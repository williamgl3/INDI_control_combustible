import 'catalogos_vehiculo.dart';

bool intervaloMantenimientoConfigurado(double? intervalo) =>
    intervalo != null && intervalo > 0;

String etiquetaIntervaloMantenimiento(double? intervalo, String tipoUnidad) {
  if (!intervaloMantenimientoConfigurado(intervalo)) return 'No configurado';
  final unidad = esUnidadPorHorometro(tipoUnidad) ? 'h' : 'km';
  return '${intervalo!.toStringAsFixed(0)} $unidad';
}
