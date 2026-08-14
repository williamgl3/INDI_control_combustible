import '../core/catalogos_vehiculo.dart';

/// Rutas de la app. Fuente de verdad de paths para evitar strings sueltos.
class RoutePaths {
  const RoutePaths._();

  static const bienvenida = '/';
  static const login = '/login';
  static const registroChofer = '/registro-chofer';
  static const recuperarPassword = '/recuperar-password';

  static const chofer = '/chofer';
  static const choferTipoOperacion = '/chofer/tipo-operacion';
  static const choferSolicitar = '/chofer/solicitar';
  static const choferSolicitarConCategoria = '/chofer/solicitar/:categoria';

  static String solicitud(CategoriaSolicitud categoria) =>
      '$choferSolicitar/${categoria.segmentoRuta}';
  static const choferRegistrarDespacho = '/chofer/registrar-despacho';
  static const choferRecorridoMarimba = '/chofer/recorrido-marimba';
  static const choferRespuesta = '/chofer/respuesta';
  static const choferComprobar = '/chofer/comprobar';
  static const choferCerrarDia = '/chofer/cerrar-dia';
  static const choferSolicitudes = '/chofer/solicitudes';
  static const choferPerfil = '/chofer/perfil';
  static const choferDashboard = '/chofer/dashboard';
  static const choferSubirEvidencias = '/chofer/subir-evidencias';

  static const administrativo = '/administrativo';
  static const administrativoMarimba = '/administrativo/marimba-pipa';
  static const administrativoChoferDetalle = '/administrativo/chofer';

  /// Rutas accesibles sin sesión iniciada.
  static const publicas = {
    bienvenida,
    login,
    registroChofer,
    recuperarPassword,
  };
}
