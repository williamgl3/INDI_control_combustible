import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';

type PartidaCanonica = {
  tipo: string;
  litros: number;
  tipoCombustible: string;
  observaciones?: string | null | undefined;
};

function texto(valor?: string | null): string {
  return (valor ?? '').trim().replace(/\s+/g, ' ');
}

export async function sha256Archivo(ruta?: string): Promise<string> {
  if (!ruta) return '';
  return createHash('sha256').update(await readFile(ruta)).digest('hex');
}

export function fingerprintSolicitud(datos: {
  choferId: string;
  vehiculoId: string;
  litrosSolicitados?: number | undefined;
  partidas?: PartidaCanonica[] | undefined;
  esUrgente: boolean;
  motivoChofer?: string | null | undefined;
  actividad: string;
  fechaProgramada: string;
  fotoSha256: string;
}): string {
  const partidas = [...(datos.partidas ?? [])]
    .sort((a, b) => a.tipo.localeCompare(b.tipo))
    .map((p) => ({
      tipo: p.tipo,
      litros: p.litros.toFixed(2),
      tipoCombustible: p.tipoCombustible,
      observaciones: texto(p.observaciones),
    }));
  const canonico = JSON.stringify({
    choferId: datos.choferId,
    vehiculoId: datos.vehiculoId,
    categoria: partidas.length > 0 ? 'partidas' : 'unidad',
    litros: partidas.length > 0
      ? partidas.reduce((total, p) => total + Number(p.litros), 0).toFixed(2)
      : (datos.litrosSolicitados ?? 0).toFixed(2),
    urgente: datos.esUrgente,
    fechaProgramada: new Date(datos.fechaProgramada).toISOString().slice(0, 10),
    actividad: texto(datos.actividad),
    motivo: texto(datos.motivoChofer),
    partidas,
    fotoSha256: datos.fotoSha256,
  });
  return createHash('sha256').update(canonico).digest('hex');
}
