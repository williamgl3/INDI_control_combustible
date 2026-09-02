import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';

type Canonical = null | boolean | string | number | Canonical[] | { [key: string]: Canonical };

function normalizarNumero(valor: number): number | string {
  if (!Number.isFinite(valor)) throw new TypeError('El fingerprint no admite numeros no finitos.');
  return Object.is(valor, -0) ? 0 : valor;
}

export function canonicalizar(valor: unknown): Canonical {
  if (valor === null || typeof valor === 'boolean' || typeof valor === 'string') return valor;
  if (typeof valor === 'number') return normalizarNumero(valor);
  if (valor instanceof Date) return valor.toISOString();
  if (Array.isArray(valor)) return valor.map(canonicalizar);
  if (typeof valor === 'object') {
    const salida: Record<string, Canonical> = {};
    for (const clave of Object.keys(valor as Record<string, unknown>).sort()) {
      const item = (valor as Record<string, unknown>)[clave];
      if (item !== undefined) salida[clave] = canonicalizar(item);
    }
    return salida;
  }
  throw new TypeError(`Tipo no permitido en fingerprint: ${typeof valor}`);
}

export function fingerprintRequest(valor: unknown): string {
  return createHash('sha256').update(JSON.stringify(canonicalizar(valor))).digest('hex');
}

export async function sha256DeArchivo(ruta: string | undefined): Promise<string | null> {
  if (!ruta) return null;
  return createHash('sha256').update(await readFile(ruta)).digest('hex');
}

export async function hashesDeArchivos(
  archivos: Readonly<Record<string, Express.Multer.File[] | undefined>>,
): Promise<Record<string, string[]>> {
  const resultado: Record<string, string[]> = {};
  for (const campo of Object.keys(archivos).sort()) {
    const lista = archivos[campo] ?? [];
    resultado[campo] = await Promise.all(lista.map((archivo) => sha256DeArchivo(archivo.path))) as string[];
  }
  return resultado;
}
