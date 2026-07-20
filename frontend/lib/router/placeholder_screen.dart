import 'package:flutter/material.dart';

/// Placeholder simple usado por todas las rutas hasta que se construyan
/// las pantallas reales en tandas futuras.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(nombre, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}

/// Pantalla mostrada cuando `state.extra` llega inválido/faltante a una
/// ruta que lo requiere (ej. /chofer/respuesta, /chofer/comprobar sin el
/// folio/solicitud esperada). Redirige de vuelta a /chofer.
class RutaInvalidaScreen extends StatelessWidget {
  const RutaInvalidaScreen({super.key, required this.onVolver});

  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esta pantalla no recibió la información esperada.'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onVolver, child: const Text('Volver')),
          ],
        ),
      ),
    );
  }
}
