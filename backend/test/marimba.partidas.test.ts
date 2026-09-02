import { describe, expect, it } from 'vitest';
import { crearSolicitudConPartidas, validarPartidas } from '../src/services/marimbaPartidasService';

const consumo = {
  tipo: 'consumo_propio' as const,
  litros: 30,
  tipoCombustible: 'Diésel',
};
const granel = {
  tipo: 'carga_granel' as const,
  litros: 100,
  tipoCombustible: 'Diésel',
};

describe('partidas de unidad abastecedora', () => {
  it('acepta combustible de granel distinto al combustible del motor', () => {
    expect(() =>
      validarPartidas([consumo, { ...granel, tipoCombustible: 'Magna' }]),
    ).not.toThrow();
  });

  it('rechaza un combustible fuera del catálogo', () => {
    expect(() => validarPartidas([{ ...granel, tipoCombustible: 'Otro' }])).toThrow(
      'El tipo de combustible no es válido.',
    );
  });

  it.each([{ partidas: [consumo] }, { partidas: [granel] }, { partidas: [consumo, granel] }])(
    'acepta una o ambas partidas',
    ({ partidas }) => {
      expect(() => validarPartidas(partidas)).not.toThrow();
    },
  );

  it('rechaza una solicitud vacía o un concepto duplicado', () => {
    expect(() => validarPartidas([])).toThrow();
    expect(() => validarPartidas([consumo, consumo])).toThrow();
  });

  it.each([0, -1])('rechaza litros no positivos: %s', (litros) => {
    expect(() => validarPartidas([{ ...granel, litros }])).toThrow();
  });

  it('impide que un chofer use el flujo granel antes de consultar la base', async () => {
    await expect(
      crearSolicitudConPartidas({
        solicitanteId: '00000000-0000-4000-8000-000000000001',
        rol: 'chofer',
        vehiculoId: '00000000-0000-4000-8000-000000000002',
        partidas: [granel],
        actividad: 'Prueba',
        fechaProgramada: new Date().toISOString(),
        esUrgente: false,
      }),
    ).rejects.toMatchObject({ status: 403 });
  });
});
