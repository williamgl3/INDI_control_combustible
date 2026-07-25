import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/vehiculo.dart';
import '../screens/chofer/reportar_vehiculo_nuevo_dialog.dart';
import '../theme/app_borders.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';

const _valorVehiculoNuevo = '__nuevo__';

/// Selector de "qué vehículo vas a usar" — se elige en cada solicitud/
/// comprobación de carga, ya no es un dato fijo del perfil del chofer
/// (ver `Vehiculo`). Incluye la opción de reportar una unidad que no
/// está en el catálogo.
class SelectorVehiculo extends ConsumerWidget {
  const SelectorVehiculo({
    super.key,
    required this.vehiculoSeleccionado,
    required this.onSeleccionar,
  });

  final Vehiculo? vehiculoSeleccionado;
  final ValueChanged<Vehiculo> onSeleccionar;

  Future<void> _manejarSeleccion(
    BuildContext context,
    WidgetRef ref,
    String? valor,
  ) async {
    if (valor == null) return;
    if (valor == _valorVehiculoNuevo) {
      final nuevo = await ReportarVehiculoNuevoDialog.show(context);
      if (nuevo != null) onSeleccionar(nuevo);
      return;
    }
    final repo = ref.read(vehiculosRepositoryProvider);
    final vehiculo = repo.porId(valor);
    if (vehiculo != null) onSeleccionar(vehiculo);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    ref.watch(
      operacionesTickProvider,
    ); // el catálogo puede crecer (vehículo nuevo)
    final vehiculos = ref.watch(vehiculosRepositoryProvider).todos;

    // Fondo blanco + sombra propia (en vez del `fillColor` gris casi
    // idéntico al fondo de la pantalla que usa el resto de los inputs) —
    // así combina con el resto de cards de la pantalla en vez de verse
    // plano/perdido contra el fondo.
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: context.shadows.card,
      ),
      child: DropdownButtonFormField<String>(
        initialValue: vehiculoSeleccionado?.id,
        decoration: InputDecoration(
          labelText: '¿Qué vehículo vas a usar?',
          filled: true,
          fillColor: colors.surface,
          prefixIcon: Icon(
            Icons.local_shipping_outlined,
            color: colors.textMuted,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadii.cardRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadii.cardRadius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.cardRadius,
            borderSide: BorderSide(
              color: colors.primary,
              width: AppBorders.focus,
            ),
          ),
        ),
        isExpanded: true,
        items: [
          ...vehiculos.map(
            (v) => DropdownMenuItem(
              value: v.id,
              child: Text(
                '${v.tipoUnidad} · ${v.identificador}'
                '${v.esNuevaSinFormalizar ? ' (sin tope asignado)' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          DropdownMenuItem(
            value: _valorVehiculoNuevo,
            child: Text(
              '🆕 Vehículo nuevo, no está en la lista',
              style: TextStyle(color: colors.primary),
            ),
          ),
        ],
        validator: (v) =>
            v == null ? 'Elige el vehículo que vas a usar.' : null,
        onChanged: (valor) => _manejarSeleccion(context, ref, valor),
      ),
    );
  }
}
