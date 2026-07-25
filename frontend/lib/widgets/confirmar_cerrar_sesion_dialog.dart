import 'package:flutter/material.dart';

/// Confirmación antes de cerrar sesión — evita que un toque accidental
/// sobre "Cerrar sesión" en el menú de 3 puntos saque a alguien de la
/// app en mitad de una solicitud sin querer.
Future<bool> confirmarCerrarSesion(BuildContext context) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Cerrar sesión?'),
      content: const Text('Vas a salir de tu cuenta en este dispositivo.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}
