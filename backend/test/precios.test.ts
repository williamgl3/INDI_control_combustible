import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

import { pool } from '../src/db/pool';
import { ApiError } from '../src/utils/asyncHandler';
import * as preciosService from '../src/services/preciosService';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

function filaPrecio(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    id: 'precio-1',
    tipo_combustible: 'Diésel',
    precio_por_litro: '24.50',
    vigente_desde: new Date('2026-07-01T00:00:00Z'),
    registrado_por: null,
    creado_en: new Date('2026-07-01T00:00:00Z'),
    ...overrides,
  };
}

describe('preciosService.precioDeDecimal', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('devuelve el precio vigente más reciente para esa fecha', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [filaPrecio({ precio_por_litro: '25.80' })] });

    const precio = await preciosService.precioDeDecimal('Diésel', new Date('2026-07-15'));

    expect(precio.toNumber()).toBe(25.8);
    // La consulta debe filtrar por tipo Y por vigente_desde <= fecha —
    // nunca cae a otro tipo de combustible (el bug que se está evitando).
    const [sql, params] = poolQueryMock.mock.calls[0]!;
    expect(sql).toContain('vigente_desde <= $2');
    expect(params).toEqual(['Diésel', new Date('2026-07-15')]);
  });

  it('lanza ApiError(409) explícito si no hay precio vigente para ese tipo — nunca cae a otro tipo', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [] });

    await expect(
      preciosService.precioDeDecimal('Premium', new Date('2026-07-15')),
    ).rejects.toMatchObject({ status: 409 } satisfies Partial<ApiError>);
  });
});

describe('preciosService.registrarPrecio', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('inserta un registro nuevo (no UPDATE) aunque no exista fila previa para ese tipo', async () => {
    // 1) SELECT del valor anterior (para la auditoría) — sin fila previa.
    poolQueryMock.mockResolvedValueOnce({ rows: [] });
    // 2) INSERT ... RETURNING *.
    poolQueryMock.mockResolvedValueOnce({
      rows: [filaPrecio({ tipo_combustible: 'Premium', precio_por_litro: '26.90' })],
    });
    // 3) registrarAuditoria (best-effort).
    poolQueryMock.mockResolvedValueOnce({ rows: [] });

    const precio = await preciosService.registrarPrecio('Premium', 26.9, 'admin-1');

    expect(precio.precioPorLitro).toBe(26.9);
    expect(precio.tipoCombustible).toBe('Premium');
    // La segunda llamada a pool.query debe ser un INSERT, nunca un UPDATE
    // sobre una fila que no existía.
    const [sqlInsert] = poolQueryMock.mock.calls[1]!;
    expect(sqlInsert).toContain('INSERT INTO precios_combustible');
    expect(sqlInsert).not.toContain('UPDATE');
  });

  it('conserva el precio anterior en la auditoría en vez de sobrescribirlo', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [filaPrecio({ precio_por_litro: '24.50' })] });
    poolQueryMock.mockResolvedValueOnce({
      rows: [filaPrecio({ precio_por_litro: '25.80' })],
    });
    poolQueryMock.mockResolvedValueOnce({ rows: [] });

    await preciosService.registrarPrecio('Diésel', 25.8, 'admin-1');

    const [, paramsAuditoria] = poolQueryMock.mock.calls[2]!;
    const detalle = JSON.parse(paramsAuditoria[4] as string);
    expect(detalle).toMatchObject({ valorAnterior: 24.5, valorNuevo: 25.8 });
  });
});

describe('preciosService.listarPrecios', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('trae solo el precio vigente más reciente por tipo (DISTINCT ON)', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [filaPrecio()] });

    await preciosService.listarPrecios();

    const [sql] = poolQueryMock.mock.calls[0]!;
    expect(sql).toContain('DISTINCT ON (tipo_combustible)');
    expect(sql).toContain('ORDER BY tipo_combustible, vigente_desde DESC');
  });
});
