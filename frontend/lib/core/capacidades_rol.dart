import '../models/perfil.dart';
import 'catalogos_vehiculo.dart';

enum CapacidadOperativa {
  solicitarVehiculo,
  solicitarMaquinaria,
  solicitarUnidadGranel,
  registrarDespacho,
  administrarRecorrido,
  comprobarCarga,
  subirEvidencias,
  cerrarJornada,
  consultarHistorial,
  reportarIncidencia,
}

Set<CapacidadOperativa> capacidadesDe(RolUsuario rol) => switch (rol) {
  RolUsuario.chofer => const {
    CapacidadOperativa.solicitarVehiculo,
    CapacidadOperativa.solicitarMaquinaria,
    CapacidadOperativa.comprobarCarga,
    CapacidadOperativa.subirEvidencias,
    CapacidadOperativa.cerrarJornada,
    CapacidadOperativa.consultarHistorial,
    CapacidadOperativa.reportarIncidencia,
  },
  RolUsuario.supervisor => const {
    CapacidadOperativa.solicitarVehiculo,
    CapacidadOperativa.solicitarMaquinaria,
    CapacidadOperativa.solicitarUnidadGranel,
    CapacidadOperativa.registrarDespacho,
    CapacidadOperativa.administrarRecorrido,
    CapacidadOperativa.comprobarCarga,
    CapacidadOperativa.subirEvidencias,
    CapacidadOperativa.cerrarJornada,
    CapacidadOperativa.consultarHistorial,
    CapacidadOperativa.reportarIncidencia,
  },
  RolUsuario.administrativo || RolUsuario.superadmin => const {},
};

bool tieneCapacidad(RolUsuario rol, CapacidadOperativa capacidad) =>
    capacidadesDe(rol).contains(capacidad);

bool puedeSolicitarCategoria(RolUsuario rol, CategoriaSolicitud categoria) =>
    switch (categoria) {
      CategoriaSolicitud.vehiculo => tieneCapacidad(
        rol,
        CapacidadOperativa.solicitarVehiculo,
      ),
      CategoriaSolicitud.maquinaria => tieneCapacidad(
        rol,
        CapacidadOperativa.solicitarMaquinaria,
      ),
      CategoriaSolicitud.granel => tieneCapacidad(
        rol,
        CapacidadOperativa.solicitarUnidadGranel,
      ),
    };
