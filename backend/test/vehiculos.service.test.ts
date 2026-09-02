import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../src/db/pool', () => ({ pool: { query: vi.fn() } }));

import { pool } from '../src/db/pool';
import {
  actualizarVehiculo,
  crearVehiculo,
} from '../src/services/vehiculosService';

const query = pool.query as unknown as ReturnType<typeof vi.fn>;

function errorUnico(constraint: string) {
  return Object.assign(new Error('duplicate key'), {
    code: '23505',
    constraint,
  });
}

const fila = {
  id: '00000000-0000-4000-8000-000000000001',
  tipo_unidad: 'Vehículo',
  placas: 'TEST-001',
  numero_economico: null,
  tipo_combustible: 'Diésel',
  modelo: 'Unidad',
  intervalo_servicio: '5000',
  lectura_ultimo_servicio: null,
  fecha_ultimo_servicio: null,
  activo: true,
  unidad_padre_id: null,
  ubicacion: null,
};

describe('duplicidad de identificadores de unidades', () => {
  beforeEach(() => query.mockReset());

  it('devuelve 409 genérico para placas duplicadas', async () => {
    query.mockRejectedValueOnce(errorUnico('vehiculos_placas_normalizada_key'));
    await expect(
      crearVehiculo({
        tipoUnidad: 'Vehículo',
        modelo: 'Unidad',
        placas: 'AA-000-A',
        tipoCombustible: 'Diésel',
        activo: true,
      }),
    ).rejects.toMatchObject({
      status: 409,
      message: 'Ya existe una unidad con esas placas.',
    });
  });

  it('devuelve 409 genérico para número económico duplicado', async () => {
    query.mockRejectedValueOnce(
      errorUnico('vehiculos_numero_economico_normalizado_key'),
    );
    await expect(
      crearVehiculo({
        tipoUnidad: 'Maquinaria',
        modelo: 'Unidad',
        numeroEconomico: 'EQ-001',
        tipoCombustible: 'Diésel',
        activo: true,
      }),
    ).rejects.toMatchObject({
      status: 409,
      message: 'Ya existe una unidad con ese número económico.',
    });
  });
});

describe('intervalo nullable y actualizaciones', () => {
  beforeEach(() => query.mockReset());

  it('crear sin intervalo envía NULL y la respuesta conserva null', async () => {
    query.mockResolvedValueOnce({
      rows: [{ ...fila, intervalo_servicio: null }],
    });
    const creado = await crearVehiculo({
      tipoUnidad: 'Vehículo',
      modelo: 'Unidad',
      placas: 'TEST-001',
      tipoCombustible: 'Diésel',
      activo: true,
    });
    expect(query.mock.calls[0]![1]![5]).toBeNull();
    expect(creado.intervaloServicio).toBeNull();
  });

  it('crear con intervalo conserva el valor positivo', async () => {
    query.mockResolvedValueOnce({ rows: [fila] });
    await crearVehiculo({
      tipoUnidad: 'Vehículo',
      modelo: 'Unidad',
      placas: 'TEST-001',
      tipoCombustible: 'Diésel',
      intervaloServicio: 5000,
      activo: true,
    });
    expect(query.mock.calls[0]![1]![5]).toBe(5000);
  });

  it.each([0, -1])('servicio rechaza intervalo nuevo %s', async (intervaloServicio) => {
    await expect(
      crearVehiculo({
        tipoUnidad: 'Vehículo',
        modelo: 'Unidad',
        placas: 'TEST-001',
        tipoCombustible: 'Diésel',
        intervaloServicio,
        activo: true,
      }),
    ).rejects.toMatchObject({ status: 400 });
    expect(query).not.toHaveBeenCalled();
  });

  it.each([
    ['omitido', {}, 5000],
    ['null', { intervaloServicio: null }, null],
    ['positivo', { intervaloServicio: 250 }, 250],
  ])('actualizar intervalo %s aplica la semántica esperada', async (_, cambios, esperado) => {
    query
      .mockResolvedValueOnce({ rows: [fila] })
      .mockResolvedValueOnce({
        rows: [
          {
            ...fila,
            intervalo_servicio: esperado === null ? null : String(esperado),
          },
        ],
      })
      .mockResolvedValueOnce({ rows: [] });

    const actualizado = await actualizarVehiculo(fila.id, cambios);
    expect(query.mock.calls[1]![1]![5]).toBe(esperado);
    expect(actualizado.intervaloServicio).toBe(esperado);
  });

  it('conservar identificadores propios no produce conflicto', async () => {
    query
      .mockResolvedValueOnce({ rows: [fila] })
      .mockResolvedValueOnce({ rows: [fila] })
      .mockResolvedValueOnce({ rows: [] });
    await expect(
      actualizarVehiculo(fila.id, {
        placas: fila.placas,
        numeroEconomico: fila.numero_economico,
      }),
    ).resolves.toMatchObject({ placas: fila.placas });
  });

  it('duplicado de otra unidad al editar devuelve 409 sin exponer el valor', async () => {
    query
      .mockResolvedValueOnce({ rows: [fila] })
      .mockRejectedValueOnce(errorUnico('vehiculos_placas_normalizada_key'));
    await expect(
      actualizarVehiculo(fila.id, { placas: 'OTRA-001' }),
    ).rejects.toMatchObject({
      status: 409,
      message: 'Ya existe una unidad con esas placas.',
    });
  });
});
