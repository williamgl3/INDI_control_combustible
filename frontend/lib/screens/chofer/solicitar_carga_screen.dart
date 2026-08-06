import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cola_solicitudes_offline.dart';
import '../../core/connectivity_provider.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../data/api_client.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/brand_sub_header.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/estado_mantenimiento_badge.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/selector_vehiculo.dart';
import '../../widgets/sin_conexion_dialog.dart';
import '../administrativo/tabs/mantenimiento_calculo.dart';
import 'reportar_incidencia_dialog.dart';

class SolicitarCargaScreen extends ConsumerStatefulWidget {
  const SolicitarCargaScreen({super.key, this.categoriaFiltro});

  /// Categoría elegida en `TipoOperacionScreen` (ej. "Maquinaria") — filtra
  /// el catálogo de `SelectorVehiculo` a esa categoría. `null` muestra el
  /// catálogo completo (llegando a esta pantalla por una ruta que no pasó
  /// por la selección de tipo de operación).
  final String? categoriaFiltro;

  @override
  ConsumerState<SolicitarCargaScreen> createState() =>
      _SolicitarCargaScreenState();
}

class _SolicitarCargaScreenState extends ConsumerState<SolicitarCargaScreen> {
  static const _kUltimaCantidadKey = 'ultima_cantidad_litros_solicitados';

  final _formKey = GlobalKey<FormState>();
  final _motivoController = TextEditingController();
  final _actividadController = TextEditingController();
  final _motivoFocus = FocusNode();

  Vehiculo? _vehiculo;
  double _litros = 0;
  double? _ultimaCantidad;
  bool _esUrgente = false;
  bool _cargando = false;
  String? _errorGeneral;
  DiagnosticoMantenimiento? _diagnosticoMantenimiento;

  // TODO-SPEC: no existe todavía un catálogo real de supervisores — lista
  // placeholder hasta que haya una decisión de negocio/backend al respecto.
  static const _supervisoresPlaceholder = [
    'Ing. Ponce',
    'Ing. Ramírez',
    'Ing. Torres',
  ];
  final _serviciosAdicionales = <String>{};
  String? _supervisor;

  String? _fotoTableroPath;
  bool _cargandoFotoTablero = false;

  late DateTime _fechaProgramada = () {
    final siguienteDia = DateTime.now().add(const Duration(days: 1));
    return DateTime(siguienteDia.year, siguienteDia.month, siguienteDia.day);
  }();

  @override
  void initState() {
    super.initState();
    _cargarUltimaCantidad();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _actividadController.dispose();
    _motivoFocus.dispose();
    super.dispose();
  }

  Future<void> _cargarUltimaCantidad() async {
    final prefs = await SharedPreferences.getInstance();
    final guardada = prefs.getDouble(_kUltimaCantidadKey);
    if (mounted && guardada != null && guardada > 0) {
      setState(() => _ultimaCantidad = guardada);
    }
  }

  Future<void> _guardarUltimaCantidad() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kUltimaCantidadKey, _litros);
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

  Future<void> _tomarFotoTablero() async {
    setState(() => _cargandoFotoTablero = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) _fotoTableroPath = ruta;
        _cargandoFotoTablero = false;
      });
    }
  }

  Future<void> _reportarIncidencia() async {
    final vehiculo = _vehiculo;
    if (vehiculo == null) return;
    final reportada = await ReportarIncidenciaDialog.show(
      context,
      vehiculo: vehiculo,
    );
    if (reportada == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incidencia reportada.')));
    }
  }

  /// Agrega el supervisor/servicios adicionales elegidos (solo relevantes
  /// para maquinaria) al motivo, ya que no existe todavía un campo propio
  /// en el contrato del backend para esto — ver nota en la clase.
  String? _motivoConDetalleMaquinaria(String? motivoBase) {
    if (_vehiculo?.tipoUnidad != 'Maquinaria') return motivoBase;
    final detalles = <String>[
      if (_supervisor != null) 'Supervisor: $_supervisor',
      if (_serviciosAdicionales.isNotEmpty)
        'Servicios adicionales: ${_serviciosAdicionales.join(', ')}',
    ];
    if (detalles.isEmpty) return motivoBase;
    final detalleTexto = detalles.join(' · ');
    return motivoBase == null ? detalleTexto : '$motivoBase\n$detalleTexto';
  }

  Future<void> _elegirFechaProgramada() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaProgramada,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Fecha en que se necesita el combustible',
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
    if (_fotoTableroPath == null) {
      setState(
        () => _errorGeneral =
            'Toma una foto del tablero (km/horómetro actual) antes de enviar.',
      );
      return;
    }

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    final motivo = _motivoConDetalleMaquinaria(
      _motivoController.text.trim().isEmpty
          ? null
          : _motivoController.text.trim(),
    );
    final actividad = _actividadController.text.trim();

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
            fotoTableroPath: _fotoTableroPath,
          );
      HapticFeedback.mediumImpact();
      ref.read(operacionesTickProvider.notifier).state++;
      unawaited(_guardarUltimaCantidad());
      if (mounted) {
        context.replace(RoutePaths.choferRespuesta, extra: solicitud);
      }
    } on ApiException catch (e) {
      if (e.status == null) {
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
            fotoTableroPath: _fotoTableroPath!,
            creadaEn: ahora,
          ),
        );
    ref.read(operacionesTickProvider.notifier).state++;
    unawaited(_guardarUltimaCantidad());
    if (!mounted) return;
    setState(() => _cargando = false);
    await SinConexionDialog.show(
      context,
      mensaje:
          'Guardamos tu solicitud en este dispositivo. Se enviará sola en '
          'cuanto vuelvas a tener señal — no hace falta que la repitas.',
    );
    // `go` en vez de `pop`: ahora esta pantalla se alcanza vía
    // TipoOperacionScreen (push), así que un solo `pop` regresaría ahí en
    // vez de a Inicio. `ChoferHomeScreen` lee el estado de la cola
    // directo del provider al reconstruirse, no depende de este pop.
    if (mounted) context.go(RoutePaths.chofer);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          BrandSubHeader(
            titulo: 'Solicitar carga',
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ContenidoResponsivo(
                physics: const BouncingScrollPhysics(),
                paddingSuperior: AppSpacing.lg,
                paddingInferior: AppSpacing.xxl,
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectorVehiculo(
                        vehiculoSeleccionado: _vehiculo,
                        onSeleccionar: _elegirVehiculo,
                        filtroTipoUnidad: widget.categoriaFiltro,
                      ),
                      if (_vehiculo != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        GroupedSection(
                          children: [
                            GroupedRow(
                              titulo:
                                  _vehiculo!.tipoCombustible ??
                                  'Sin especificar',
                              subtitulo: 'Tipo de combustible',
                              icono: Icons.local_gas_station_outlined,
                            ),
                            if (_diagnosticoMantenimiento != null &&
                                _diagnosticoMantenimiento!.estado !=
                                    EstadoMantenimiento.alDia &&
                                _diagnosticoMantenimiento!.estado !=
                                    EstadoMantenimiento.sinDatos)
                              GroupedRow(
                                titulo:
                                    _diagnosticoMantenimiento!.estado ==
                                        EstadoMantenimiento.vencido
                                    ? 'Mantenimiento vencido'
                                    : 'Mantenimiento por vencer',
                                subtitulo: 'Toca para reportar un problema',
                                icono: Icons.build_outlined,
                                iconoColor:
                                    _diagnosticoMantenimiento!.estado ==
                                        EstadoMantenimiento.vencido
                                    ? colors.error
                                    : colors.warning,
                                trailing: EstadoMantenimientoBadge(
                                  estado: _diagnosticoMantenimiento!.estado,
                                ),
                                onTap: _reportarIncidencia,
                              )
                            else
                              GroupedRow(
                                titulo: '¿Problema con esta unidad?',
                                subtitulo: 'Repórtalo aquí',
                                icono: Icons.build_outlined,
                                onTap: _reportarIncidencia,
                              ),
                          ],
                        ),
                      ],
                      if (_vehiculo?.tipoUnidad == 'Maquinaria') ...[
                        const SizedBox(height: AppSpacing.md),
                        GroupedSection(
                          header: 'Maquinaria',
                          children: [
                            GroupedRow(
                              titulo: 'Grasa',
                              subtitulo: 'Servicio de engrasado en esta salida',
                              icono: Icons.opacity_outlined,
                              trailing: CupertinoSwitch(
                                value: _serviciosAdicionales.contains('Grasa'),
                                activeTrackColor: colors.primary,
                                inactiveTrackColor: colors.border,
                                onChanged: (v) => setState(() {
                                  if (v) {
                                    _serviciosAdicionales.add('Grasa');
                                  } else {
                                    _serviciosAdicionales.remove('Grasa');
                                  }
                                }),
                              ),
                            ),
                            GroupedRow(
                              titulo: 'Aceite',
                              subtitulo: 'Cambio o relleno de aceite en esta salida',
                              icono: Icons.water_drop_outlined,
                              trailing: CupertinoSwitch(
                                value: _serviciosAdicionales.contains('Aceite'),
                                activeTrackColor: colors.primary,
                                inactiveTrackColor: colors.border,
                                onChanged: (v) => setState(() {
                                  if (v) {
                                    _serviciosAdicionales.add('Aceite');
                                  } else {
                                    _serviciosAdicionales.remove('Aceite');
                                  }
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        DropdownButtonFormField<String>(
                          initialValue: _supervisor,
                          decoration: const InputDecoration(
                            labelText: 'Supervisor (opcional)',
                            prefixIcon: Icon(Icons.engineering_outlined),
                          ),
                          items: _supervisoresPlaceholder
                              .map(
                                (s) => DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _supervisor = v),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      _FotoTableroCard(
                        rutaFoto: _fotoTableroPath,
                        cargando: _cargandoFotoTablero,
                        onTap: _tomarFotoTablero,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        '¿Cuántos litros necesitas?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SelectorLitros(
                        valor: _litros,
                        onChanged: (v) => setState(() => _litros = v),
                        ultimaCantidad: _ultimaCantidad,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      GroupedSection(
                        children: [
                          GroupedRow(
                            titulo: 'Es urgente (lo necesito hoy)',
                            subtitulo: 'Si no, se planea para mañana',
                            trailing: CupertinoSwitch(
                              value: _esUrgente,
                              activeTrackColor: colors.primary,
                              inactiveTrackColor: colors.border,
                              onChanged: (v) {
                                setState(() => _esUrgente = v);
                                if (v) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) _motivoFocus.requestFocus();
                                  });
                                }
                              },
                            ),
                          ),
                          Semantics(
                            button: true,
                            label:
                                'Elegir fecha en que se necesita el '
                                'combustible',
                            child: GroupedRow(
                              titulo: 'Fecha en que se necesita',
                              subtitulo: formatearFecha(_fechaProgramada),
                              icono: Icons.event_outlined,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _elegirFechaProgramada,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _motivoController,
                        focusNode: _motivoFocus,
                        decoration: InputDecoration(
                          labelText: _esUrgente
                              ? 'Motivo (obligatorio)'
                              : 'Motivo (opcional)',
                          hintText: 'Ej. se acabó antes de tiempo',
                        ),
                        minLines: 1,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _actividadController,
                        decoration: const InputDecoration(
                          labelText: 'Actividad',
                          hintText:
                              'Ej. Tramo 340+000 al 349+420, Realizar Trazos y '
                              'Niveles traslado al área de trabajo…',
                        ),
                        maxLines: 3,
                        minLines: 2,
                        keyboardType: TextInputType.multiline,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Describe la actividad para la que necesitas el '
                                  'combustible.'
                            : null,
                      ),
                      if (_errorGeneral != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AvisoError(mensaje: _errorGeneral!),
                      ],
                      // Padding inferior extra para que el último campo
                      // de texto no quede tapado por el botón fijo.
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BarraEnviar(
        cargando: _cargando,
        onEnviar: _enviar,
      ),
    );
  }
}

/// Tarjeta de captura de foto del tablero — sin foto muestra borde punteado
/// con ícono de cámara grande; con foto muestra thumbnail + indicador verde.
class _FotoTableroCard extends StatelessWidget {
  const _FotoTableroCard({
    required this.rutaFoto,
    required this.cargando,
    required this.onTap,
  });

  final String? rutaFoto;
  final bool cargando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tieneFoto = rutaFoto != null;

    return Semantics(
      button: true,
      label: tieneFoto
          ? 'Cambiar foto del tablero'
          : 'Tomar foto del tablero (obligatorio)',
      child: Material(
        color: tieneFoto
            ? colors.success.withValues(alpha: 0.06)
            : colors.surfaceAlt,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          onTap: cargando ? null : onTap,
          borderRadius: AppRadii.cardRadius,
          child: tieneFoto ? _buildConFoto(context, colors) : _buildSinFoto(context, colors),
        ),
      ),
    );
  }

  Widget _buildSinFoto(BuildContext context, AppColors colors) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: colors.border,
        radius: AppRadii.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: 32,
        ),
        child: Column(
          children: [
            if (cargando)
              const SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: colors.primary,
                  size: 32,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tomar foto del tablero',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: colors.warning),
                const SizedBox(width: 4),
                Text(
                  'Obligatorio',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'km / horómetro actual',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConFoto(BuildContext context, AppColors colors) {
    return AppCard(
      floating: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      border: Border.all(color: colors.success.withValues(alpha: 0.4)),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: AppRadii.inputRadius,
                child: Image.file(
                  File(rutaFoto!),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 64,
                    height: 64,
                    color: colors.success.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.speed_outlined,
                      color: colors.success,
                      size: 28,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: colors.success,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto del tablero capturada',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'km / horómetro actual',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (cargando)
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Cambiar',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Selector de litros interactivo: display grande editable (con animación al
/// cambiar), chips de atajos rápidos (+10, +20, +50) como acción principal,
/// atajo de "repetir última cantidad" y botón de reinicio.
class _SelectorLitros extends StatelessWidget {
  const _SelectorLitros({
    required this.valor,
    required this.onChanged,
    this.ultimaCantidad,
  });

  final double valor;
  final ValueChanged<double> onChanged;
  final double? ultimaCantidad;

  static const _atajos = [
    (10.0, '+10 L'),
    (20.0, '+20 L'),
    (50.0, '+50 L'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ultima = ultimaCantidad;
    final mostrarRepetir = ultima != null && ultima > 0;

    return AppCard(
      floating: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'LITROS SOLICITADOS',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (valor > 0)
                TextButton.icon(
                  onPressed: () => onChanged(0),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reiniciar'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: GestureDetector(
              onTap: () => _editarManualmente(context),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Text(
                      valor.toStringAsFixed(1),
                      key: ValueKey(valor),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1463FF),
                      ),
                    ),
                  ),
                  Text(
                    'L · toca para escribir',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (mostrarRepetir) ...[
            _ChipAtajo(
              label: 'Repetir: ${ultima.toStringAsFixed(0)} L',
              icono: Icons.replay,
              onTap: () => onChanged(ultima),
              destacado: true,
              anchoCompleto: true,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              for (final (cantidad, label) in _atajos) ...[
                if (cantidad != _atajos.first.$1) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ChipAtajo(
                    label: label,
                    onTap: () => onChanged(valor + cantidad),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editarManualmente(BuildContext context) async {
    final controller = TextEditingController(
      text: valor == 0 ? '' : valor.toStringAsFixed(1),
    );
    final nuevoValor = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Litros solicitados'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'L'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parseado = double.tryParse(controller.text.trim());
              Navigator.of(context).pop(parseado);
            },
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    if (nuevoValor != null && nuevoValor >= 0) {
      onChanged(nuevoValor);
    }
  }
}

/// Chip pill para atajos de litros — tamaño ampliado para ser la forma
/// principal de construir la cantidad (ver [_SelectorLitros]).
class _ChipAtajo extends StatelessWidget {
  const _ChipAtajo({
    required this.label,
    required this.onTap,
    this.icono,
    this.destacado = false,
    this.anchoCompleto = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icono;
  final bool destacado;
  final bool anchoCompleto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: anchoCompleto ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        // Variante intencional de `AppShadows.card` (mismo blur/offset),
        // no un olvido: el tinte de color de marca es la señal visual de
        // "chip seleccionado/destacado", se perdería con el token neutro.
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: destacado ? 0.2 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: destacado
            ? colors.primary.withValues(alpha: 0.15)
            : colors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 14,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icono != null) ...[
                  Icon(
                    icono,
                    size: 18,
                    color: destacado ? colors.primary : colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: destacado ? colors.primary : colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior fija con el botón "Enviar solicitud" — vive fuera del
/// scroll para que siempre sea accesible sin importar la posición del
/// formulario. Respeta el safe area inferior (Home Indicator de iOS).
class _BarraEnviar extends StatelessWidget {
  const _BarraEnviar({required this.cargando, required this.onEnviar});

  final bool cargando;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: context.shadows.floating,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AppElevatedButton(
          onPressed: onEnviar,
          cargando: cargando,
          child: const Text('Enviar solicitud'),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const dashWidth = 6.0;
  static const gapWidth = 4.0;
  static const strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metric.length) {
        final siguiente = distancia + dashWidth;
        canvas.drawPath(
          metric.extractPath(distancia, siguiente.clamp(0, metric.length)),
          paint,
        );
        distancia = siguiente + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
