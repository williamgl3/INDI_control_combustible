import 'package:flutter/foundation.dart';

/// Rol del usuario autenticado. Solo existen estos dos roles.
enum RolUsuario { chofer, administrativo }

/// Perfil de un usuario autenticado.
///
/// Ya NO incluye un vehículo embebido: los vehículos viven en un
/// catálogo compartido (`Vehiculo`, administrado por el área
/// administrativa) porque varios choferes pueden usar distintas unidades
/// en días distintos — fijar un vehículo por chofer generaba
/// incongruencias. El chofer elige su vehículo en cada solicitud/
/// comprobación de carga, no al registrarse.
///
/// Dato que vendrá del backend en el futuro (hoy solo existe vía mocks).
@immutable
class Perfil {
  const Perfil({
    required this.id,
    required this.usuario,
    required this.nombre,
    this.apellidoPaterno,
    this.apellidoMaterno,
    required this.correo,
    this.fechaNacimiento,
    required this.rol,
    this.activo = true,
  });

  final String id;
  final String usuario;
  final String nombre;

  /// `null` para cuentas administrativas dadas de alta desde el panel
  /// (`AuthRepository.crearAdministrativo`), que solo piden
  /// nombre/usuario/correo/password — un chofer siempre lo trae.
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final String correo;

  /// `null` para cuentas administrativas dadas de alta desde el panel,
  /// por el mismo motivo que [apellidoPaterno].
  final DateTime? fechaNacimiento;
  final RolUsuario rol;

  /// `false` si el usuario fue desactivado por un administrativo (ver
  /// `AuthRepository.cambiarEstado`). Un usuario inactivo no puede
  /// iniciar sesión — lo valida el backend, aquí solo se refleja en la UI
  /// (badge en el directorio de choferes/administrativos).
  final bool activo;

  bool get esChofer => rol == RolUsuario.chofer;
  bool get esAdministrativo => rol == RolUsuario.administrativo;

  String get nombreCompleto => [
    nombre,
    if (apellidoPaterno != null && apellidoPaterno!.isNotEmpty) apellidoPaterno,
    if (apellidoMaterno != null && apellidoMaterno!.isNotEmpty) apellidoMaterno,
  ].join(' ');

  /// Edad calculada desde [fechaNacimiento] — no se guarda por separado.
  /// `null` si el perfil no trae fecha de nacimiento (cuentas
  /// administrativas dadas de alta desde el panel).
  int? get edad {
    final nacimiento = fechaNacimiento;
    if (nacimiento == null) return null;
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    final aunNoCumple =
        hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day);
    if (aunNoCumple) edad--;
    return edad;
  }

  Perfil copyWith({
    String? id,
    String? usuario,
    String? nombre,
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? correo,
    DateTime? fechaNacimiento,
    RolUsuario? rol,
    bool? activo,
  }) {
    return Perfil(
      id: id ?? this.id,
      usuario: usuario ?? this.usuario,
      nombre: nombre ?? this.nombre,
      apellidoPaterno: apellidoPaterno ?? this.apellidoPaterno,
      apellidoMaterno: apellidoMaterno ?? this.apellidoMaterno,
      correo: correo ?? this.correo,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
    );
  }

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] as String,
      usuario: json['usuario'] as String,
      nombre: json['nombre'] as String,
      apellidoPaterno: json['apellidoPaterno'] as String?,
      apellidoMaterno: json['apellidoMaterno'] as String?,
      correo: json['correo'] as String,
      fechaNacimiento: json['fechaNacimiento'] != null
          ? DateTime.parse(json['fechaNacimiento'] as String)
          : null,
      rol: RolUsuario.values.byName(json['rol'] as String),
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario': usuario,
      'nombre': nombre,
      'apellidoPaterno': apellidoPaterno,
      'apellidoMaterno': apellidoMaterno,
      'correo': correo,
      'fechaNacimiento': fechaNacimiento == null
          ? null
          : '${fechaNacimiento!.year.toString().padLeft(4, '0')}-'
                '${fechaNacimiento!.month.toString().padLeft(2, '0')}-'
                '${fechaNacimiento!.day.toString().padLeft(2, '0')}',
      'rol': rol.name,
      'activo': activo,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Perfil &&
        other.id == id &&
        other.usuario == usuario &&
        other.nombre == nombre &&
        other.apellidoPaterno == apellidoPaterno &&
        other.apellidoMaterno == apellidoMaterno &&
        other.correo == correo &&
        other.fechaNacimiento == fechaNacimiento &&
        other.rol == rol &&
        other.activo == activo;
  }

  @override
  int get hashCode => Object.hash(
    id,
    usuario,
    nombre,
    apellidoPaterno,
    apellidoMaterno,
    correo,
    fechaNacimiento,
    rol,
    activo,
  );
}
