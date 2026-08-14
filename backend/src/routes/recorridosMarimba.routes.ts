import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ApiError } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { limpiarArchivosAnteError, upload, rutaPublicaDeArchivo, verificarMagicBytes } from '../middleware/upload';
import * as recorridosService from '../services/recorridosMarimbaService';
import * as despachosService from '../services/despachosMarimbaService';

export const recorridosMarimbaRouter=Router();
recorridosMarimbaRouter.use(requireAuth as never);
recorridosMarimbaRouter.get('/panel/unidades',requireRole('administrativo','superadmin') as never,
  asyncHandler(async(_req,res)=>res.json(await recorridosService.resumenUnidadesAdministrativo())));
recorridosMarimbaRouter.get('/panel/recorridos',requireRole('administrativo','superadmin') as never,
  asyncHandler(async(req,res)=>{const q=z.object({marimbaId:z.string().uuid().optional(),
    categoria:z.enum(['Marimba','Pipa']).optional(),
    tipoCombustible:z.enum(['Diésel','Magna','Premium']).optional(),
    estado:z.enum(['abierto','cerrado']).optional(),responsableId:z.string().uuid().optional(),
    requiereRevision:z.enum(['true','false']).transform((v)=>v==='true').optional(),
    fechaDesde:z.coerce.date().optional(),fechaHasta:z.coerce.date().optional(),
    page:z.coerce.number().int().positive().default(1),
    limit:z.coerce.number().int().min(1).max(100).default(25)}).superRefine((q,ctx)=>{
      if(q.fechaDesde&&q.fechaHasta&&q.fechaDesde>q.fechaHasta)ctx.addIssue({code:'custom',path:['fechaHasta'],message:'La fecha final no puede ser anterior a la inicial.'});
    }).parse(req.query);
    res.json(await recorridosService.listarRecorridosAdministrativo(q));}));
recorridosMarimbaRouter.get('/',requireRole('administrativo','superadmin') as never,
  asyncHandler(async(req,res)=>{const q=z.object({marimbaId:z.string().uuid().optional(),
    requiereRevision:z.coerce.boolean().optional()}).parse(req.query);res.json(await recorridosService.listarRecorridos(q));}));
recorridosMarimbaRouter.get('/:id',requireRole('supervisor','administrativo','superadmin') as never,
  asyncHandler(async(req:AuthRequest,res)=>{const r=await recorridosService.buscarRecorridoAccesible(
    req.params.id as string,req.usuarioActual!.sub,req.usuarioActual!.rol);
  if(!r)throw new ApiError(404,'Recorrido no encontrado.');res.json(r);}));
recorridosMarimbaRouter.get('/:id/despachos',requireRole('supervisor','administrativo','superadmin') as never,
  asyncHandler(async(req:AuthRequest,res)=>{const recorrido=await recorridosService.buscarRecorridoAccesible(
    req.params.id as string,req.usuarioActual!.sub,req.usuarioActual!.rol);
    if(!recorrido)throw new ApiError(404,'El recorrido no está disponible.');
    res.json(await despachosService.listarDespachosDeRecorrido(recorrido.id));}));

const abrirSchema=z.object({marimbaId:z.string().uuid(),operadorId:z.string().uuid().optional(),
  tipoCombustible:z.enum(['Diésel','Magna','Premium']),
  frente:z.string().trim().min(1).max(150),kmInicio:z.coerce.number().nonnegative().nullish(),
  horasEquipoMenorInicio:z.coerce.number().nonnegative().nullish()});
recorridosMarimbaRouter.post('/',requireRole('supervisor') as never,
  asyncHandler(async(req:AuthRequest,res)=>{const d=abrirSchema.parse(req.body);
    const operadorId=d.operadorId??(req.usuarioActual!.rol==='supervisor'?req.usuarioActual!.sub:null);
    if(!operadorId)throw new ApiError(400,'Indica el supervisor responsable del recorrido.');
    res.status(201).json(await recorridosService.crearRecorrido({...d,operadorId,
      registradoPor:req.usuarioActual!.sub}));}));

const despachoSchema=z.object({vehiculoDestinoId:z.string().uuid(),operadorTexto:z.string().trim().min(1).max(150),
  tipoCombustible:z.enum(['Diésel','Magna','Premium']),
  litrosSuministrados:z.coerce.number().positive().nullish(),horometro:z.coerce.number().nonnegative(),
  medidorInicial:z.coerce.number().nonnegative().nullish(),medidorFinal:z.coerce.number().nonnegative().nullish(),
  ubicacion:z.string().trim().max(150).nullish(),observaciones:z.string().trim().max(500).nullish()});
recorridosMarimbaRouter.post('/:id/despachos',requireRole('supervisor') as never,
  upload.fields([{name:'fotoHorometro',maxCount:1},{name:'fotoMedidor',maxCount:1},{name:'fotoEvidencia',maxCount:1}]),
  verificarMagicBytes,asyncHandler(async(req:AuthRequest,res)=>{const recorrido=await recorridosService.buscarRecorridoPorId(req.params.id as string);
    if(!recorrido)throw new ApiError(404,'El recorrido no está disponible.');const d=despachoSchema.parse(req.body);
    const f=req.files as Record<string,Express.Multer.File[]>|undefined;const hor=f?.fotoHorometro?.[0];
    if(!hor)throw new ApiError(400,'La foto del horómetro es obligatoria.');
    res.status(201).json(await recorridosService.agregarDespacho(recorrido.id,{...d,marimbaId:recorrido.marimbaId,
      registradoPor:req.usuarioActual!.sub,
      actorRol:req.usuarioActual!.rol,
      fotoHorometroPath:rutaPublicaDeArchivo(hor.filename),
      fotoMedidorPath:f?.fotoMedidor?.[0]?rutaPublicaDeArchivo(f.fotoMedidor[0].filename):null,
      fotoEvidenciaPath:f?.fotoEvidencia?.[0]?rutaPublicaDeArchivo(f.fotoEvidencia[0].filename):null}));}));

const cerrarSchema=z.object({existenciaFisica:z.coerce.number().nonnegative(),
  observaciones:z.string().trim().max(1000).nullish(),kmCierre:z.coerce.number().nonnegative().nullish(),
  horasEquipoMenorCierre:z.coerce.number().nonnegative().nullish()});
recorridosMarimbaRouter.post('/:id/cerrar',requireRole('supervisor') as never,
  upload.fields([{name:'fotoCierre',maxCount:1},{name:'fotoNivel',maxCount:1}]),verificarMagicBytes,
  asyncHandler(async(req:AuthRequest,res)=>{const d=cerrarSchema.parse(req.body);
    const f=req.files as Record<string,Express.Multer.File[]>|undefined;const cierre=f?.fotoCierre?.[0];const nivel=f?.fotoNivel?.[0];
    if(!cierre||!nivel)throw new ApiError(400,'Las evidencias de cierre y nivel son obligatorias.');
    res.json(await recorridosService.cerrarRecorrido(req.params.id as string,{...d,
      fotoCierrePath:rutaPublicaDeArchivo(cierre.filename),fotoNivelPath:rutaPublicaDeArchivo(nivel.filename)},
      req.usuarioActual!.sub,req.usuarioActual!.rol));}));

recorridosMarimbaRouter.use(limpiarArchivosAnteError);
