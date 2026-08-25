import { beforeEach, describe, expect, it, vi } from 'vitest';

const { query, connect } = vi.hoisted(() => ({ query: vi.fn(), connect: vi.fn() }));
vi.mock('../src/db/pool', () => ({ pool: { query, connect } }));
vi.mock('../src/services/auditoriaService', () => ({ registrarAuditoria: vi.fn() }));

import * as servicio from '../src/services/choferesService';

const id = '22222222-2222-4222-8222-222222222222';
const actor = '11111111-1111-4111-8111-111111111111';

function clienteCon(responder: (sql: string) => unknown) {
  const clientQuery = vi.fn(async (sql: string) => responder(sql));
  connect.mockResolvedValue({ query: clientQuery, release: vi.fn() });
  return clientQuery;
}

describe('política de eliminación definitiva de choferes', () => {
  beforeEach(() => { query.mockReset(); connect.mockReset(); });

  it('rechaza con 409 una cuenta con historia y no ejecuta DELETE', async () => {
    const q = clienteCon((sql) => {
      if (sql === 'BEGIN' || sql === 'ROLLBACK') return { rows: [] };
      if (sql.includes("SELECT usuario, activo")) return { rows: [{ usuario: 'prueba', activo: false }] };
      if (sql.includes('information_schema.table_constraints')) return { rows: [{ table_name: 'cargas', column_name: 'chofer_id' }] };
      if (sql.includes('FROM "cargas"')) return { rows: [{ total: 1 }] };
      if (sql.includes("entidad='usuario'")) return { rows: [{ total: 0 }] };
      return { rows: [] };
    });
    await expect(servicio.eliminarDefinitivamente(id, '@prueba', 'cuenta de prueba', actor)).rejects.toMatchObject({ status: 409 });
    expect(q.mock.calls.some(([sql]) => String(sql).startsWith('DELETE FROM usuarios'))).toBe(false);
  });

  it('elimina sesiones y cuenta sin relaciones en una sola transacción, conservando auditoría', async () => {
    const q = clienteCon((sql) => {
      if (sql.includes("SELECT usuario, activo")) return { rows: [{ usuario: 'prueba', activo: false }] };
      if (sql.includes('information_schema.table_constraints')) return { rows: [] };
      if (sql.includes("entidad='usuario'")) return { rows: [{ total: 0 }] };
      return { rows: [] };
    });
    await servicio.eliminarDefinitivamente(id, '@prueba', 'cuenta de prueba', actor);
    const sentencias = q.mock.calls.map(([sql]) => String(sql));
    expect(sentencias[0]).toBe('BEGIN');
    expect(sentencias).toContain('DELETE FROM refresh_tokens WHERE usuario_id=$1');
    expect(sentencias.some((sql) => sql.includes("'chofer_eliminado'"))).toBe(true);
    expect(sentencias.some((sql) => sql.startsWith('DELETE FROM usuarios'))).toBe(true);
    expect(sentencias.at(-1)).toBe('COMMIT');
  });

  it('no elimina una cuenta activa aunque no tenga relaciones', async () => {
    const q = clienteCon((sql) => sql.includes("SELECT usuario, activo") ? { rows: [{ usuario: 'prueba', activo: true }] } : { rows: [] });
    await expect(servicio.eliminarDefinitivamente(id, '@prueba', 'cuenta de prueba', actor)).rejects.toMatchObject({ status: 409 });
    expect(q.mock.calls.some(([sql]) => String(sql).startsWith('DELETE FROM usuarios'))).toBe(false);
  });
});

describe('listado de choferes', () => {
  it('impone rol chofer, búsqueda, filtro y límite desde SQL parametrizado', async () => {
    query.mockResolvedValueOnce({ rows: [{ total: 0 }] }).mockResolvedValueOnce({ rows: [] });
    await servicio.listar({ buscar: 'juan', estado: 'activo', pagina: 1, limite: 25 });
    const sql = String(query.mock.calls[1]?.[0]);
    expect(sql).toContain("u.rol = 'chofer'");
    expect(sql).toContain('u.activo = $1');
    expect(sql).toContain('ILIKE $2');
    expect(query.mock.calls[1]?.[1]).toEqual([true, '%juan%', 25, 0]);
  });
});
