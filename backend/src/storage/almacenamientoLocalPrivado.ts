import { createReadStream } from 'node:fs';
import { open, realpath, stat } from 'node:fs/promises';
import { isAbsolute, join, relative, resolve } from 'node:path';
import { detectarMimeImagen, UPLOADS_DIR } from '../middleware/upload';
import type { AlmacenamientoPrivado, ArchivoAlmacenado } from './almacenamientoPrivado';

export const STORAGE_KEY_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(?:jpe?g|png|webp|heic|heif)$/i;

function estaDentroDe(raiz: string, objetivo: string): boolean {
  const dentro = relative(raiz, objetivo);
  return dentro !== '' && !dentro.startsWith('..') && !isAbsolute(dentro);
}

export class AlmacenamientoLocalPrivado implements AlmacenamientoPrivado {
  constructor(private readonly directorioRaiz: string = UPLOADS_DIR) {}

  async abrir(storageKey: string): Promise<ArchivoAlmacenado | null> {
    if (!STORAGE_KEY_PATTERN.test(storageKey)) return null;

    try {
      const raizReal = await realpath(resolve(this.directorioRaiz));
      const candidato = join(raizReal, storageKey);
      const objetivoReal = await realpath(candidato);
      if (!estaDentroDe(raizReal, objetivoReal)) return null;
      const info = await stat(objetivoReal);
      if (!info.isFile()) return null;
      const descriptor = await open(objetivoReal, 'r');
      let mimeType: string | null;
      try {
        const encabezado = Buffer.alloc(16);
        const { bytesRead } = await descriptor.read(encabezado, 0, 16, 0);
        mimeType = detectarMimeImagen(encabezado.subarray(0, bytesRead));
      } finally {
        await descriptor.close();
      }
      if (!mimeType) return null;
      return {
        stream: createReadStream(objetivoReal),
        mimeType,
        longitud: info.size,
      };
    } catch {
      // No se propaga el error del sistema de archivos: puede contener la
      // ruta física del servidor. Para el consumidor es un archivo ausente.
      return null;
    }
  }
}

export const almacenamientoLocalPrivado = new AlmacenamientoLocalPrivado();
