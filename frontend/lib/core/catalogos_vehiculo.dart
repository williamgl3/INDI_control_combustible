/// Opciones compartidas por el formulario de "vehículo nuevo" (chofer) y
/// el catálogo de vehículos (admin).
///
/// TODO-SPEC: valores PLACEHOLDER hasta tener SPEC.md.
const tiposUnidadVehiculo = ['Vehículo', 'Pipa', 'Maquinaria'];

const tiposCombustibleVehiculo = ['Diésel', 'Gasolina'];

/// `true` si la unidad se mide por horómetro (horas) en vez de kilómetros
/// recorridos — hoy solo "Maquinaria". Rige la etiqueta que ve el chofer
/// al capturar la lectura del medidor y el reporte de mantenimiento.
bool esUnidadPorHorometro(String tipoUnidad) => tipoUnidad == 'Maquinaria';

/// Intervalo de servicio general por defecto según el tipo de unidad —
/// editable por unidad individual en el catálogo de vehículos.
/// TODO-SPEC: valores PLACEHOLDER hasta tener SPEC.md.
double intervaloServicioPorDefecto(String tipoUnidad) =>
    esUnidadPorHorometro(tipoUnidad) ? 250 : 5000;
