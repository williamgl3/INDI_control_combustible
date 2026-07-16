/// Rutas de la app. Fuente de verdad de paths para evitar strings sueltos.
class RoutePaths {
  const RoutePaths._();

  static const login = '/login';
  static const registroChofer = '/registro-chofer';
  static const recuperarPassword = '/recuperar-password';

  static const chofer = '/chofer';
  static const choferSolicitar = '/chofer/solicitar';
  static const choferRespuesta = '/chofer/respuesta';
  static const choferComprobar = '/chofer/comprobar';
  static const choferCerrarDia = '/chofer/cerrar-dia';

  static const administrativo = '/administrativo';
  static const administrativoChoferDetalle = '/administrativo/chofer';

  /// Rutas accesibles sin sesión iniciada.
  static const publicas = {login, registroChofer, recuperarPassword};
}
