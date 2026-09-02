import '../models/vehiculo.dart';

const tipoUnidadVehiculo = 'Vehículo';
const tipoUnidadMarimba = 'Marimba';
const tipoUnidadMaquinaria = 'Maquinaria';
const tipoUnidadPipa = 'Pipa';
const tipoUnidadEquipoMenor = 'Equipo menor';

/// Opciones compartidas por el formulario de "vehículo nuevo" y el catálogo
/// administrativo. Las decisiones operativas usan las constantes y
/// predicados semánticos de este archivo, nunca la posición de esta lista.
/// `Equipo menor` representa accesorios/sub-unidades (migración 0025).
const tiposUnidadVehiculo = [
  tipoUnidadVehiculo,
  tipoUnidadMarimba,
  tipoUnidadMaquinaria,
  tipoUnidadPipa,
  tipoUnidadEquipoMenor,
];

const tiposCombustibleVehiculo = ['Diésel', 'Magna', 'Premium'];

/// `true` si la unidad se mide por horómetro (horas) en vez de kilómetros
/// recorridos — "Maquinaria" y "Equipo menor" (ej. la bomba de una
/// marimba). Rige la etiqueta que ve el chofer al capturar la lectura del
/// medidor y el reporte de mantenimiento.
bool esUnidadPorHorometro(String tipoUnidad) =>
    esMaquinaria(tipoUnidad) || tipoUnidad == tipoUnidadEquipoMenor;

bool esVehiculoLigero(String tipoUnidad) => tipoUnidad == tipoUnidadVehiculo;
bool esMaquinaria(String tipoUnidad) => tipoUnidad == tipoUnidadMaquinaria;
bool esMarimba(String tipoUnidad) => tipoUnidad == tipoUnidadMarimba;
bool esPipa(String tipoUnidad) => tipoUnidad == tipoUnidadPipa;
bool esUnidadGranel(String tipoUnidad) =>
    esMarimba(tipoUnidad) || esPipa(tipoUnidad);
bool estaActiva(Vehiculo unidad) => unidad.activo;

enum CategoriaSolicitud {
  vehiculo('vehiculo'),
  maquinaria('maquinaria'),
  granel('granel');

  const CategoriaSolicitud(this.segmentoRuta);
  final String segmentoRuta;

  bool acepta(Vehiculo unidad) => switch (this) {
    CategoriaSolicitud.vehiculo => esVehiculoLigero(unidad.tipoUnidad),
    CategoriaSolicitud.maquinaria => esMaquinaria(unidad.tipoUnidad),
    CategoriaSolicitud.granel => esUnidadGranel(unidad.tipoUnidad),
  };

  String get tipoInicialReporte => switch (this) {
    CategoriaSolicitud.vehiculo => tipoUnidadVehiculo,
    CategoriaSolicitud.maquinaria => tipoUnidadMaquinaria,
    CategoriaSolicitud.granel => tipoUnidadMarimba,
  };
}

CategoriaSolicitud? categoriaSolicitudDesdeRuta(String? segmento) {
  for (final categoria in CategoriaSolicitud.values) {
    if (categoria.segmentoRuta == segmento) return categoria;
  }
  return null;
}

String etiquetaCategoria(String tipoUnidad) => switch (tipoUnidad) {
  tipoUnidadVehiculo => 'Vehículo',
  tipoUnidadMaquinaria => 'Maquinaria',
  tipoUnidadMarimba => 'Marimba',
  tipoUnidadPipa => 'Pipa',
  tipoUnidadEquipoMenor => 'Equipo menor',
  _ => tipoUnidad,
};

/// Intervalo de servicio general por defecto según el tipo de unidad —
/// editable por unidad individual en el catálogo de vehículos.
double intervaloServicioPorDefecto(String tipoUnidad) =>
    esUnidadPorHorometro(tipoUnidad) ? 250 : 5000;
