import { existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { AlmacenamientoLocalPrivado } from '../src/storage/almacenamientoLocalPrivado';

const creados: string[] = [];
const key = '550e8400-e29b-41d4-a716-446655440000.jpg';

function temporal(): string {
  const dir = mkdtempSync(join(tmpdir(), 'indi-storage-'));
  creados.push(dir);
  return dir;
}

afterEach(() => {
  for (const dir of creados.splice(0)) rmSync(dir, { recursive: true, force: true });
});

describe('AlmacenamientoLocalPrivado', () => {
  it('abre una storageKey válida dentro de la raíz', async () => {
    const dir = temporal();
    writeFileSync(join(dir, key), Buffer.from([0xff, 0xd8, 0xff, 0xd9]));
    const archivo = await new AlmacenamientoLocalPrivado(dir).abrir(key);
    expect(archivo?.mimeType).toBe('image/jpeg');
    expect(archivo?.longitud).toBe(4);
    const partes: Buffer[] = [];
    if (archivo) {
      for await (const parte of archivo.stream) partes.push(Buffer.from(parte));
    }
    expect(Buffer.concat(partes)).toEqual(Buffer.from([0xff, 0xd8, 0xff, 0xd9]));
  });

  it('determina el MIME por magic bytes y no por la extensión', async () => {
    const dir = temporal();
    const keyConExtensionEngañosa = '550e8400-e29b-41d4-a716-446655440000.png';
    writeFileSync(join(dir, keyConExtensionEngañosa), Buffer.from([0xff, 0xd8, 0xff, 0xd9]));
    const archivo = await new AlmacenamientoLocalPrivado(dir).abrir(keyConExtensionEngañosa);
    expect(archivo?.mimeType).toBe('image/jpeg');
    if (archivo) {
      for await (const _ of archivo.stream) {
        // Consumir el stream antes del cleanup del directorio temporal.
      }
    }
  });

  it('devuelve null para archivo inexistente', async () => {
    expect(await new AlmacenamientoLocalPrivado(temporal()).abrir(key)).toBeNull();
  });

  it.each(['../archivo.jpg', '..\\archivo.jpg', 'C:\\Windows\\system.ini', 'archivo.jpg'])(
    'rechaza la clave fuera de contrato %s sin revelar la raíz',
    async (entrada) => {
      const dir = temporal();
      const resultado = await new AlmacenamientoLocalPrivado(dir).abrir(entrada);
      expect(resultado).toBeNull();
      expect(JSON.stringify(resultado)).not.toContain(dir);
    },
  );

  it('traduce un error de lectura a ausencia sin revelar la ruta', async () => {
    const dir = temporal();
    // Un directorio con nombre de archivo válido falla el requisito isFile.
    const objetivo = join(dir, key);
    mkdirSync(objetivo);
    const resultado = await new AlmacenamientoLocalPrivado(dir).abrir(key);
    expect(resultado).toBeNull();
    expect(JSON.stringify(resultado)).not.toContain(dir);
  });

  it('rechaza un symlink que escapa de la raíz cuando la plataforma lo permite', async () => {
    const dir = temporal();
    const fuera = temporal();
    const destino = join(fuera, 'fuera.jpg');
    writeFileSync(destino, Buffer.from([0xff, 0xd8, 0xff]));
    try {
      symlinkSync(destino, join(dir, key), 'file');
    } catch {
      // Windows puede no conceder privilegio para symlinks en CI.
      expect(existsSync(join(dir, key))).toBe(false);
      return;
    }
    expect(await new AlmacenamientoLocalPrivado(dir).abrir(key)).toBeNull();
  });
});
