import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../data/api_client.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/selector_vehiculo.dart';
import '../../widgets/stepper_numerico.dart';

class SolicitarCargaScreen extends ConsumerStatefulWidget {
  const SolicitarCargaScreen({super.key});

  @override
  ConsumerState<SolicitarCargaScreen> createState() =>
      _SolicitarCargaScreenState();
}

class _SolicitarCargaScreenState extends ConsumerState<SolicitarCargaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motivoController = TextEditingController();

  Vehiculo? _vehiculo;
  double _litros = 0;
  bool _esUrgente = false;
  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vehiculo == null) {
      setState(() => _errorGeneral = 'Elige qué vehículo vas a usar.');
      return;
    }
    if (_litros <= 0) {
      setState(() => _errorGeneral = 'Ingresa los litros que necesitas.');
      return;
    }
    if (_esUrgente && _motivoController.text.trim().isEmpty) {
      setState(
        () =>
            _errorGeneral = 'Al pedir combustible urgente, cuéntanos por qué.',
      );
      return;
    }

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      final perfil = ref.read(sessionProvider)!;
      final solicitud = await ref
          .read(operacionesRepositoryProvider)
          .enviarSolicitud(
            choferId: perfil.id,
            vehiculo: _vehiculo!,
            litrosSolicitados: _litros,
            esUrgente: _esUrgente,
            motivoChofer: _motivoController.text.trim().isEmpty
                ? null
                : _motivoController.text.trim(),
          );
      ref.read(operacionesTickProvider.notifier).state++;
      if (mounted) {
        context.replace(RoutePaths.choferRespuesta, extra: solicitud);
      }
    } on ApiException catch (e) {
      setState(() => _errorGeneral = e.mensaje);
    } catch (e) {
      setState(
        () =>
            _errorGeneral = 'No pudimos enviar tu solicitud. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar carga'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectorVehiculo(
                      vehiculoSeleccionado: _vehiculo,
                      onSeleccionar: (v) => setState(() => _vehiculo = v),
                    ),
                    if (_vehiculo != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: AppRadii.cardRadius,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_gas_station_outlined,
                              color: colors.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _vehiculo!.tipoCombustible,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      '¿Cuántos litros necesitas?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    StepperNumerico(
                      etiqueta: 'Litros solicitados',
                      valor: _litros,
                      sufijo: 'L',
                      paso: 1,
                      decimales: 1,
                      onChanged: (v) => setState(() => _litros = v),
                    ),
                    const SizedBox(height: 16),
                    GroupedSection(
                      children: [
                        GroupedRow(
                          titulo: 'Es urgente (lo necesito hoy)',
                          subtitulo: 'Si no, se planea para mañana',
                          trailing: CupertinoSwitch(
                            value: _esUrgente,
                            activeTrackColor: colors.primary,
                            onChanged: (v) => setState(() => _esUrgente = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _motivoController,
                      decoration: InputDecoration(
                        labelText: _esUrgente
                            ? '¿Por qué? (obligatorio)'
                            : '¿Por qué? (opcional)',
                        hintText: 'Ej. voy hasta el frente de obra…',
                      ),
                      maxLines: 2,
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _cargando ? null : _enviar,
                      child: _cargando
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enviar solicitud'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
