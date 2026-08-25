import { beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({ pool: { query: vi.fn() } }));
vi.mock('../src/services/choferesService', () => ({
  cambiarEstado: vi.fn(), obtener: vi.fn(), editar: vi.fn(),
  solicitarReset: vi.fn(), elegibilidadEliminacion: vi.fn(), eliminarDefinitivamente: vi.fn(),
}));

import { pool } from '../src/db/pool';
import * as choferesService from '../src/services/choferesService';
import { firmarToken } from '../src/utils/jwt';
import { crearAppDePrueba } from './testApp';

const query = pool.query as unknown as ReturnType<typeof vi.fn>;
const cambiarEstado = choferesService.cambiarEstado as unknown as ReturnType<typeof vi.fn>;
const eliminar = choferesService.eliminarDefinitivamente as unknown as ReturnType<typeof vi.fn>;
const id = '22222222-2222-4222-8222-222222222222';
const actorId = '11111111-1111-4111-8111-111111111111';
function token(rol: 'chofer'|'supervisor'|'administrativo'|'superadmin', sub=actorId) { return firmarToken({sub, usuario:'actor', rol, tokenVersion:1}); }
function auth(t:string){return {Authorization:`Bearer ${t}`};}

describe('gestión de estado de choferes',()=>{
  beforeEach(()=>{query.mockReset();cambiarEstado.mockReset();eliminar.mockReset();query.mockResolvedValue({rows:[{token_version:1,activo:true}]});cambiarEstado.mockResolvedValue({id,rol:'chofer',activo:false});});
  it('responde 401 sin sesión',async()=>{expect((await request(crearAppDePrueba()).post(`/usuarios/choferes/${id}/desactivar`).send({motivo:'prueba válida'})).status).toBe(401);});
  it.each(['chofer','supervisor'] as const)('responde 403 para rol %s',async(rol)=>{const r=await request(crearAppDePrueba()).post(`/usuarios/choferes/${id}/desactivar`).set(auth(token(rol))).send({motivo:'prueba válida'});expect(r.status).toBe(403);});
  it.each(['administrativo','superadmin'] as const)('permite desactivar a %s y pasa actor/motivo',async(rol)=>{const r=await request(crearAppDePrueba()).post(`/usuarios/choferes/${id}/desactivar`).set(auth(token(rol))).send({motivo:'baja solicitada'});expect(r.status).toBe(200);expect(cambiarEstado).toHaveBeenCalledWith(id,false,'baja solicitada',actorId);});
  it('rechaza motivo ausente',async()=>{const r=await request(crearAppDePrueba()).post(`/usuarios/choferes/${id}/desactivar`).set(auth(token('administrativo'))).send({});expect(r.status).toBe(400);expect(cambiarEstado).not.toHaveBeenCalled();});
});

describe('DELETE /usuarios/choferes/:id',()=>{
  beforeEach(()=>{query.mockReset();eliminar.mockReset();query.mockResolvedValue({rows:[{token_version:1,activo:true}]});});
  const body={usuarioConfirmado:'@prueba',motivo:'cuenta de prueba'};
  it('administrativo no puede eliminar',async()=>{const r=await request(crearAppDePrueba()).delete(`/usuarios/choferes/${id}`).set(auth(token('administrativo'))).send(body);expect(r.status).toBe(403);expect(eliminar).not.toHaveBeenCalled();});
  it('superadmin puede solicitar eliminación elegible',async()=>{const r=await request(crearAppDePrueba()).delete(`/usuarios/choferes/${id}`).set(auth(token('superadmin'))).send(body);expect(r.status).toBe(204);expect(eliminar).toHaveBeenCalledWith(id,'@prueba','cuenta de prueba',actorId);});
  it('sin sesión recibe 401',async()=>{expect((await request(crearAppDePrueba()).delete(`/usuarios/choferes/${id}`).send(body)).status).toBe(401);});
});
