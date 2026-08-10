import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/capacidades_rol.dart';
import 'package:indi_combustible/core/catalogos_vehiculo.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/vehiculo.dart';

void main() {
  test('clasifica las cuatro categorías sin depender de índices', () {
    expect(esVehiculoLigero('Vehículo'), isTrue);
    expect(esMaquinaria('Maquinaria'), isTrue);
    expect(esMarimba('Marimba'), isTrue);
    expect(esPipa('Pipa'), isTrue);
    expect(esUnidadGranel('Marimba'), isTrue);
    expect(esUnidadGranel('Pipa'), isTrue);
    expect(esUnidadGranel('Maquinaria'), isFalse);
  });

  test('estaActiva excluye unidades inactivas de operaciones', () {
    const unidad = Vehiculo(
      id: '1',
      tipoUnidad: 'Maquinaria',
      placas: null,
      numeroEconomico: 'E-1',
      tipoCombustible: null,
      intervaloServicio: 250,
      activo: false,
    );
    expect(estaActiva(unidad), isFalse);
  });

  test('chofer tiene capacidades operativas propias pero no granel', () {
    expect(
      tieneCapacidad(RolUsuario.chofer, CapacidadOperativa.solicitarVehiculo),
      isTrue,
    );
    expect(
      tieneCapacidad(RolUsuario.chofer, CapacidadOperativa.solicitarMaquinaria),
      isTrue,
    );
    expect(
      tieneCapacidad(
        RolUsuario.chofer,
        CapacidadOperativa.administrarRecorrido,
      ),
      isFalse,
    );
  });

  test('supervisor incorpora granel, despachos y recorridos', () {
    expect(
      tieneCapacidad(
        RolUsuario.supervisor,
        CapacidadOperativa.solicitarUnidadGranel,
      ),
      isTrue,
    );
    expect(
      tieneCapacidad(
        RolUsuario.supervisor,
        CapacidadOperativa.registrarDespacho,
      ),
      isTrue,
    );
    expect(
      tieneCapacidad(
        RolUsuario.supervisor,
        CapacidadOperativa.administrarRecorrido,
      ),
      isTrue,
    );
  });
}
