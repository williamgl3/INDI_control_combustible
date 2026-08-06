/// Opciones compartidas por el formulario de "vehículo nuevo" (chofer) y
/// el catálogo de vehículos (admin).
/// 'Equipo menor' se agrega al final (índice 4) para no romper ninguna
/// referencia por índice existente (`tiposUnidadVehiculo[1]` sigue siendo
/// 'Marimba', usado en `tipo_operacion_screen.dart`) — es la categoría de
/// accesorios/sub-unidades (ver `Vehiculo.unidadPadreId`, migración
/// 0025), como el equipo menor de gasolina de una marimba.
const tiposUnidadVehiculo = [
  'Vehículo',
  'Marimba',
  'Maquinaria',
  'Pipa',
  'Equipo menor',
];

const tiposCombustibleVehiculo = ['Diésel', 'Magna', 'Premium'];

/// `true` si la unidad se mide por horómetro (horas) en vez de kilómetros
/// recorridos — "Maquinaria" y "Equipo menor" (ej. la bomba de una
/// marimba). Rige la etiqueta que ve el chofer al capturar la lectura del
/// medidor y el reporte de mantenimiento.
bool esUnidadPorHorometro(String tipoUnidad) =>
    tipoUnidad == 'Maquinaria' || tipoUnidad == 'Equipo menor';

/// Intervalo de servicio general por defecto según el tipo de unidad —
/// editable por unidad individual en el catálogo de vehículos.
double intervaloServicioPorDefecto(String tipoUnidad) =>
    esUnidadPorHorometro(tipoUnidad) ? 250 : 5000;
