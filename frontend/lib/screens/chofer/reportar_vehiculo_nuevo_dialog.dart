import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/providers.dart';
import '../../core/validators.dart';
import '../../data/api_client.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';

/// El chofer reporta sobre la marcha una unidad que no está en el
/// catálogo (ej. una unidad recién llegada a la obra). Queda sin tope
/// asignado hasta que un administrativo la formalice — ver
/// `MockVehiculosRepository.reportarNuevo`.
///
/// El campo de identificación pedido cambia según el tipo de unidad —
/// mismo criterio que `EditarVehiculoDialog` (panel admin): Vehículo
/// pide placas, Maquinaria pide económico, Marimba pide ambos.
class ReportarVehiculoNuevoDialog extends ConsumerStatefulWidget {
  const ReportarVehiculoNuevoDialog({super.key, this.tipoUnidadInicial});

  /// Preselecciona el tipo de unidad (ej. cuando se abre desde un
  /// [SelectorVehiculo] ya filtrado por categoría) — el chofer puede
  /// cambiarlo igual, solo evita que tenga que volver a elegirlo.
  final String? tipoUnidadInicial;

  static Future<Vehiculo?> show(
    BuildContext context, {
    String? tipoUnidadInicial,
  }) {
    return mostrarDialogoApp<Vehiculo>(
      context,
      builder: (_) =>
          ReportarVehiculoNuevoDialog(tipoUnidadInicial: tipoUnidadInicial),
    );
  }

  @override
  ConsumerState<ReportarVehiculoNuevoDialog> createState() =>
      _ReportarVehiculoNuevoDialogState();
}

class _ReportarVehiculoNuevoDialogState
    extends ConsumerState<ReportarVehiculoNuevoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _modeloController = TextEditingController();
  final _placasController = TextEditingController();
  final _economicoController = TextEditingController();

  late String _tipoUnidad =
      widget.tipoUnidadInicial ?? tiposUnidadVehiculo.first;
  String _tipoCombustible = tiposCombustibleVehiculo.first;
  bool _cargando = false;
  String? _errorGeneral;

  bool get _mostrarPlacas => _tipoUnidad != 'Maquinaria';
  bool get _mostrarEconomico => _tipoUnidad != 'Vehículo';

  @override
  void dispose() {
    _modeloController.dispose();
    _placasController.dispose();
    _economicoController.dispose();
    super.dispose();
  }

  void _cambiarTipoUnidad(String tipo) {
    setState(() {
      _tipoUnidad = tipo;
      if (!_mostrarPlacas) _placasController.clear();
      if (!_mostrarEconomico) _economicoController.clear();
    });
  }

  Future<void> _reportar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });
    try {
      final vehiculo = await ref
          .read(vehiculosRepositoryProvider)
          .reportarNuevo(
            tipoUnidad: _tipoUnidad,
            placas: _mostrarPlacas ? _placasController.text.trim() : '',
            numeroEconomico: _mostrarEconomico
                ? _economicoController.text.trim()
                : '',
            tipoCombustible: _tipoCombustible,
            modelo: _modeloController.text.trim(),
          );
      ref.read(operacionesTickProvider.notifier).state++;
      ref.read(catalogoUnidadesProvider.notifier).publicarCambiosLocales();
      if (mounted) Navigator.of(context).pop(vehiculo);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialogShell(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vehículo nuevo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Repórtalo y ya puedes seguir — un administrativo le asignará su '
              'tope semanal después.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _tipoUnidad,
              decoration: const InputDecoration(
                labelText: 'Tipo de unidad',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
              items: tiposUnidadVehiculo
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => _cambiarTipoUnidad(v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modeloController,
              decoration: const InputDecoration(
                labelText: 'Vehículo',
                hintText: 'Ej. NISSAN FRONTIER, TOYOTA HILUX',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  Validators.requerido(v, etiqueta: 'El vehículo'),
            ),
            // Igual que en `EditarVehiculoDialog`: el campo que no
            // aplica se quita del árbol por completo, no solo se
            // oculta — así su validator nunca corre ni bloquea el envío
            // en silencio.
            if (_mostrarPlacas) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _placasController,
                decoration: const InputDecoration(
                  labelText: 'Placas',
                  hintText: 'Ej. PJ-6567-C',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: Validators.placa,
              ),
            ],
            if (_mostrarEconomico) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _economicoController,
                decoration: const InputDecoration(
                  labelText: 'Número económico',
                  hintText: 'Ej. EHO-330-056',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    Validators.requerido(v, etiqueta: 'El número económico'),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _tipoCombustible,
              decoration: const InputDecoration(
                labelText: 'Tipo de combustible',
                prefixIcon: Icon(Icons.local_gas_station_outlined),
              ),
              items: tiposCombustibleVehiculo
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipoCombustible = v!),
            ),
            if (_errorGeneral != null) ...[
              const SizedBox(height: 12),
              AvisoError(mensaje: _errorGeneral!),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppElevatedButton(
                    onPressed: _reportar,
                    cargando: _cargando,
                    child: const Text('Reportar y usar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
