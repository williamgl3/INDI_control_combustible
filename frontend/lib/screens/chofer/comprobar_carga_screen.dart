import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/cola_solicitudes_offline.dart';
import '../../core/connectivity_provider.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../core/ticket_ocr_service.dart';
import '../../data/api_client.dart';
import '../../data/operaciones_repository.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/chofer_operation_scaffold.dart';
import '../../widgets/confirmar_fotos_dialog.dart';
import '../../widgets/selector_vehiculo.dart';
import '../../widgets/sin_conexion_dialog.dart';
import '../../widgets/stepper_numerico.dart';

/// Registro 1 del día: se llena justo después de cargar combustible,
/// contra un folio ya autorizado. Llega vía `state.extra` (el folio,
/// String) desde /chofer/respuesta o desde la tarjeta de "carga pendiente"
/// en /chofer.
class ComprobarCargaScreen extends ConsumerStatefulWidget {
  const ComprobarCargaScreen({super.key, required this.folioAutorizacion});

  final String folioAutorizacion;

  @override
  ConsumerState<ComprobarCargaScreen> createState() =>
      _ComprobarCargaScreenState();
}

class _ComprobarCargaScreenState extends ConsumerState<ComprobarCargaScreen> {
  final _gasolineraController = TextEditingController();
  final _folioEstacionController = TextEditingController();

  Vehiculo? _vehiculo;
  SolicitudAutorizacion? _solicitud;
  double _litrosCargados = 0;
  double _litrosConsumoPropio = 0;
  double _litrosCargaGranel = 0;
  double _kmAlCargar = 0;
  String? _fotoTicketPath;
  String? _fotoTableroPath;
  ResultadoOcrTicket? _resultadoOcr;

  bool _cargandoFotoTicket = false;
  bool _cargandoFotoTablero = false;
  bool _enviando = false;
  String? _errorGeneral;

  @override
  void initState() {
    super.initState();
    // Precarga el vehículo elegido al solicitar — el chofer puede
    // corregirlo aquí si en el camino le tocó otra unidad.
    final solicitud = ref
        .read(operacionesRepositoryProvider)
        .solicitudPorFolio(widget.folioAutorizacion);
    if (solicitud != null) {
      _solicitud = solicitud;
      _vehiculo = ref
          .read(vehiculosRepositoryProvider)
          .porId(solicitud.vehiculoId);
    }
  }

  @override
  void dispose() {
    _gasolineraController.dispose();
    _folioEstacionController.dispose();
    super.dispose();
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

  Future<void> _tomarFotoTicket() async {
    setState(() => _cargandoFotoTicket = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (ruta == null) {
      if (mounted) setState(() => _cargandoFotoTicket = false);
      return;
    }
    // El OCR es un apoyo visual (ver TicketOcrService) — si falla, se
    // ignora y el chofer puede seguir enviando su comprobación igual.
    ResultadoOcrTicket? resultado;
    try {
      resultado = await ref.read(ticketOcrServiceProvider).leerTicket(ruta);
    } catch (_) {
      resultado = null;
    }
    if (mounted) {
      setState(() {
        _fotoTicketPath = ruta;
        _resultadoOcr = resultado;
        _cargandoFotoTicket = false;
      });
    }
  }

  bool get _usaPartidas => _solicitud?.partidas.isNotEmpty ?? false;
  double get _totalCargado => _usaPartidas
      ? _litrosConsumoPropio + _litrosCargaGranel
      : _litrosCargados;

  List<SolicitudPartida>? get _partidasCarga {
    if (!_usaPartidas) return null;
    return [
      if (_litrosConsumoPropio > 0)
        SolicitudPartida(
          tipo: TipoPartidaSolicitud.consumoPropio,
          litrosSolicitados: _litrosConsumoPropio,
          tipoCombustible: _solicitud!.partidas
              .firstWhere((p) => p.tipo == TipoPartidaSolicitud.consumoPropio)
              .tipoCombustible,
        ),
      if (_litrosCargaGranel > 0)
        SolicitudPartida(
          tipo: TipoPartidaSolicitud.cargaGranel,
          litrosSolicitados: _litrosCargaGranel,
          tipoCombustible: _solicitud!.partidas
              .firstWhere((p) => p.tipo == TipoPartidaSolicitud.cargaGranel)
              .tipoCombustible,
        ),
    ];
  }

  bool get _formularioCompleto =>
      _vehiculo != null &&
      _totalCargado > 0 &&
      _kmAlCargar > 0 &&
      _gasolineraController.text.trim().isNotEmpty &&
      _fotoTicketPath != null &&
      _fotoTableroPath != null &&
      (!_usaPartidas || _folioEstacionController.text.trim().isNotEmpty);

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_formularioCompleto) {
      setState(
        () => _errorGeneral =
            'Completa el vehículo, los litros, el km, la gasolinera y ambas fotos.',
      );
      return;
    }

    final confirmado = await ConfirmarFotosDialog.show(
      context,
      fotos: [
        FotoPreview(etiqueta: 'Foto del tablero', ruta: _fotoTableroPath!),
        FotoPreview(etiqueta: 'Foto del ticket', ruta: _fotoTicketPath!),
      ],
    );
    if (!confirmado || !mounted) return;

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    // Sin conexión detectada de entrada: se encola directo, igual que en
    // SolicitarCargaScreen — evita esperar el timeout de red.
    if (ref.read(conectividadProvider).valueOrNull == false) {
      if (_usaPartidas) {
        setState(() {
          _enviando = false;
          _errorGeneral =
              'La carga por conceptos requiere conexiÃ³n para validar el saldo de cada partida.';
        });
        return;
      }
      await _encolarSinConexion();
      return;
    }

    try {
      final perfil = ref.read(sessionProvider)!;
      final carga = await ref
          .read(operacionesRepositoryProvider)
          .registrarCarga(
            choferId: perfil.id,
            vehiculoId: _vehiculo!.id,
            folioAutorizacion: widget.folioAutorizacion,
            litrosCargados: _totalCargado,
            kmAlCargar: _kmAlCargar,
            gasolinera: _gasolineraController.text.trim(),
            fotoTicketPath: _fotoTicketPath,
            fotoTableroPath: _fotoTableroPath,
            litrosDetectadosOcr: _resultadoOcr?.litros,
            partidas: _partidasCarga,
            comprobantes: _usaPartidas
                ? [
                    ComprobanteEstacionCarga(
                      folioEstacion: _folioEstacionController.text.trim(),
                      concepto: 'visita_completa',
                      litrosIndicados: _resultadoOcr?.litros,
                    ),
                  ]
                : null,
          );
      HapticFeedback.mediumImpact();
      ref.read(operacionesTickProvider.notifier).state++;
      // 8 horas para "fin de jornada" confirmado por el usuario.
      await ref
          .read(recordatorioServiceProvider)
          .programarRecordatorioCerrarDia(
            cargaId: carga.id,
            cuando: carga.creadaEn.add(const Duration(hours: 8)),
          );
      if (mounted) context.go(RoutePaths.chofer);
    } on ApiException catch (e) {
      if (e.status == null) {
        if (_usaPartidas) {
          if (mounted) {
            setState(
              () => _errorGeneral =
                  'No se pudo validar el saldo por partida. Conserva los datos y reintenta con conexiÃ³n.',
            );
          }
          return;
        }
        // Sin `status` HTTP = nunca llegó a un servidor — posible falso
        // positivo del chequeo de conectividad de arriba.
        await _encolarSinConexion();
        return;
      }
      setState(() => _errorGeneral = e.mensaje);
    } catch (e) {
      setState(
        () =>
            _errorGeneral = 'No pudimos registrar tu carga. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Encola la comprobación para reintentarla al reconectar (ver
  /// `cola_solicitudes_offline.dart`). No se programa el recordatorio
  /// local de "cerrar mi día" aquí — depende del `id`/`creadaEn` reales
  /// que solo asigna el backend al sincronizar.
  Future<void> _encolarSinConexion() async {
    final perfil = ref.read(sessionProvider)!;
    final ahora = DateTime.now();
    await ref
        .read(colaComprobarCargaOfflineProvider)
        .agregar(
          ComprobarCargaPendienteOffline(
            idLocal: 'offline-${ahora.microsecondsSinceEpoch}',
            choferId: perfil.id,
            vehiculoId: _vehiculo!.id,
            folioAutorizacion: widget.folioAutorizacion,
            litrosCargados: _litrosCargados,
            kmAlCargar: _kmAlCargar,
            gasolinera: _gasolineraController.text.trim(),
            fotoTicketPath: _fotoTicketPath!,
            fotoTableroPath: _fotoTableroPath!,
            litrosDetectadosOcr: _resultadoOcr?.litros,
            creadaEn: ahora,
          ),
        );
    ref.read(operacionesTickProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _enviando = false);
    await SinConexionDialog.show(
      context,
      mensaje:
          'Guardamos tu comprobación en este dispositivo. Se enviará sola '
          'en cuanto vuelvas a tener señal — no hace falta que la repitas.',
    );
    if (mounted) context.go(RoutePaths.chofer);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final porHorometro =
        _vehiculo != null && esUnidadPorHorometro(_vehiculo!.tipoUnidad);

    return ChoferOperationScaffold(
      titulo: 'Registrar carga',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppCard(
            floating: true,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Folio ${widget.folioAutorizacion}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SelectorVehiculo(
            vehiculoSeleccionado: _vehiculo,
            onSeleccionar: (v) => setState(() => _vehiculo = v),
          ),
          const SizedBox(height: 20),
          CapturaFotoField(
            etiqueta: porHorometro
                ? 'Foto del tablero (horómetro al cargar)'
                : 'Foto del tablero (km al cargar)',
            icono: Icons.speed_outlined,
            rutaFoto: _fotoTableroPath,
            cargando: _cargandoFotoTablero,
            onTomarFoto: _tomarFotoTablero,
          ),
          const SizedBox(height: 12),
          CapturaFotoField(
            etiqueta: 'Foto del ticket de la gasolinera',
            icono: Icons.receipt_long_outlined,
            rutaFoto: _fotoTicketPath,
            cargando: _cargandoFotoTicket,
            onTomarFoto: _tomarFotoTicket,
          ),
          if (_resultadoOcr != null && !_resultadoOcr!.sinDatos) ...[
            const SizedBox(height: 8),
            _AvisoOcr(resultado: _resultadoOcr!, litrosEscritos: _totalCargado),
          ],
          const SizedBox(height: 20),
          if (_usaPartidas) ...[
            if (_solicitud!.partidas.any(
              (p) => p.tipo == TipoPartidaSolicitud.consumoPropio,
            ))
              StepperNumerico(
                etiqueta: 'Litros cargados al motor',
                valor: _litrosConsumoPropio,
                sufijo: 'L',
                paso: 1,
                decimales: 1,
                onChanged: (v) => setState(() => _litrosConsumoPropio = v),
              ),
            if (_solicitud!.partidas.length > 1) const SizedBox(height: 16),
            if (_solicitud!.partidas.any(
              (p) => p.tipo == TipoPartidaSolicitud.cargaGranel,
            ))
              StepperNumerico(
                etiqueta: 'Litros cargados al tanque a granel',
                valor: _litrosCargaGranel,
                sufijo: 'L',
                paso: 1,
                decimales: 1,
                onChanged: (v) => setState(() => _litrosCargaGranel = v),
              ),
            const SizedBox(height: 12),
            Text('Total de la visita: ${_totalCargado.toStringAsFixed(1)} L'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _folioEstacionController,
              decoration: const InputDecoration(
                labelText: 'Folio del ticket de estación',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else
            StepperNumerico(
              etiqueta: 'Litros cargados',
              valor: _litrosCargados,
              sufijo: 'L',
              paso: 1,
              decimales: 1,
              onChanged: (v) => setState(() => _litrosCargados = v),
            ),
          const SizedBox(height: 16),
          StepperNumerico(
            etiqueta: porHorometro
                ? 'Horómetro al cargar (según el tablero)'
                : 'Km al cargar (según el tablero)',
            valor: _kmAlCargar,
            sufijo: porHorometro ? 'h' : 'km',
            paso: 1,
            decimales: 0,
            onChanged: (v) => setState(() => _kmAlCargar = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _gasolineraController,
            decoration: const InputDecoration(labelText: 'Gasolinera'),
            onChanged: (_) => setState(() {}),
          ),
          if (_errorGeneral != null) ...[
            const SizedBox(height: 12),
            AvisoError(mensaje: _errorGeneral!),
          ],
          const SizedBox(height: 24),
          AppElevatedButton(
            onPressed: _enviar,
            cargando: _enviando,
            child: const Text('Enviar comprobación'),
          ),
        ],
      ),
    );
  }
}

class _AvisoOcr extends StatelessWidget {
  const _AvisoOcr({required this.resultado, required this.litrosEscritos});

  final ResultadoOcrTicket resultado;
  final double litrosEscritos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final coincide =
        resultado.litros != null &&
        (resultado.litros! - litrosEscritos).abs() <= 1.5;
    final color = coincide ? colors.success : colors.warning;

    return AppCard(
      floating: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            coincide ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              resultado.litros != null
                  ? (coincide
                        ? 'El ticket parece decir ${resultado.litros!.toStringAsFixed(1)} L — coincide.'
                        : 'El ticket parece decir ${resultado.litros!.toStringAsFixed(1)} L — revisa el dato.')
                  : 'No se pudo leer el ticket automáticamente, no afecta tu envío.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
