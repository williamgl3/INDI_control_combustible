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

/// Almacenamiento de fotos (tickets, tablero) — HOY guarda en disco local
/// del servidor y expone la ruta como `/uploads/<archivo>` vía
/// `express.static` (ver index.ts). Cuando se decida el storage real de
/// producción (S3, bucket propio, etc.), solo hay que cambiar este
/// archivo por una implementación que suba ahí y devuelva la URL
/// resultante — el resto de la app (rutas, DB) ya trabaja con "una URL de
/// foto" como concepto, no con el mecanismo de guardado.
export const UPLOADS_DIR = process.env.UPLOADS_DIR
  ? join(process.cwd(), process.env.UPLOADS_DIR)
  : join(process.cwd(), 'uploads');

if (!existsSync(UPLOADS_DIR)) {
  mkdirSync(UPLOADS_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOADS_DIR),
  filename: (_req, file, cb) => {
    const ext = extname(file.originalname) || '.jpg';
    cb(null, `${randomUUID()}${ext}`);
  },
});

const FORMATOS_PERMITIDOS = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic']);

export const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB por foto
  fileFilter: (_req, file, cb) => {
    if (!FORMATOS_PERMITIDOS.has(file.mimetype)) {
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
const FIRMAS: Array<(buf: Buffer) => boolean> = [
  // JPEG
  (b) => b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff,
  // PNG
  (b) => b.length >= 4 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47,
  // WEBP (contenedor RIFF con marca WEBP)
  (b) =>
    b.length >= 12 && b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP',
  // HEIC/HEIF (caja ISO BMFF "ftyp" con alguna de las marcas conocidas)
  (b) =>
    b.length >= 12 &&
    b.toString('ascii', 4, 8) === 'ftyp' &&
    ['heic', 'heix', 'hevc', 'heim', 'heis', 'hevm', 'hevs', 'mif1', 'msf1'].includes(
      b.toString('ascii', 8, 12),
    ),
];

async function esImagenValida(rutaArchivo: string): Promise<boolean> {
  const archivo = await open(rutaArchivo, 'r');
  try {
    const encabezado = Buffer.alloc(16);
    const { bytesRead } = await archivo.read(encabezado, 0, 16, 0);
    return FIRMAS.some((coincide) => coincide(encabezado.subarray(0, bytesRead)));
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
