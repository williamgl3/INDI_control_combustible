import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/cola_solicitudes_offline.dart';
import '../../core/connectivity_provider.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../data/api_client.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_mantenimiento_badge.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/selector_vehiculo.dart';
import '../../widgets/stepper_numerico.dart';
import '../administrativo/tabs/mantenimiento_calculo.dart';
import 'reportar_incidencia_dialog.dart';

class SolicitarCargaScreen extends ConsumerStatefulWidget {
  const SolicitarCargaScreen({super.key});

  @override
  ConsumerState<SolicitarCargaScreen> createState() =>
      _SolicitarCargaScreenState();
}

class _SolicitarCargaScreenState extends ConsumerState<SolicitarCargaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motivoController = TextEditingController();
  final _actividadController = TextEditingController();

  Vehiculo? _vehiculo;
  double _litros = 0;
  bool _esUrgente = false;
  bool _cargando = false;
  String? _errorGeneral;
  DiagnosticoMantenimiento? _diagnosticoMantenimiento;

  /// Fecha en que se necesita el combustible — independiente del switch
  /// "es urgente" (que sigue rigiendo la auto-aprobación). Solo fecha, sin
  /// hora: el momento exacto de la solicitud ya queda registrado
  /// automáticamente al enviarla (`creadaEn`, puesto por el dispositivo/
  /// servidor, no editable) — pedir también una hora aquí sería
  /// redundante. Arranca mañana como default razonable.
  late DateTime _fechaProgramada = () {
    final siguienteDia = DateTime.now().add(const Duration(days: 1));
    return DateTime(siguienteDia.year, siguienteDia.month, siguienteDia.day);
  }();

  @override
  void dispose() {
    _motivoController.dispose();
    _actividadController.dispose();
    super.dispose();
  }

  Future<void> _elegirVehiculo(Vehiculo vehiculo) async {
    setState(() {
      _vehiculo = vehiculo;
      _diagnosticoMantenimiento = null;
    });
    final repo = ref.read(operacionesRepositoryProvider);
    try {
      await repo.cargarHistorialLecturas(vehiculo.id);
    } catch (_) {
      // Sin historial no hay diagnóstico posible — no bloquea el flujo
      // de solicitar carga, solo no se muestra el aviso.
      return;
    }
    if (!mounted || _vehiculo?.id != vehiculo.id) return;
    setState(() {
      _diagnosticoMantenimiento = calcularMantenimiento(
        vehiculo: vehiculo,
        historial: repo.historialLecturas(vehiculo.id),
        ahora: DateTime.now(),
      );
    });
  }

  Future<void> _reportarIncidencia() async {
    final vehiculo = _vehiculo;
    if (vehiculo == null) return;
    final reportada = await ReportarIncidenciaDialog.show(
      context,
      vehiculo: vehiculo,
    );
    if (reportada == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incidencia reportada.')),
      );
    }
  }

  Future<void> _elegirFechaProgramada() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaProgramada,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Fecha en que se necesita el combustible',
      // Igual que en fecha de nacimiento: arranca en modo "escribir la
      // fecha" — el calendario queda como opción secundaria (ícono para
      // cambiar dentro del diálogo).
      initialEntryMode: DatePickerEntryMode.input,
      errorFormatText: 'Formato inválido',
      errorInvalidText: 'Fuera del rango permitido',
      fieldLabelText: 'Fecha en que se necesita',
      fieldHintText: 'dd/mm/aaaa',
    );
    if (fecha == null) return;
    setState(() {
      _fechaProgramada = DateTime(fecha.year, fecha.month, fecha.day);
    });
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
    if (_actividadController.text.trim().isEmpty) {
      setState(
        () => _errorGeneral =
            'Describe la actividad para la que necesitas el combustible.',
      );
      return;
    }

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    final motivo = _motivoController.text.trim().isEmpty
        ? null
        : _motivoController.text.trim();
    final actividad = _actividadController.text.trim();

    // Sin conexión detectada de entrada: ni se intenta la petición, se
    // encola directo — evita esperar el timeout de red para llegar al
    // mismo resultado.
    if (ref.read(conectividadProvider).valueOrNull == false) {
      await _encolarSinConexion(motivo: motivo, actividad: actividad);
      return;
    }

    try {
      final perfil = ref.read(sessionProvider)!;
      final solicitud = await ref
          .read(operacionesRepositoryProvider)
          .enviarSolicitud(
            choferId: perfil.id,
            vehiculo: _vehiculo!,
            litrosSolicitados: _litros,
            esUrgente: _esUrgente,
            motivoChofer: motivo,
            actividad: actividad,
            fechaProgramada: _fechaProgramada,
          );
      ref.read(operacionesTickProvider.notifier).state++;
      if (mounted) {
        context.replace(RoutePaths.choferRespuesta, extra: solicitud);
      }
    } on ApiException catch (e) {
      if (e.status == null) {
        // Sin `status` HTTP = nunca llegó a un servidor (falla de red) —
        // el chequeo de conectividad de arriba pudo dar un falso
        // positivo (hay wifi/datos pero sin salida real a internet).
        await _encolarSinConexion(motivo: motivo, actividad: actividad);
        return;
      }
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

  Future<void> _encolarSinConexion({
    required String? motivo,
    required String actividad,
  }) async {
    final ahora = DateTime.now();
    await ref
        .read(colaSolicitudesOfflineProvider)
        .agregar(
          SolicitudPendienteOffline(
            idLocal: 'offline-${ahora.microsecondsSinceEpoch}',
            vehiculoId: _vehiculo!.id,
            litrosSolicitados: _litros,
            esUrgente: _esUrgente,
            motivoChofer: motivo,
            actividad: actividad,
            fechaProgramada: _fechaProgramada,
            creadaEn: ahora,
          ),
        );
    ref.read(operacionesTickProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _cargando = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_off_outlined),
        title: const Text('Sin conexión'),
        content: const Text(
          'Guardamos tu solicitud en este dispositivo. Se enviará sola en '
          'cuanto vuelvas a tener señal — no hace falta que la repitas.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (mounted) context.pop();
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
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.contentMaxWidth,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectorVehiculo(
                      vehiculoSeleccionado: _vehiculo,
                      onSeleccionar: _elegirVehiculo,
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
                      if (_diagnosticoMantenimiento != null &&
                          _diagnosticoMantenimiento!.estado !=
                              EstadoMantenimiento.alDia &&
                          _diagnosticoMantenimiento!.estado !=
                              EstadoMantenimiento.sinDatos) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (_diagnosticoMantenimiento!.estado ==
                                        EstadoMantenimiento.vencido
                                    ? colors.error
                                    : colors.warning)
                                    .withValues(alpha: 0.1),
                            borderRadius: AppRadii.cardRadius,
                          ),
                          child: Row(
                            children: [
                              EstadoMantenimientoBadge(
                                estado: _diagnosticoMantenimiento!.estado,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _diagnosticoMantenimiento!.estado ==
                                          EstadoMantenimiento.vencido
                                      ? 'Este vehículo tiene el mantenimiento vencido.'
                                      : 'Este vehículo está por vencer su mantenimiento.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              TextButton(
                                onPressed: _reportarIncidencia,
                                child: const Text('Reportar'),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _reportarIncidencia,
                            icon: const Icon(Icons.report_gmailerrorred_outlined, size: 16),
                            label: const Text('¿Problema con esta unidad? Repórtalo'),
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
                        Semantics(
                          button: true,
                          label:
                              'Elegir fecha en que se necesita el '
                              'combustible',
                          child: GroupedRow(
                            titulo: 'Fecha en que se necesita',
                            subtitulo:
                                '${_fechaProgramada.day.toString().padLeft(2, '0')}/'
                                '${_fechaProgramada.month.toString().padLeft(2, '0')}/'
                                '${_fechaProgramada.year}',
                            icono: Icons.event_outlined,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _elegirFechaProgramada,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _motivoController,
                      decoration: InputDecoration(
                        labelText: _esUrgente
                            ? 'Motivo (obligatorio)'
                            : 'Motivo (opcional)',
                        hintText: 'Ej. se acabó antes de tiempo',
                        // Sin límite de líneas fijo: cada quien decide si
                        // basta una frase corta o prefiere explicarlo con
                        // detalle — el campo crece solo con el texto.
                      ),
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _actividadController,
                      decoration: const InputDecoration(
                        labelText: 'Actividad',
                        hintText:
                            'Ej. Tramo 340+000 al 349+420, Realizar Trazos y '
                            'Niveles traslado al área de trabajo…',
                      ),
                      maxLines: 3,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Describe la actividad para la que necesitas el '
                                'combustible.'
                          : null,
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
