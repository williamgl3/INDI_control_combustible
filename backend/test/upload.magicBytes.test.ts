import { mkdtempSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { verificarMagicBytes } from '../src/middleware/upload';

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
  it('deja pasar un archivo con bytes reales de JPEG', () => {
    const dir = mkdtempSync(join(tmpdir(), 'upload-test-'));
    const ruta = join(dir, 'real.jpg');
    writeFileSync(ruta, Buffer.from([0xff, 0xd8, 0xff, 0x00, 0x00, 0x00]));

    let siguienteLlamado = false;
    const req = { file: archivoFalso(ruta), files: undefined } as never;
    const next = ((err?: unknown) => {
      expect(err).toBeUndefined();
      siguienteLlamado = true;
    }) as never;

    verificarMagicBytes(req, {} as never, next);
    expect(siguienteLlamado).toBe(true);
    expect(existsSync(ruta)).toBe(true);
  });

  it('rechaza y borra un archivo cuyo mimetype declarado no coincide con sus bytes reales', () => {
    const dir = mkdtempSync(join(tmpdir(), 'upload-test-'));
    const ruta = join(dir, 'falso.jpg');
    // Un ejecutable/script cualquiera, disfrazado de "image/jpeg" en el
    // multipart pero sin ninguna firma de imagen real en sus bytes.
    writeFileSync(ruta, Buffer.from('#!/bin/sh\necho hola\n'));

    let errorRecibido: unknown;
    const req = { file: archivoFalso(ruta), files: undefined } as never;
    const next = ((err?: unknown) => {
      errorRecibido = err;
    }) as never;

    verificarMagicBytes(req, {} as never, next);
    expect(errorRecibido).toBeInstanceOf(Error);
    expect((errorRecibido as Error).message).toContain('no es una imagen válida');
    expect(existsSync(ruta)).toBe(false);
  });
});
