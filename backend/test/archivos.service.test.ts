import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../src/db/pool', () => ({ pool: { query: vi.fn() } }));

import { pool } from '../src/db/pool';
import { localizarReferencias, referenciasPersistidasPara } from '../src/services/archivosService';

const queryMock = pool.query as unknown as ReturnType<typeof vi.fn>;
const key = '550e8400-e29b-41d4-a716-446655440000.jpg';

describe('archivosService', () => {
  beforeEach(() => queryMock.mockReset());

  it('normaliza referencias históricas y privadas sin aceptar una URL externa', () => {
    expect(referenciasPersistidasPara(key)).toEqual([`/uploads/${key}`, `/archivos/${key}`, key]);
  });

  it('consulta foto_url, foto_urls y deriva despachos desde recorridos con parámetros', async () => {
    queryMock.mockResolvedValue({
      rows: [
        { tipo: 'evidencia', propietario_id: 'usuario-1' },
        { tipo: 'despacho_horometro', propietario_id: 'supervisor-1' },
      ],
    });
    const resultado = await localizarReferencias(key);
    const [sql, parametros] = queryMock.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain('e.foto_url = ANY');
    expect(sql).toContain('e.foto_urls &&');
    expect(sql).toContain('LEFT JOIN recorridos_marimba r ON r.id = d.recorrido_id');
    expect(sql).not.toContain('comprobantes_carga');
    expect(sql).not.toContain(key);
    expect(parametros).toEqual([referenciasPersistidasPara(key)]);
    expect(resultado).toEqual([
      { tipo: 'evidencia', propietarioId: 'usuario-1' },
      { tipo: 'despacho_horometro', propietarioId: 'supervisor-1' },
    ]);
  });
});

