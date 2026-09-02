import 'package:flutter/material.dart';

/// Diálogo de "se guardó localmente, se enviará sola al reconectar" —
/// mostrado por las 4 colas offline del chofer (solicitar carga, comprobar
/// carga, cerrar día, reportar incidencia). Antes cada pantalla repetía el
/// mismo `AlertDialog` (ícono + título + botón "Entendido"), solo cambiando
/// el texto del cuerpo — aquí se centraliza la estructura y cada pantalla
/// solo aporta [mensaje] con su propia redacción.
class SinConexionDialog {
  const SinConexionDialog._();

  static Future<void> show(BuildContext context, {required String mensaje}) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_off_outlined),
        title: const Text('Sin conexión'),
        content: Text(mensaje),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
