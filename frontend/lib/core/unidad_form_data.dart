import 'catalogos_vehiculo.dart';

const tiposUnidadAdministrables = [
  tipoUnidadVehiculo,
  tipoUnidadMaquinaria,
  tipoUnidadMarimba,
  tipoUnidadPipa,
];

class UnidadFormData {
  const UnidadFormData({
    required this.tipoUnidad,
    required this.modelo,
    required this.placas,
    required this.numeroEconomico,
    required this.tipoCombustible,
    required this.intervaloServicio,
    required this.ubicacion,
    required this.activo,
    this.unidadPadreId,
  });

  final String tipoUnidad;
  final String modelo;
  final String? placas;
  final String? numeroEconomico;
  final String tipoCombustible;
  final double? intervaloServicio;
  final String? ubicacion;
  final bool activo;
  final String? unidadPadreId;

  static String? textoOpcional(String? valor, {bool mayusculas = false}) {
    final limpio = valor?.trim() ?? '';
    if (limpio.isEmpty) return null;
    return mayusculas ? limpio.toUpperCase() : limpio;
  }
}

class UnidadFormValidators {
  const UnidadFormValidators._();

  static String? modelo(String? valor) => (valor?.trim().isEmpty ?? true)
      ? 'Ingresa el modelo o nombre de la unidad'
      : null;

  static String? identificadores(String? placas, String? numeroEconomico) {
    if ((placas?.trim().isEmpty ?? true) &&
        (numeroEconomico?.trim().isEmpty ?? true)) {
      return 'Captura las placas o el número económico';
    }
    return null;
  }

  static String? intervalo(String? valor) {
    final limpio = valor?.trim() ?? '';
    if (limpio.isEmpty) return null;
    final numero = double.tryParse(limpio);
    if (numero == null || numero <= 0) {
      return 'El intervalo debe ser mayor que cero';
    }
    return null;
  }
}
