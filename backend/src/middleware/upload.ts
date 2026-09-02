import { randomUUID } from 'node:crypto';
import { existsSync, mkdirSync } from 'node:fs';
import { open, unlink } from 'node:fs/promises';
import { extname, join, relative, resolve } from 'node:path';
import type { NextFunction, Request, Response } from 'express';
import dotenv from 'dotenv';
import multer from 'multer';
import { ApiError } from '../utils/asyncHandler';

// Ver el comentario en `db/pool.ts` sobre por qué cada módulo que lee
// `process.env` al cargar necesita su propio `dotenv.config()`.
dotenv.config({ quiet: true });

/// Directorio privado de fotos (tickets, tablero y evidencias). Ya no se
/// monta con `express.static`: la lectura pasa por `GET /archivos/:id`, que
/// resuelve metadata, autoriza al actor y usa `AlmacenamientoPrivado`.
export const UPLOADS_DIR = process.env.UPLOADS_DIR
  ? join(process.cwd(), process.env.UPLOADS_DIR)
  : join(process.cwd(), 'uploads');

if (!existsSync(UPLOADS_DIR)) {
  mkdirSync(UPLOADS_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOADS_DIR),
  filename: (_req, file, cb) => {
    const original = extname(file.originalname).toLowerCase();
    const extensionesPermitidas = new Set(['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif']);
    const porMime: Readonly<Record<string, string>> = {
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
      'image/heic': '.heic',
      'image/heif': '.heif',
    };
    // Nunca conservar una extensión arbitraria proporcionada por el
    // cliente. `verificarMagicBytes` valida después el contenido real.
    const ext = extensionesPermitidas.has(original)
      ? original
      : (porMime[file.mimetype.toLowerCase()] ?? '.jpg');
    cb(null, `${randomUUID()}${ext}`);
  },
});

// Algunos dispositivos Android (y `MultipartFile.fromPath` cuando la ruta
// temporal no conserva su extensión) declaran `image/jpg` o
// `application/octet-stream`. Estos dos valores no son una autorización por
// sí mismos: `verificarMagicBytes`, ejecutado inmediatamente después de
// Multer, exige que el contenido tenga una firma real de imagen y elimina el
// archivo si no la tiene.
const FORMATOS_PERMITIDOS = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
  'application/octet-stream',
]);

export function esMimetypePermitido(mimetype: string): boolean {
  return FORMATOS_PERMITIDOS.has(mimetype.toLowerCase().trim());
}

export const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB por foto
  fileFilter: (_req, file, cb) => {
    if (!esMimetypePermitido(file.mimetype)) {
      cb(new Error('Formato de imagen no soportado.'));
      return;
    }
    cb(null, true);
  },
});

export function rutaPublicaDeArchivo(nombreArchivo: string): string {
  return `/uploads/${nombreArchivo}`;
}

// Firmas ("magic bytes") reales de cada formato permitido — el
// `fileFilter` de multer arriba solo puede ver el mimetype que el
// CLIENTE declaró en el multipart, y un cliente malicioso puede mandar
// cualquier archivo diciendo que es "image/jpeg" sin que multer lo note.
const FORMATOS_POR_FIRMA: Array<{ mimeType: string; coincide: (buf: Buffer) => boolean }> = [
  // JPEG
  { mimeType: 'image/jpeg', coincide: (b) => b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  // PNG
  { mimeType: 'image/png', coincide: (b) => b.length >= 4 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47 },
  // WEBP (contenedor RIFF con marca WEBP)
  {
    mimeType: 'image/webp',
    coincide: (b) =>
      b.length >= 12 && b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP',
  },
  // HEIC/HEIF (caja ISO BMFF "ftyp" con alguna de las marcas conocidas)
  {
    mimeType: 'image/heic',
    coincide: (b) =>
      b.length >= 12 &&
      b.toString('ascii', 4, 8) === 'ftyp' &&
      ['heic', 'heix', 'hevc', 'heim', 'heis', 'hevm', 'hevs', 'mif1', 'msf1'].includes(
        b.toString('ascii', 8, 12),
      ),
  },
];

export function detectarMimeImagen(buf: Buffer): string | null {
  return FORMATOS_POR_FIRMA.find((formato) => formato.coincide(buf))?.mimeType ?? null;
}

async function esImagenValida(rutaArchivo: string): Promise<boolean> {
  const archivo = await open(rutaArchivo, 'r');
  try {
    const encabezado = Buffer.alloc(16);
    const { bytesRead } = await archivo.read(encabezado, 0, 16, 0);
    return detectarMimeImagen(encabezado.subarray(0, bytesRead)) !== null;
  } finally {
    await archivo.close();
  }
}

export function archivosDeLaPeticion(req: Request): Express.Multer.File[] {
  if (req.file) return [req.file];
  if (!req.files) return [];
  return Array.isArray(req.files) ? req.files : Object.values(req.files).flat();
}

/// Corre DESPUÉS de `upload.single(...)`/`upload.fields(...)` (ya con el
/// archivo escrito en disco) y valida los bytes reales contra las firmas
/// de arriba — si algo no coincide, borra TODOS los archivos de la
/// petición (no dejar huérfanos en disco) y responde 400.
export async function eliminarArchivosNuevos(req: Request): Promise<void> {
  const raiz = resolve(UPLOADS_DIR);
  await Promise.all(archivosDeLaPeticion(req).map(async (archivo) => {
    const objetivo = resolve(archivo.path);
    const dentro = relative(raiz, objetivo);
    if (dentro.startsWith('..') || dentro.includes(':') || dentro === '') return;
    await unlink(objetivo).catch(() => undefined);
  }));
}

/// Un replay multipart ya tiene un recurso persistido que referencia los
/// archivos de la primera ejecucion. Multer, sin embargo, escribio copias
/// nuevas para este request: elimina solo esas copias recibidas ahora.
export async function limpiarArchivosDeReplay(req: Request, replayed: boolean): Promise<void> {
  if (replayed) await eliminarArchivosNuevos(req);
}

export function limpiarArchivosAnteError(
  error: unknown,
  req: Request,
  _res: Response,
  next: NextFunction,
): void {
  void eliminarArchivosNuevos(req).finally(() => next(error));
}

export async function verificarMagicBytes(req: Request, _res: Response, next: NextFunction): Promise<void> {
  const archivos = archivosDeLaPeticion(req);
  try {
    const resultados = await Promise.all(archivos.map((archivo) => esImagenValida(archivo.path)));
    if (resultados.every(Boolean)) {
      next();
      return;
    }
    await eliminarArchivosNuevos(req);
    next(new ApiError(400, 'Uno de los archivos no es una imagen válida.'));
  } catch {
    await eliminarArchivosNuevos(req);
    next(new ApiError(400, 'No fue posible validar uno de los archivos.'));
  }
}
