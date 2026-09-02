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

  test('chofer conserva operaciones de campo sin funciones de marimba', () {
    expect(capacidadesDe(RolUsuario.chofer), {
      CapacidadOperativa.solicitarVehiculo,
      CapacidadOperativa.solicitarMaquinaria,
      CapacidadOperativa.comprobarCarga,
      CapacidadOperativa.subirEvidencias,
      CapacidadOperativa.cerrarJornada,
      CapacidadOperativa.consultarHistorial,
      CapacidadOperativa.reportarIncidencia,
    });
  });

  test('supervisor hereda campo y agrega funciones de marimba', () {
    expect(capacidadesDe(RolUsuario.supervisor), {
      ...capacidadesDe(RolUsuario.chofer),
      CapacidadOperativa.solicitarUnidadGranel,
      CapacidadOperativa.registrarDespacho,
      CapacidadOperativa.administrarRecorrido,
    });
  });

  test('roles administrativos no reciben operaciones de campo', () {
    expect(capacidadesDe(RolUsuario.administrativo), isEmpty);
    expect(capacidadesDe(RolUsuario.superadmin), isEmpty);
  });
}
