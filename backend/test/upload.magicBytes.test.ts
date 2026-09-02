import { mkdtempSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  esMimetypePermitido,
  limpiarArchivosAnteError,
  limpiarArchivosDeReplay,
  UPLOADS_DIR,
  verificarMagicBytes,
} from '../src/middleware/upload';

/// El `fileFilter` de multer solo ve el mimetype que el cliente declaró
/// en el multipart — este middleware corre después, con el archivo ya en
/// disco, y valida los bytes reales. Se prueba directo (sin levantar
/// Express) pasando objetos `req`/`res`/`next` mínimos.
function archivoFalso(path: string): Express.Multer.File {
  return {
    path,
    fieldname: 'foto',
    originalname: 'foto.jpg',
    encoding: '7bit',
    mimetype: 'image/jpeg',
    destination: tmpdir(),
    filename: 'foto.jpg',
    size: 10,
    stream: undefined as never,
    buffer: undefined as never,
  };
}

describe('verificarMagicBytes', () => {
  it('acepta los MIME de cámara que luego se validan por firma real', () => {
    expect(esMimetypePermitido('image/jpeg')).toBe(true);
    expect(esMimetypePermitido('image/jpg')).toBe(true);
    expect(esMimetypePermitido('application/octet-stream')).toBe(true);
    expect(esMimetypePermitido('application/pdf')).toBe(false);
  });

  it('deja pasar un archivo con bytes reales de JPEG', async () => {
    const dir = mkdtempSync(join(UPLOADS_DIR, 'upload-test-'));
    const ruta = join(dir, 'real.jpg');
    writeFileSync(ruta, Buffer.from([0xff, 0xd8, 0xff, 0x00, 0x00, 0x00]));

    let siguienteLlamado = false;
    const req = { file: archivoFalso(ruta), files: undefined } as never;
    const next = ((err?: unknown) => {
      expect(err).toBeUndefined();
      siguienteLlamado = true;
    }) as never;

    await verificarMagicBytes(req, {} as never, next);
    expect(siguienteLlamado).toBe(true);
    expect(existsSync(ruta)).toBe(true);
  });

  it('rechaza y borra un archivo cuyo mimetype declarado no coincide con sus bytes reales', async () => {
    const dir = mkdtempSync(join(UPLOADS_DIR, 'upload-test-'));
    const ruta = join(dir, 'falso.jpg');
    // Un ejecutable/script cualquiera, disfrazado de "image/jpeg" en el
    // multipart pero sin ninguna firma de imagen real en sus bytes.
    writeFileSync(ruta, Buffer.from('#!/bin/sh\necho hola\n'));

    let errorRecibido: unknown;
    const req = { file: archivoFalso(ruta), files: undefined } as never;
    const next = ((err?: unknown) => {
      errorRecibido = err;
    }) as never;

    await verificarMagicBytes(req, {} as never, next);
    expect(errorRecibido).toBeInstanceOf(Error);
    expect((errorRecibido as Error).message).toContain('no es una imagen válida');
    expect(existsSync(ruta)).toBe(false);
  });

  it('limpia solo el archivo de la petición cuando falla la persistencia', async () => {
    const dir = mkdtempSync(join(UPLOADS_DIR, 'upload-test-'));
    const ruta = join(dir, 'creado-por-esta-peticion.jpg');
    writeFileSync(ruta, Buffer.from([0xff, 0xd8, 0xff]));
    const errorOriginal = new Error('fallo de inserción');
    const req = { file: archivoFalso(ruta), files: undefined } as never;

    await new Promise<void>((resolve, reject) => {
      limpiarArchivosAnteError(errorOriginal, req, {} as never, (error) => {
        try {
          expect(error).toBe(errorOriginal);
          expect(existsSync(ruta)).toBe(false);
          resolve();
        } catch (assertionError) {
          reject(assertionError);
        }
      });
    });
  });

  it('un replay elimina solo la copia multipart nueva y conserva el original', async () => {
    const dir = mkdtempSync(join(UPLOADS_DIR, 'upload-replay-test-'));
    const original = join(dir, 'original.jpg');
    const copiaRetry = join(dir, 'retry.jpg');
    writeFileSync(original, Buffer.from([0xff, 0xd8, 0xff, 1]));
    writeFileSync(copiaRetry, Buffer.from([0xff, 0xd8, 0xff, 1]));
    await limpiarArchivosDeReplay(
      { file: archivoFalso(copiaRetry), files: undefined } as never,
      true,
    );
    expect(existsSync(copiaRetry)).toBe(false);
    expect(existsSync(original)).toBe(true);
  });
});
