import { describe, expect, it } from 'vitest';
import {
  actualizarVehiculoSchema,
  crearVehiculoSchema,
} from '../src/routes/vehiculos.routes';

const base = {
  tipoUnidad: 'Vehículo',
  modelo: 'Unidad de prueba',
  placas: 'AA-000-A',
  numeroEconomico: null,
  tipoCombustible: 'Diésel',
};

describe('contrato administrativo de unidades', () => {
  it('rechaza modelo vacío', () => {
    expect(() => crearVehiculoSchema.parse({ ...base, modelo: ' ' })).toThrow();
  });

  it('rechaza ambos identificadores vacíos', () => {
    expect(() =>
      crearVehiculoSchema.parse({ ...base, placas: ' ', numeroEconomico: null }),
    ).toThrow();
  });

  it.each([
    [{ placas: 'AA-000-A', numeroEconomico: null }, 'solo placas'],
    [{ placas: null, numeroEconomico: 'EQ-001' }, 'solo económico'],
    [{ placas: 'AA-000-A', numeroEconomico: 'EQ-001' }, 'ambos'],
  ])('acepta %s', (identificadores) => {
    expect(
      crearVehiculoSchema.parse({ ...base, ...identificadores }),
    ).toBeDefined();
  });

  it.each([0, -1])('rechaza intervalo %s', (intervaloServicio) => {
    expect(() =>
      crearVehiculoSchema.parse({ ...base, intervaloServicio }),
    ).toThrow();
  });

  it('acepta intervalo positivo y aplica activo=true por defecto', () => {
    const datos = crearVehiculoSchema.parse({ ...base, intervaloServicio: 250 });
    expect(datos.intervaloServicio).toBe(250);
    expect(datos.activo).toBe(true);
  });

  it('acepta intervalo null en creación y edición', () => {
    expect(
      crearVehiculoSchema.parse({ ...base, intervaloServicio: null })
        .intervaloServicio,
    ).toBeNull();
    expect(
      actualizarVehiculoSchema.parse({ intervaloServicio: null }),
    ).toEqual({ intervaloServicio: null });
  });

  it.each([0, -1])('edición rechaza intervalo %s', (intervaloServicio) => {
    expect(() =>
      actualizarVehiculoSchema.parse({ intervaloServicio }),
    ).toThrow();
  });

  it.each(['Vehículo', 'Maquinaria', 'Marimba', 'Pipa'] as const)(
    'acepta la categoría %s',
    (tipoUnidad) => {
      expect(crearVehiculoSchema.parse({ ...base, tipoUnidad })).toBeDefined();
    },
  );

  it('edición aplica las mismas restricciones a campos presentes', () => {
    expect(() => actualizarVehiculoSchema.parse({ modelo: '' })).toThrow();
    expect(() =>
      actualizarVehiculoSchema.parse({ intervaloServicio: 0 }),
    ).toThrow();
    expect(
      actualizarVehiculoSchema.parse({
        modelo: 'Unidad editada',
        activo: false,
      }),
    ).toEqual({ modelo: 'Unidad editada', activo: false });
  });
});
