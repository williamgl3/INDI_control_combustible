import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/cola_solicitudes_offline.dart';
import '../../core/connectivity_provider.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../data/api_client.dart';
import '../../models/carga.dart';
import '../../models/cierre_dia.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/sin_conexion_dialog.dart';
import '../../widgets/stepper_numerico.dart';

/// Registro 2 del día: se llena cuando el chofer termina de trabajar,
/// contra la [Carga] (registro 1) de ese mismo día. Llega vía
/// `state.extra` (la [Carga]) desde /chofer.
class CerrarDiaScreen extends ConsumerStatefulWidget {
  const CerrarDiaScreen({super.key, required this.carga});

  final Carga carga;

  @override
  ConsumerState<CerrarDiaScreen> createState() => _CerrarDiaScreenState();
}

class _CerrarDiaScreenState extends ConsumerState<CerrarDiaScreen> {
  double _kmFinal = 0;
  String? _fotoTableroPath;

  bool _cargandoFoto = false;
  bool _enviando = false;
  String? _errorGeneral;
  RendimientoDia? _resultado;

  Future<void> _tomarFoto() async {
    setState(() => _cargandoFoto = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) _fotoTableroPath = ruta;
        _cargandoFoto = false;
      });
    }
  }

  Future<void> _enviar() async {
    if (_kmFinal <= widget.carga.kmAlCargar) {
      setState(
        () => _errorGeneral =
            'La lectura final debe ser mayor a la de cuando cargaste (${widget.carga.kmAlCargar.toStringAsFixed(0)}).',
      );
      return;
    }
    if (_fotoTableroPath == null) {
      setState(
        () => _errorGeneral = 'Toma la foto del tablero con la lectura final.',
      );
      return;
    }

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    // Sin conexión detectada de entrada: se encola directo, igual que en
    // SolicitarCargaScreen — evita esperar el timeout de red.
    if (ref.read(conectividadProvider).valueOrNull == false) {
      await _encolarSinConexion();
      return;
    }

    try {
      final perfil = ref.read(sessionProvider)!;
      final repo = ref.read(operacionesRepositoryProvider);
      final cierre = await repo.cerrarDia(
        choferId: perfil.id,
        cargaId: widget.carga.id,
        kmFinal: _kmFinal,
        fotoTableroPath: _fotoTableroPath!,
      );
      final resultado = repo.rendimientoDe(cierre);
      HapticFeedback.mediumImpact();
      ref.read(operacionesTickProvider.notifier).state++;
      await ref
          .read(recordatorioServiceProvider)
          .cancelarRecordatorio(widget.carga.id);
      if (mounted) setState(() => _resultado = resultado);
    } on ApiException catch (e) {
      if (e.status == null) {
        // Sin `status` HTTP = nunca llegó a un servidor — posible falso
        // positivo del chequeo de conectividad de arriba.
        await _encolarSinConexion();
        return;
      }
      setState(() => _errorGeneral = e.mensaje);
    } catch (e) {
      setState(
        () => _errorGeneral = 'No pudimos cerrar tu día. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Encola el cierre de día para reintentarlo al reconectar (ver
  /// `cola_solicitudes_offline.dart`). Sin resultado de rendimiento que
  /// mostrar aquí — se calcula del lado del backend al sincronizar.
  Future<void> _encolarSinConexion() async {
    final perfil = ref.read(sessionProvider)!;
    final ahora = DateTime.now();
    await ref
        .read(colaCerrarDiaOfflineProvider)
        .agregar(
          CerrarDiaPendienteOffline(
            idLocal: 'offline-${ahora.microsecondsSinceEpoch}',
            choferId: perfil.id,
            cargaId: widget.carga.id,
            kmFinal: _kmFinal,
            fotoTableroPath: _fotoTableroPath!,
            creadaEn: ahora,
          ),
        );
    ref.read(operacionesTickProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _enviando = false);
    await SinConexionDialog.show(
      context,
      mensaje:
          'Guardamos el cierre de tu día en este dispositivo. Se enviará '
          'solo en cuanto vuelvas a tener señal — no hace falta que lo '
          'repitas.',
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculo = ref
        .watch(vehiculosRepositoryProvider)
        .porId(widget.carga.vehiculoId);
    final porHorometro =
        vehiculo != null && esUnidadPorHorometro(vehiculo.tipoUnidad);
    final unidad = porHorometro ? 'h' : 'km';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerrar mi día'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ContenidoResponsivo(
          child: _resultado != null
              ? _ResultadoCierre(
                  resultado: _resultado!,
                  porHorometro: porHorometro,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppCard(
                      floating: true,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.speed_outlined,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Cargaste combustible hoy con '
                              '${widget.carga.kmAlCargar.toStringAsFixed(0)} $unidad en el tablero.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    CapturaFotoField(
                      etiqueta: porHorometro
                          ? 'Foto del tablero (horómetro final)'
                          : 'Foto del tablero (km final)',
                      icono: Icons.speed_outlined,
                      rutaFoto: _fotoTableroPath,
                      cargando: _cargandoFoto,
                      onTomarFoto: _tomarFoto,
                    ),
                    const SizedBox(height: 16),
                    StepperNumerico(
                      etiqueta: porHorometro
                          ? 'Horómetro final del día'
                          : 'Km final del día',
                      valor: _kmFinal,
                      sufijo: unidad,
                      paso: 1,
                      decimales: 0,
                      minimo: widget.carga.kmAlCargar,
                      onChanged: (v) => setState(() => _kmFinal = v),
                    ),
                    if (_errorGeneral != null) ...[
                      const SizedBox(height: 12),
                      AvisoError(mensaje: _errorGeneral!),
                    ],
                    const SizedBox(height: 24),
                    AppElevatedButton(
                      onPressed: _enviar,
                      cargando: _enviando,
                      child: const Text('Cerrar mi día'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ResultadoCierre extends StatelessWidget {
  const _ResultadoCierre({required this.resultado, required this.porHorometro});

  final RendimientoDia resultado;
  final bool porHorometro;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = resultado.esAnomalo ? colors.warning : colors.success;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.check_circle, color: color, size: 44),
        ),
        const SizedBox(height: 24),
        Text('Día cerrado', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          porHorometro
              ? '${resultado.kmRecorridos.toStringAsFixed(0)} horas trabajadas'
              : '${resultado.kmRecorridos.toStringAsFixed(0)} km recorridos',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        AppCard(
          floating: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Rendimiento',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                resultado.rendimiento != null
                    ? '${resultado.rendimiento!.toStringAsFixed(1)} km/L'
                    : 'No calculable',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: color),
              ),
              if (resultado.esAnomalo) ...[
                const SizedBox(height: 4),
                Text(
                  'Fuera de lo habitual — un admin lo revisará.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.warning),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          // pop() (no go()): se llegó aquí con push() desde /chofer, y el
          // caller espera ese Future para refrescar sus datos al volver.
          onPressed: () => context.pop(),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}
