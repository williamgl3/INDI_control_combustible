import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/providers.dart';
import '../../core/unidad_form_data.dart';
import '../../data/api_client.dart';
import '../../data/vehiculos_repository.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_dialog.dart';

class EditarVehiculoDialog extends ConsumerStatefulWidget {
  const EditarVehiculoDialog({super.key, this.vehiculo});

  final Vehiculo? vehiculo;

  static Future<bool?> show(BuildContext context, {Vehiculo? vehiculo}) {
    return mostrarDialogoApp<bool>(
      context,
      barrierDismissible: false,
      builder: (_) => EditarVehiculoDialog(vehiculo: vehiculo),
    );
  }

  @override
  ConsumerState<EditarVehiculoDialog> createState() =>
      _EditarVehiculoDialogState();
}

class _EditarVehiculoDialogState extends ConsumerState<EditarVehiculoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _modeloController = TextEditingController(
    text: widget.vehiculo?.modelo ?? '',
  );
  late final _placasController = TextEditingController(
    text: widget.vehiculo?.placas ?? '',
  );
  late final _economicoController = TextEditingController(
    text: widget.vehiculo?.numeroEconomico ?? '',
  );
  late final _ubicacionController = TextEditingController(
    text: widget.vehiculo?.ubicacion ?? '',
  );
  late final _intervaloController = TextEditingController(
    text: widget.vehiculo == null
        ? ''
        : widget.vehiculo!.intervaloServicio?.toStringAsFixed(0) ?? '',
  );

  late String _tipoUnidad = widget.vehiculo?.tipoUnidad ?? tipoUnidadVehiculo;
  late String? _tipoCombustible = widget.vehiculo?.tipoCombustible;
  late bool _activo = widget.vehiculo?.activo ?? true;
  bool _cargando = false;
  String? _errorIdentificadores;
  String? _errorGeneral;

  bool get _esAlta => widget.vehiculo == null;

  @override
  void dispose() {
    _modeloController.dispose();
    _placasController.dispose();
    _economicoController.dispose();
    _ubicacionController.dispose();
    _intervaloController.dispose();
    super.dispose();
  }

  UnidadFormData? _datosValidos() {
    final formularioValido = _formKey.currentState?.validate() ?? false;
    final errorIdentificadores = UnidadFormValidators.identificadores(
      _placasController.text,
      _economicoController.text,
    );
    setState(() => _errorIdentificadores = errorIdentificadores);
    if (!formularioValido || errorIdentificadores != null) return null;

    return UnidadFormData(
      tipoUnidad: _tipoUnidad,
      modelo: _modeloController.text.trim(),
      placas: UnidadFormData.textoOpcional(
        _placasController.text,
        mayusculas: true,
      ),
      numeroEconomico: UnidadFormData.textoOpcional(
        _economicoController.text,
        mayusculas: true,
      ),
      tipoCombustible: _tipoCombustible!,
      intervaloServicio: _intervaloController.text.trim().isEmpty
          ? null
          : double.parse(_intervaloController.text.trim()),
      ubicacion: UnidadFormData.textoOpcional(_ubicacionController.text),
      activo: _activo,
      unidadPadreId: widget.vehiculo?.unidadPadreId,
    );
  }

  Future<void> _guardar() async {
    if (_cargando) return;
    final datos = _datosValidos();
    if (datos == null) return;
    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      final repo = ref.read(vehiculosRepositoryProvider);
      if (_esAlta) {
        await repo.crear(
          tipoUnidad: datos.tipoUnidad,
          modelo: datos.modelo,
          placas: datos.placas,
          numeroEconomico: datos.numeroEconomico,
          tipoCombustible: datos.tipoCombustible,
          intervaloServicio: datos.intervaloServicio,
          ubicacion: datos.ubicacion,
          unidadPadreId: datos.unidadPadreId,
          activo: datos.activo,
        );
      } else {
        await repo.actualizar(
          id: widget.vehiculo!.id,
          cambios: ActualizacionVehiculo(
            tipoUnidad: CampoActualizacion.valor(datos.tipoUnidad),
            modelo: CampoActualizacion.valor(datos.modelo),
            placas: CampoActualizacion.valor(datos.placas),
            numeroEconomico: CampoActualizacion.valor(datos.numeroEconomico),
            tipoCombustible: CampoActualizacion.valor(datos.tipoCombustible),
            intervaloServicio: CampoActualizacion.valor(
              datos.intervaloServicio,
            ),
            ubicacion: CampoActualizacion.valor(datos.ubicacion),
            unidadPadreId: CampoActualizacion.valor(datos.unidadPadreId),
            activo: CampoActualizacion.valor(datos.activo),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorGeneral = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _errorGeneral = 'No pudimos guardar la unidad.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tituloCategoria = _esAlta
        ? 'Agregar ${_tipoUnidad.toLowerCase()}'
        : 'Editar unidad';

    return AppDialogShell(
      maxWidth: 560,
      footer: _AccionesDialogo(
        cargando: _cargando,
        esAlta: _esAlta,
        onCancelar: () => Navigator.of(context).pop(false),
        onGuardar: _guardar,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _esAlta ? 'Agregar unidad' : 'Editar unidad',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tituloCategoria,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _TituloSeccion(titulo: 'Identificación'),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _tipoUnidad,
              decoration: const InputDecoration(
                labelText: 'Tipo de unidad',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: tiposUnidadAdministrables
                  .map(
                    (tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)),
                  )
                  .toList(),
              onChanged: _cargando
                  ? null
                  : (tipo) => setState(() => _tipoUnidad = tipo!),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _modeloController,
              decoration: const InputDecoration(
                labelText: 'Modelo o nombre',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
              validator: UnidadFormValidators.modelo,
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final placas = _campoIdentificador(
                  controller: _placasController,
                  label: 'Placas',
                  icon: Icons.badge_outlined,
                );
                final economico = _campoIdentificador(
                  controller: _economicoController,
                  label: 'Número económico',
                  icon: Icons.numbers_outlined,
                );
                if (constraints.maxWidth < 480) {
                  return Column(
                    children: [
                      placas,
                      const SizedBox(height: AppSpacing.md),
                      economico,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: placas),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: economico),
                  ],
                );
              },
            ),
            if (_errorIdentificadores != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _errorIdentificadores!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _TituloSeccion(titulo: 'Operación'),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _tipoCombustible,
              decoration: const InputDecoration(
                labelText: 'Tipo de combustible',
                prefixIcon: Icon(Icons.local_gas_station_outlined),
              ),
              items: tiposCombustibleVehiculo
                  .map<DropdownMenuItem<String?>>(
                    (tipo) => DropdownMenuItem<String?>(
                      value: tipo,
                      child: Text(tipo),
                    ),
                  )
                  .toList(),
              validator: (valor) =>
                  valor == null ? 'Selecciona el tipo de combustible' : null,
              onChanged: _cargando
                  ? null
                  : (tipo) => setState(() => _tipoCombustible = tipo),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _ubicacionController,
              decoration: const InputDecoration(
                labelText: 'Ubicación o frente (opcional)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unidad activa'),
                value: _activo,
                onChanged: _cargando
                    ? null
                    : (activo) => setState(() => _activo = activo),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _TituloSeccion(titulo: 'Mantenimiento'),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _intervaloController,
              decoration: InputDecoration(
                labelText: 'Intervalo de servicio (opcional)',
                prefixIcon: const Icon(Icons.build_outlined),
                suffixText: esUnidadPorHorometro(_tipoUnidad) ? 'horas' : 'km',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: UnidadFormValidators.intervalo,
            ),
            if (_errorGeneral != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorGeneral!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _campoIdentificador({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      onChanged: (_) {
        if (_errorIdentificadores != null &&
            UnidadFormValidators.identificadores(
                  _placasController.text,
                  _economicoController.text,
                ) ==
                null) {
          setState(() => _errorIdentificadores = null);
        }
      },
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) => Text(
    titulo,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );
}

class _AccionesDialogo extends StatelessWidget {
  const _AccionesDialogo({
    required this.cargando,
    required this.esAlta,
    required this.onCancelar,
    required this.onGuardar,
  });

  final bool cargando;
  final bool esAlta;
  final VoidCallback onCancelar;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: cargando ? null : onCancelar,
          child: const Text('Cancelar'),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: cargando ? null : onGuardar,
            child: cargando
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(esAlta ? 'Agregar' : 'Guardar vehículo'),
          ),
        ),
      ),
    ],
  );
}
