import type { ReadStream } from 'node:fs';

export interface ArchivoAlmacenado {
  stream: ReadStream;
  mimeType: string;
  longitud: number;
}

/**
 * Frontera de almacenamiento privado. Las rutas HTTP y los servicios de
 * dominio solo conocen una storageKey opaca; ninguna implementación debe
 * producir una URL pública ni aceptar rutas del cliente.
 */
export interface AlmacenamientoPrivado {
  abrir(storageKey: string): Promise<ArchivoAlmacenado | null>;
}

