import 'package:flutter/foundation.dart';

import 'vehiculo.dart';

/// Rol del usuario autenticado. Solo existen estos dos roles.
enum RolUsuario { chofer, administrativo }

/// Perfil de un usuario autenticado.
///
/// Si [rol] es [RolUsuario.chofer], [vehiculo] siempre está presente:
/// sus datos se capturan una sola vez en /registro-chofer, en la misma
/// transacción que crea el perfil, y quedan embebidos aquí (no como
/// referencia a un catálogo externo). Esto permite precargarlos en
/// /chofer/comprobar sin volver a pedirlos.
///
/// Dato que vendrá del backend en el futuro (hoy solo existe vía mocks).
@immutable
class Perfil {
  const Perfil({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
    required this.correo,
    required this.edad,
    required this.rol,
    this.vehiculo,
  }) : assert(
          rol != RolUsuario.chofer || vehiculo != null,
          'Un perfil de chofer siempre debe tener vehículo embebido.',
        );

  final String id;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final int edad;
  final RolUsuario rol;

  /// Solo presente (y obligatorio) cuando [rol] == [RolUsuario.chofer].
  final Vehiculo? vehiculo;

  bool get esChofer => rol == RolUsuario.chofer;
  bool get esAdministrativo => rol == RolUsuario.administrativo;

  Perfil copyWith({
    String? id,
    String? usuario,
    String? nombreCompleto,
    String? correo,
    int? edad,
    RolUsuario? rol,
    Vehiculo? vehiculo,
  }) {
    return Perfil(
      id: id ?? this.id,
      usuario: usuario ?? this.usuario,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correo: correo ?? this.correo,
      edad: edad ?? this.edad,
      rol: rol ?? this.rol,
      vehiculo: vehiculo ?? this.vehiculo,
    );
  }

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      correo: json['correo'] as String,
      edad: json['edad'] as int,
      rol: RolUsuario.values.byName(json['rol'] as String),
      vehiculo: json['vehiculo'] == null
          ? null
          : Vehiculo.fromJson(json['vehiculo'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario': usuario,
      'nombreCompleto': nombreCompleto,
      'correo': correo,
      'edad': edad,
      'rol': rol.name,
      'vehiculo': vehiculo?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Perfil &&
        other.id == id &&
        other.usuario == usuario &&
        other.nombreCompleto == nombreCompleto &&
        other.correo == correo &&
        other.edad == edad &&
        other.rol == rol &&
        other.vehiculo == vehiculo;
  }

  @override
  int get hashCode =>
      Object.hash(id, usuario, nombreCompleto, correo, edad, rol, vehiculo);
}
