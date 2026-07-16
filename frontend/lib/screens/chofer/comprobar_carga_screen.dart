import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../core/ticket_ocr_service.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/selector_vehiculo.dart';
import '../../widgets/stepper_numerico.dart';

/// Registro 1 del día: se llena justo después de cargar combustible,
/// contra un folio ya autorizado. Llega vía `state.extra` (el folio,
/// String) desde /chofer/respuesta o desde la tarjeta de "carga pendiente"
/// en /chofer.
class ComprobarCargaScreen extends ConsumerStatefulWidget {
  const ComprobarCargaScreen({super.key, required this.folioAutorizacion});

  final String folioAutorizacion;

  @override
  ConsumerState<ComprobarCargaScreen> createState() => _ComprobarCargaScreenState();
}

class _ComprobarCargaScreenState extends ConsumerState<ComprobarCargaScreen> {
  final _gasolineraController = TextEditingController();

  Vehiculo? _vehiculo;
  double _litrosCargados = 0;
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
    final solicitud =
        ref.read(operacionesRepositoryProvider).solicitudPorFolio(widget.folioAutorizacion);
    if (solicitud != null) {
      _vehiculo = ref.read(vehiculosRepositoryProvider).porId(solicitud.vehiculoId);
    }
  }

  @override
  void dispose() {
    _gasolineraController.dispose();
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

  bool get _formularioCompleto =>
      _vehiculo != null &&
      _litrosCargados > 0 &&
      _kmAlCargar > 0 &&
      _gasolineraController.text.trim().isNotEmpty &&
      _fotoTicketPath != null &&
      _fotoTableroPath != null;

  Future<void> _enviar() async {
    if (!_formularioCompleto) {
      setState(() => _errorGeneral =
          'Completa el vehículo, los litros, el km, la gasolinera y ambas fotos.');
      return;
    }

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    try {
      final perfil = ref.read(sessionProvider)!;
      final carga = await ref.read(operacionesRepositoryProvider).registrarCarga(
            choferId: perfil.id,
            vehiculoId: _vehiculo!.id,
            folioAutorizacion: widget.folioAutorizacion,
            litrosCargados: _litrosCargados,
            kmAlCargar: _kmAlCargar,
            gasolinera: _gasolineraController.text.trim(),
            fotoTicketPath: _fotoTicketPath,
            fotoTableroPath: _fotoTableroPath,
            litrosDetectadosOcr: _resultadoOcr?.litros,
          );
      ref.read(operacionesTickProvider.notifier).state++;
      // TODO-SPEC: 8 horas es un placeholder para "fin de jornada".
      await ref.read(recordatorioServiceProvider).programarRecordatorioCerrarDia(
            cargaId: carga.id,
            cuando: carga.creadaEn.add(const Duration(hours: 8)),
          );
      if (mounted) context.go(RoutePaths.chofer);
    } catch (e) {
      setState(() => _errorGeneral = 'No pudimos registrar tu carga. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar carga'),
        leading: BackButton(onPressed: () => context.go(RoutePaths.chofer)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: AppRadii.cardRadius,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.confirmation_number_outlined, color: colors.textSecondary),
                        const SizedBox(width: 12),
                        Text('Folio ${widget.folioAutorizacion}',
                            style: Theme.of(context).textTheme.titleMedium),
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
                    etiqueta: 'Foto del tablero (km al cargar)',
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
                    _AvisoOcr(resultado: _resultadoOcr!, litrosEscritos: _litrosCargados),
                  ],
                  const SizedBox(height: 20),
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
                    etiqueta: 'Km al cargar (según el tablero)',
                    valor: _kmAlCargar,
                    sufijo: 'km',
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
                    Text(_errorGeneral!, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enviar comprobación'),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final coincide = resultado.litros != null &&
        (resultado.litros! - litrosEscritos).abs() <= 1.5;
    final color = coincide ? colors.success : colors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        children: [
          Icon(coincide ? Icons.check_circle_outline : Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              resultado.litros != null
                  ? (coincide
                      ? 'El ticket parece decir ${resultado.litros!.toStringAsFixed(1)} L — coincide.'
                      : 'El ticket parece decir ${resultado.litros!.toStringAsFixed(1)} L — revisa el dato.')
                  : 'No se pudo leer el ticket automáticamente, no afecta tu envío.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
