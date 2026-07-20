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
    required this.nombreCompleto,
    required this.correo,
    required this.edad,
    required this.rol,
  });

  final String id;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final int edad;
  final RolUsuario rol;

  bool get esChofer => rol == RolUsuario.chofer;
  bool get esAdministrativo => rol == RolUsuario.administrativo;

  Perfil copyWith({
    String? id,
    String? usuario,
    String? nombreCompleto,
    String? correo,
    int? edad,
    RolUsuario? rol,
  }) {
    return Perfil(
      id: id ?? this.id,
      usuario: usuario ?? this.usuario,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correo: correo ?? this.correo,
      edad: edad ?? this.edad,
      rol: rol ?? this.rol,
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
        other.rol == rol;
  }

  @override
  int get hashCode =>
      Object.hash(id, usuario, nombreCompleto, correo, edad, rol);
}
