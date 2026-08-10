import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../src/db/pool', () => ({ pool: { query: vi.fn() } }));

import { pool } from '../src/db/pool';
import { validarUnidadParaSolicitud } from '../src/services/solicitudesService';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

function fila(tipoUnidad: string, activo = true) {
  return {
    id: '00000000-0000-4000-8000-000000000001',
    tipo_unidad: tipoUnidad,
    placas: tipoUnidad === 'Maquinaria' ? null : 'ID-OCULTO',
    numero_economico: tipoUnidad === 'Vehículo' ? null : 'E-OCULTO',
    tipo_combustible: 'Diésel',
    modelo: 'Unidad',
    intervalo_servicio: '5000',
    lectura_ultimo_servicio: null,
    fecha_ultimo_servicio: null,
    activo,
    unidad_padre_id: null,
    ubicacion: null,
  };
}

describe('validación de categoría al crear solicitudes', () => {
  beforeEach(() => poolQueryMock.mockReset());

  it.each([
    ['chofer', 'Vehículo'],
    ['chofer', 'Maquinaria'],
    ['supervisor', 'Marimba'],
    ['supervisor', 'Pipa'],
  ] as const)('permite %s con %s activa', async (rol, tipo) => {
    poolQueryMock.mockResolvedValueOnce({ rows: [fila(tipo)] });
    await expect(
      validarUnidadParaSolicitud('unidad-id', rol),
    ).resolves.toMatchObject({ tipoUnidad: tipo, activo: true });
  });

  it.each(['Marimba', 'Pipa'] as const)(
    'rechaza chofer con %s',
    async (tipo) => {
      poolQueryMock.mockResolvedValueOnce({ rows: [fila(tipo)] });
      await expect(
        validarUnidadParaSolicitud('unidad-id', 'chofer'),
      ).rejects.toMatchObject({ status: 403 });
    },
  );

  it('rechaza una unidad inactiva', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [fila('Vehículo', false)] });
    await expect(
      validarUnidadParaSolicitud('unidad-id', 'chofer'),
    ).rejects.toMatchObject({ status: 409 });
  });

  it('responde 404 si la unidad no existe', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [] });
    await expect(
      validarUnidadParaSolicitud('unidad-id', 'chofer'),
    ).rejects.toMatchObject({ status: 404 });
  });
});
