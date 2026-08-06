import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pool } from './pool';
import { logger } from '../utils/logger';

/// Importa un catálogo de unidades (vehículos ligeros, marimba, pipas o
/// maquinaria pesada) desde un CSV a la tabla `vehiculos`. Soporta DOS
/// formatos de columnas distintos — el del catálogo de vehículos ligeros
/// del cliente y el del catálogo de maquinaria pesada — detectados
/// automáticamente por el encabezado del archivo, así que el mismo
/// script sirve para ambos sin flags ni archivos separados por tipo.
///
/// Formato "vehículos" (columnas):
///   vehiculo, placas, tipo_combustible, tipo_unidad, intervalo_servicio_km
///   tipo_unidad ∈ {vehiculo_ligero, marimba}
///
/// Formato "maquinaria" (columnas):
///   num_economico, maquina, tipo_unidad, marca, modelo, placas, num_serie,
///   procedencia, estatus, ubicacion, responsable, tramo, segmento,
///   capacidad, metrica, lectura_actual, fecha_alta, tipo_combustible, revisar
///   tipo_unidad ∈ {maquinaria_pesada, marimba, pipa, sin_clasificar}
///
/// Uso:
///   npm run importar:vehiculos -- data/catalogo_vehiculos_gami.csv
///   npm run importar:vehiculos -- data/catalogo_maquinaria_gami.csv
///
/// La conexión a la base de datos la decide `DATABASE_URL` (leída de
/// `backend/.env` por `./pool`) — para producción, sobreescribe la
/// variable en la misma línea de comando sin tocar el `.env` de
/// desarrollo:
///   DATABASE_URL=postgresql://usuario:pass@host-prod:5432/db npm run importar:vehiculos -- archivo.csv
///
/// Idempotente y reconciliador entre catálogos: antes de insertar,
/// busca una unidad existente por `placas` O `numero_economico`
/// normalizados. Si existe, NUNCA inserta un duplicado — en vez de eso
/// completa (con COALESCE, nunca sobrescribe un dato real ya presente)
/// los campos que la unidad existente no tenía. Esto resuelve de forma
/// genérica el caso conocido de "CV-4156-H"/"COL-25-014" (la misma
/// marimba aparece en los dos catálogos, con distintos datos en cada
/// uno) sin necesitar un caso especial hardcodeado, y de paso hace que
/// correr el mismo archivo dos veces no duplique nada.
///
/// Datos del CSV de maquinaria que EXISTEN mas NO se guardan (el
/// esquema de `vehiculos` no tiene columna para ellos): num_serie,
/// procedencia, ubicacion, responsable, tramo, segmento, capacidad,
/// metrica. Se pierden al importar — si en algún momento el panel
/// admin necesita mostrarlos, hace falta ampliar el esquema primero.
///
/// `lectura_actual`/`fecha_alta` del CSV de maquinaria TAMPOCO se
/// guardan en `lectura_ultimo_servicio`/`fecha_ultimo_servicio` — esos
/// campos significan "cuándo fue el último SERVICIO de mantenimiento",
/// no "lectura actual del odómetro/horómetro a la fecha de importación".
/// Guardar la lectura actual ahí haría que el módulo de Mantenimiento
/// preventivo calcule "0 uso, recién servida" para las 57 unidades el
/// día de la importación, que es falso — no sabemos cuándo fue su
/// último servicio real. Quedan en NULL a propósito (estado "sin
/// datos" en `calcularMantenimiento`, que es la representación honesta).

interface FilaVehiculos {
  vehiculo: string;
  placas: string;
  tipo_combustible: string;
  tipo_unidad: string;
  intervalo_servicio_km?: string;
}

interface FilaMaquinaria {
  num_economico: string;
  maquina: string;
  tipo_unidad: string;
  marca: string;
  modelo: string;
  placas?: string;
  estatus?: string;
  tipo_combustible?: string;
  revisar?: string;
}

interface RegistroNormalizado {
  /// Identificador para mostrar en los reportes — el que exista.
  fuente: string;
  /// `null` = no clasificable en las categorías de la app (ej.
  /// "sin_clasificar") — se omite, nunca se inserta con una categoría
  /// arbitraria.
  tipoUnidad: string | null;
  placas: string | null;
  numeroEconomico: string | null;
  modelo: string;
  tipoCombustible: string | null;
  intervaloServicio: number;
  activo: boolean;
  /// Contenido de la columna `revisar` del CSV de maquinaria, si trae
  /// algo — se reporta siempre, insertada o no la fila.
  observacion: string | null;
}

type Resultado =
  | { estado: 'insertado'; fuente: string; observacion: string | null }
  | { estado: 'reconciliado'; fuente: string; detalle: string; observacion: string | null }
  | { estado: 'omitido_existente'; fuente: string }
  | { estado: 'omitido_sin_categoria'; fuente: string; observacion: string }
  | { estado: 'fallido'; fuente: string; motivo: string };

// ============================================================
// CSV — parser mínimo con soporte de comillas (campos como
// "10,000LT" traen una coma dentro de comillas).
// ============================================================

function parsearLineaCsv(linea: string): string[] {
  const campos: string[] = [];
  let actual = '';
  let dentroDeComillas = false;
  for (let i = 0; i < linea.length; i++) {
    const c = linea[i];
    if (dentroDeComillas) {
      if (c === '"') {
        if (linea[i + 1] === '"') {
          actual += '"';
          i++;
        } else {
          dentroDeComillas = false;
        }
      } else {
        actual += c;
      }
    } else if (c === '"') {
      dentroDeComillas = true;
    } else if (c === ',') {
      campos.push(actual);
      actual = '';
    } else {
      actual += c;
    }
  }
  campos.push(actual);
  return campos;
}

function leerCsv(ruta: string): Record<string, string>[] {
  const contenido = readFileSync(ruta, 'utf-8');
  const lineas = contenido.split(/\r?\n/).filter((l) => l.trim().length > 0);
  if (lineas.length === 0) return [];
  const encabezados = parsearLineaCsv(lineas[0]!).map((h) => h.trim());
  return lineas.slice(1).map((linea) => {
    const valores = parsearLineaCsv(linea);
    const fila: Record<string, string> = {};
    encabezados.forEach((encabezado, i) => {
      fila[encabezado] = (valores[i] ?? '').trim();
    });
    return fila;
  });
}

// ============================================================
// Reparación de codificación — el catálogo de origen llegó con
// "doble codificación" (UTF-8 reinterpretado como Latin-1 y vuelto a
// guardar): "Diésel" quedó como "DiÃ©sel". El mismo truco arregla
// cualquier campo con este patrón, no solo el combustible.
// ============================================================
function repararMojibake(valor: string): string {
  return Buffer.from(valor, 'latin1').toString('utf-8');
}

// ============================================================
// Identificadores — mayúsculas, sin espacios, vacío → null (NUNCA
// cadena vacía: la constraint UNIQUE normalizada trataría dos
// unidades sin placas como si fueran la misma placa "").
// ============================================================
function normalizarIdentificador(valor: string | undefined | null): string | null {
  const limpio = (valor ?? '').trim().toUpperCase();
  return limpio === '' ? null : limpio;
}

const TIPOS_COMBUSTIBLE_VALIDOS = ['Diésel', 'Magna', 'Premium'];

/// Vacío es un resultado VÁLIDO (`valor: null`, sin `error`) — la
/// maquinaria entra así a propósito. Un valor presente pero no
/// reconocido sí es un error real, se reporta aparte.
function normalizarTipoCombustible(crudo: string | undefined): { valor: string | null; error?: string } {
  const limpio = (crudo ?? '').trim();
  if (limpio === '') return { valor: null };
  const reparado = repararMojibake(limpio).toUpperCase();
  const mapa: Record<string, string> = {
    MAGNA: 'Magna',
    DIESEL: 'Diésel',
    DIÉSEL: 'Diésel',
    PREMIUM: 'Premium',
  };
  const normalizado = mapa[reparado];
  if (!normalizado || !TIPOS_COMBUSTIBLE_VALIDOS.includes(normalizado)) {
    return { valor: null, error: `tipoCombustible "${crudo}" no reconocido (esperado Magna/Diésel/Premium)` };
  }
  return { valor: normalizado };
}

/// 250h para lo que se mide por horómetro (Maquinaria), 5000km para el
/// resto — mismo default que usa el alta manual del panel admin
/// (`vehiculosService.ts`/`catalogos_vehiculo.dart`). Ninguno de los 2
/// catálogos trae un intervalo real por unidad.
function intervaloServicioPorDefecto(tipoUnidad: string): number {
  return tipoUnidad === 'Maquinaria' ? 250 : 5000;
}

// ============================================================
// Normalización por formato de archivo
// ============================================================

const CATEGORIA_VEHICULOS: Record<string, string> = {
  vehiculo_ligero: 'Vehículo',
  marimba: 'Marimba',
};

/// `null` = no encaja en ninguna categoría de la app — se omite y se
/// reporta, nunca se le asigna una categoría arbitraria (ver
/// CPL-23-001, "no encaja en las 4 categorías").
const CATEGORIA_MAQUINARIA: Record<string, string | null> = {
  maquinaria_pesada: 'Maquinaria',
  marimba: 'Marimba',
  pipa: 'Pipa',
  sin_clasificar: null,
};

function normalizarFilaVehiculos(fila: FilaVehiculos): RegistroNormalizado {
  const placas = normalizarIdentificador(fila.placas);
  const { valor: tipoCombustible, error } = normalizarTipoCombustible(fila.tipo_combustible);
  const tipoUnidadOrigen = (fila.tipo_unidad ?? '').trim().toLowerCase();
  const tipoUnidad = CATEGORIA_VEHICULOS[tipoUnidadOrigen] ?? null;

  return {
    fuente: placas ?? fila.vehiculo ?? '(sin identificador)',
    tipoUnidad,
    placas,
    numeroEconomico: null,
    modelo: (fila.vehiculo ?? '').trim(),
    tipoCombustible,
    intervaloServicio: intervaloServicioPorDefecto(tipoUnidad ?? ''),
    activo: true,
    observacion: error ?? null,
  };
}

/// "Marca + modelo" como texto de `modelo` (ej. "CATERPILLAR 330") — más
/// específico que solo la descripción genérica de máquina ("EXCAVADORA
/// HIDRAULICA"), y consistente con cómo el catálogo de vehículos
/// ligeros ya combina marca+modelo en un solo campo ("NISSAN
/// FRONTIER"). Evita repetir la marca si el propio campo `modelo` ya
/// la trae al inicio (ej. marca "RM", modelo "RM HS5000M" → se queda
/// "RM HS5000M", no "RM RM HS5000M").
function combinarMarcaModelo(marca: string, modelo: string): string {
  const marcaLimpia = marca.trim();
  const modeloLimpio = modelo.trim();
  if (modeloLimpio.toUpperCase().startsWith(marcaLimpia.toUpperCase())) {
    return modeloLimpio;
  }
  return `${marcaLimpia} ${modeloLimpio}`.trim();
}

function normalizarFilaMaquinaria(fila: FilaMaquinaria): RegistroNormalizado {
  const numeroEconomico = normalizarIdentificador(fila.num_economico);
  const placas = normalizarIdentificador(fila.placas);
  const { valor: tipoCombustible, error } = normalizarTipoCombustible(fila.tipo_combustible);
  const tipoUnidadOrigen = (fila.tipo_unidad ?? '').trim().toLowerCase();
  const tipoUnidad = CATEGORIA_MAQUINARIA[tipoUnidadOrigen] ?? null;
  const observacionCsv = (fila.revisar ?? '').trim() || null;
  const activo = (fila.estatus ?? '').trim().toUpperCase() === 'ACTIVA';

  return {
    fuente: numeroEconomico ?? fila.maquina ?? '(sin identificador)',
    tipoUnidad,
    placas,
    numeroEconomico,
    modelo: combinarMarcaModelo(fila.marca ?? '', fila.modelo ?? '') || (fila.maquina ?? '').trim(),
    tipoCombustible,
    intervaloServicio: intervaloServicioPorDefecto(tipoUnidad ?? ''),
    activo,
    observacion: [observacionCsv, error].filter(Boolean).join(' — ') || null,
  };
}

/// Detecta el formato por el encabezado — `num_economico` solo existe
/// en el catálogo de maquinaria.
function normalizarArchivo(filas: Record<string, string>[]): RegistroNormalizado[] {
  if (filas.length === 0) return [];
  const esMaquinaria = 'num_economico' in filas[0]!;
  return esMaquinaria
    ? filas.map((f) => normalizarFilaMaquinaria(f as unknown as FilaMaquinaria))
    : filas.map((f) => normalizarFilaVehiculos(f as unknown as FilaVehiculos));
}

// ============================================================
// Inserción / reconciliación contra la base de datos
// ============================================================

interface FilaExistente {
  id: string;
  placas: string | null;
  numero_economico: string | null;
  tipo_combustible: string | null;
}

async function buscarExistente(
  placas: string | null,
  numeroEconomico: string | null,
): Promise<FilaExistente | null> {
  if (!placas && !numeroEconomico) return null;
  const { rows } = await pool.query<FilaExistente>(
    `SELECT id, placas, numero_economico, tipo_combustible FROM vehiculos
     WHERE ($1::text IS NOT NULL AND upper(trim(placas)) = $1)
        OR ($2::text IS NOT NULL AND upper(trim(numero_economico)) = $2)
     LIMIT 1`,
    [placas, numeroEconomico],
  );
  return rows[0] ?? null;
}

async function procesarRegistro(registro: RegistroNormalizado): Promise<Resultado> {
  if (!registro.tipoUnidad) {
    return {
      estado: 'omitido_sin_categoria',
      fuente: registro.fuente,
      observacion: registro.observacion ?? '(sin motivo especificado en el CSV)',
    };
  }
  if (!registro.placas && !registro.numeroEconomico) {
    return { estado: 'fallido', fuente: registro.fuente, motivo: 'sin placas ni número económico' };
  }

  const existente = await buscarExistente(registro.placas, registro.numeroEconomico);

  if (existente) {
    // Reconciliación: solo se completan huecos (COALESCE), nunca se
    // sobrescribe un dato ya presente — así conserva, por ejemplo, el
    // "Diésel" que el catálogo de vehículos ya trae para CV-4156-H
    // aunque el catálogo de maquinaria traiga NULL para esa misma
    // unidad (COL-25-014).
    const faltaPlacas = !existente.placas && registro.placas;
    const faltaEconomico = !existente.numero_economico && registro.numeroEconomico;
    const faltaCombustible = !existente.tipo_combustible && registro.tipoCombustible;

    if (!faltaPlacas && !faltaEconomico && !faltaCombustible) {
      return { estado: 'omitido_existente', fuente: registro.fuente };
    }

    await pool.query(
      `UPDATE vehiculos
       SET placas = COALESCE(placas, $1),
           numero_economico = COALESCE(numero_economico, $2),
           tipo_combustible = COALESCE(tipo_combustible, $3)
       WHERE id = $4`,
      [registro.placas, registro.numeroEconomico, registro.tipoCombustible, existente.id],
    );
    const completados = [
      faltaPlacas && `placas=${registro.placas}`,
      faltaEconomico && `económico=${registro.numeroEconomico}`,
      faltaCombustible && `combustible=${registro.tipoCombustible}`,
    ]
      .filter(Boolean)
      .join(', ');
    return {
      estado: 'reconciliado',
      fuente: registro.fuente,
      detalle: `ya existía, se completó: ${completados}`,
      observacion: registro.observacion,
    };
  }

  await pool.query(
    `INSERT INTO vehiculos (tipo_unidad, placas, numero_economico, tipo_combustible, modelo, intervalo_servicio, activo)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [
      registro.tipoUnidad,
      registro.placas,
      registro.numeroEconomico,
      registro.tipoCombustible,
      registro.modelo,
      registro.intervaloServicio,
      registro.activo,
    ],
  );
  return { estado: 'insertado', fuente: registro.fuente, observacion: registro.observacion };
}

// ============================================================
// Reporte
// ============================================================

async function importar() {
  const argumento = process.argv[2];
  if (!argumento) {
    throw new Error(
      'Falta la ruta del CSV. Uso: npm run importar:vehiculos -- data/catalogo_vehiculos_gami.csv',
    );
  }
  const rutaArchivo = resolve(process.cwd(), argumento);
  logger.info({ rutaArchivo }, 'Leyendo catálogo');

  const filasCrudas = leerCsv(rutaArchivo);
  const registros = normalizarArchivo(filasCrudas);

  const resultados: Resultado[] = [];
  for (const registro of registros) {
    // Fila por fila (no en una sola transacción) — una fila inválida no
    // debe tumbar la importación completa de las demás.
    resultados.push(await procesarRegistro(registro));
  }

  const insertados = resultados.filter((r) => r.estado === 'insertado');
  const reconciliados = resultados.filter((r) => r.estado === 'reconciliado');
  const omitidosExistente = resultados.filter((r) => r.estado === 'omitido_existente');
  const omitidosSinCategoria = resultados.filter((r) => r.estado === 'omitido_sin_categoria');
  const fallidos = resultados.filter((r) => r.estado === 'fallido');
  const conObservacion = resultados.filter(
    (r) => (r.estado === 'insertado' || r.estado === 'reconciliado') && r.observacion !== null,
  ) as Array<{ fuente: string; observacion: string | null }>;

  console.log('\n=== Resumen de importación ===');
  console.log(`Archivo:               ${argumento}`);
  console.log(`Total de filas:        ${registros.length}`);
  console.log(`Insertados:            ${insertados.length}`);
  console.log(`Reconciliados (ya existían en el otro catálogo, se completaron datos): ${reconciliados.length}`);
  for (const r of reconciliados) {
    if (r.estado === 'reconciliado') console.log(`  ${r.fuente}: ${r.detalle}`);
  }
  console.log(`Omitidos (ya existían, sin datos nuevos que aportar): ${omitidosExistente.length}`);
  if (omitidosExistente.length > 0) {
    console.log(`  ${omitidosExistente.map((r) => r.fuente).join(', ')}`);
  }
  console.log(`Omitidos (sin categoría asignable en la app): ${omitidosSinCategoria.length}`);
  for (const r of omitidosSinCategoria) {
    if (r.estado === 'omitido_sin_categoria') console.log(`  ${r.fuente}: ${r.observacion}`);
  }
  console.log(`Fallidos:              ${fallidos.length}`);
  for (const f of fallidos) {
    if (f.estado === 'fallido') console.log(`  ${f.fuente}: ${f.motivo}`);
  }
  console.log(`\nFilas con advertencia (columna "revisar" del CSV, o combustible no reconocido): ${conObservacion.length}`);
  for (const r of conObservacion) {
    if ('observacion' in r) console.log(`  ${r.fuente}: ${r.observacion}`);
  }
  console.log('===============================\n');

  await pool.end();
}

importar().catch(async (err) => {
  logger.error({ err }, 'Error importando el catálogo');
  await pool.end();
  process.exit(1);
});
