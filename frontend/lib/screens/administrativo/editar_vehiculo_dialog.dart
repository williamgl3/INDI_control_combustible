import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/providers.dart';
import '../../core/validators.dart';
import '../../data/api_client.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// Modal para que un administrativo dé de alta un vehículo en el catálogo
/// compartido, o edite uno existente (placas/económico, tipo,
/// combustible). Si [vehiculo] es `null` se trata de un alta nueva.
///
/// El campo de identificación pedido cambia según [_tipoUnidad] — ver
/// `_mostrarPlacas`/`_mostrarEconomico`: Vehículo pide solo placas,
/// Maquinaria pide solo económico, Marimba pide ambos (circula por
/// carretera y además lleva económico interno de GAMI).
class EditarVehiculoDialog extends ConsumerStatefulWidget {
  const EditarVehiculoDialog({super.key, this.vehiculo});

  final Vehiculo? vehiculo;

  static Future<bool?> show(BuildContext context, {Vehiculo? vehiculo}) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => EditarVehiculoDialog(vehiculo: vehiculo),
    );
  }

  @override
  ConsumerState<EditarVehiculoDialog> createState() =>
      _EditarVehiculoDialogState();
}

class _EditarVehiculoDialogState extends ConsumerState<EditarVehiculoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _placasController = TextEditingController(
    text: widget.vehiculo?.placas ?? '',
  );
  late final _economicoController = TextEditingController(
    text: widget.vehiculo?.numeroEconomico ?? '',
  );
  late final _intervaloController = TextEditingController(
    text:
        (widget.vehiculo?.intervaloServicio ??
                intervaloServicioPorDefecto(
                  widget.vehiculo?.tipoUnidad ?? tiposUnidadVehiculo.first,
                ))
            .toStringAsFixed(0),
  );

  late String _tipoUnidad =
      widget.vehiculo?.tipoUnidad ?? tiposUnidadVehiculo.first;
  // `null` = "Sin especificar" — válido de verdad (migración 0022), no
  // un estado transitorio. En alta nueva arranca en el primer valor real
  // porque la mayoría de las unidades sí tienen combustible conocido;
  // al editar respeta lo que ya haya, aunque sea `null`.
  late String? _tipoCombustible = widget.vehiculo != null
      ? widget.vehiculo!.tipoCombustible
      : tiposCombustibleVehiculo.first;
  bool _cargando = false;
  String? _errorGeneral;

  bool get _esAlta => widget.vehiculo == null;

  /// Vehículo y Marimba circulan por carretera → necesitan placa.
  bool get _mostrarPlacas => _tipoUnidad != 'Maquinaria';

  /// Maquinaria y Marimba se identifican por número económico interno.
  bool get _mostrarEconomico => _tipoUnidad != 'Vehículo';

  @override
  void dispose() {
    _placasController.dispose();
    _economicoController.dispose();
    _intervaloController.dispose();
    super.dispose();
  }

  /// Al cambiar de categoría, limpia el controller del campo que deja de
  /// aplicar — evita arrastrar un valor de la categoría anterior si el
  /// usuario ya había escrito algo antes de cambiar de tipo (ver PASO 4,
  /// trampa clásica de formularios dinámicos en Flutter).
  void _cambiarTipoUnidad(String tipo) {
    setState(() {
      _tipoUnidad = tipo;
      if (!_mostrarPlacas) _placasController.clear();
      if (!_mostrarEconomico) _economicoController.clear();
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      final repo = ref.read(vehiculosRepositoryProvider);
      final intervalo =
          double.tryParse(_intervaloController.text.trim()) ??
          intervaloServicioPorDefecto(_tipoUnidad);
      // Siempre se manda el valor de los dos campos (vacío si el campo
      // no aplica a esta categoría) — el backend normaliza cadena vacía
      // a `null`, así que cambiar de categoría también limpia el dato
      // que ya no corresponde en el registro guardado, no solo en el
      // formulario.
      final placas = _mostrarPlacas ? _placasController.text.trim() : '';
      final economico = _mostrarEconomico
          ? _economicoController.text.trim()
          : '';
      if (_esAlta) {
        await repo.crear(
          tipoUnidad: _tipoUnidad,
          placas: placas,
          numeroEconomico: economico,
          tipoCombustible: _tipoCombustible,
          intervaloServicio: intervalo,
        );
      } else {
        await repo.actualizar(
          id: widget.vehiculo!.id,
          tipoUnidad: _tipoUnidad,
          placas: placas,
          numeroEconomico: economico,
          tipoCombustible: _tipoCombustible,
          intervaloServicio: intervalo,
        );
      }
      ref.read(operacionesTickProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop(true);
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
              _esAlta ? 'Agregar vehículo' : 'Editar vehículo',
              style: Theme.of(context).textTheme.titleLarge,
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
            // Los campos ocultos se quitan del árbol por completo (no
            // solo `visible: false`) — un TextFormField oculto pero
            // presente seguiría corriendo su `validator` y bloquearía el
            // envío sin ningún error visible.
            if (_mostrarPlacas) ...[
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              TextFormField(
                controller: _economicoController,
                decoration: const InputDecoration(
                  labelText: 'Número económico',
                  hintText: 'Ej. EHO-330-056',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => Validators.requerido(
                  v,
                  etiqueta: 'El número económico',
                ),
              ),
            ],
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              initialValue: _tipoCombustible,
              decoration: const InputDecoration(
                labelText: 'Tipo de combustible',
                prefixIcon: Icon(Icons.local_gas_station_outlined),
              ),
              items: [
                ...tiposCombustibleVehiculo.map(
                  (t) => DropdownMenuItem(value: t, child: Text(t)),
                ),
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin especificar'),
                ),
              ],
              onChanged: (v) => setState(() => _tipoCombustible = v),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _intervaloController,
              decoration: InputDecoration(
                labelText: 'Intervalo de servicio general mecánico',
                suffixText: esUnidadPorHorometro(_tipoUnidad) ? 'horas' : 'km',
                prefixIcon: const Icon(Icons.build_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) {
                  return 'Ingresa un número válido mayor a 0.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _guardar(),
            ),
            if (_errorGeneral != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorGeneral!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _guardar,
                    child: _cargando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _esAlta ? 'Agregar vehículo' : 'Guardar vehículo',
                          ),
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
