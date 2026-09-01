import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/session_provider.dart';
import '../../../models/solicitud_autorizacion.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_elevated_button.dart';
import '../../../widgets/aviso_error.dart';
import '../../../widgets/barra_presupuesto.dart';
import '../../../widgets/estado_solicitud_badge.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/fecha_formato.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/ios_segmented_control.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/stat_tile.dart';
import '../../../widgets/stat_tile_row.dart';
import '../revisar_solicitud_dialog.dart';

enum _FiltroEstado { todas, pendientes, aprobadas, ajustadas, rechazadas }

/// Pestaña "Autorizaciones": solicitudes de todos los choferes, filtrables
/// por estado, con acción de revisión manual para las pendientes.
class AutorizacionesTab extends ConsumerStatefulWidget {
  const AutorizacionesTab({super.key, this.solicitudIdInicial});

  final String? solicitudIdInicial;

  @override
  ConsumerState<AutorizacionesTab> createState() => _AutorizacionesTabState();
}

class _AutorizacionesTabState extends ConsumerState<AutorizacionesTab> {
  static const _limiteMostradas = 30;

  _FiltroEstado _filtroVista = _FiltroEstado.todas;
  String? _solicitudInicialAtendida;

  @override
  void initState() {
    super.initState();
    if (widget.solicitudIdInicial != null) {
      _filtroVista = _FiltroEstado.pendientes;
    }
  }

  @override
  void didUpdateWidget(covariant AutorizacionesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.solicitudIdInicial != oldWidget.solicitudIdInicial) {
      _solicitudInicialAtendida = null;
      if (widget.solicitudIdInicial != null) {
        _filtroVista = _FiltroEstado.pendientes;
      }
    }
  }

  /// Ids de solicitudes pendientes marcadas para una acción en lote — se
  /// vacía cada vez que se cambia de filtro para no arrastrar selección
  /// entre vistas distintas.
  final Set<String> _seleccionadas = {};
  bool _procesandoLote = false;

  /// `null` representa el filtro "Todas".
  bool _coincideFiltro(SolicitudAutorizacion s) => switch (_filtroVista) {
    _FiltroEstado.todas => true,
    _FiltroEstado.pendientes => s.estado == EstadoSolicitud.pendiente,
    _FiltroEstado.aprobadas =>
      s.estadoVisual == EstadoVisualSolicitud.autorizada,
    _FiltroEstado.ajustadas => s.estadoVisual == EstadoVisualSolicitud.ajustada,
    _FiltroEstado.rechazadas =>
      s.estadoVisual == EstadoVisualSolicitud.rechazada,
  };

  Future<void> _revisar(
    SolicitudAutorizacion solicitud,
    String nombreChofer,
  ) async {
    final resuelta = await RevisarSolicitudDialog.show(
      context,
      solicitud: solicitud,
      nombreChofer: nombreChofer,
    );
    if (resuelta == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud revisada correctamente.')),
      );
    }
  }

  void _alternarSeleccion(String solicitudId, bool marcada) {
    setState(() {
      if (marcada) {
        _seleccionadas.add(solicitudId);
      } else {
        _seleccionadas.remove(solicitudId);
      }
    });
  }

  /// Aprueba de un jalón cada solicitud seleccionada, al 100% de lo
  /// pedido (una aprobación en lote no tiene sentido para "autorizar
  /// menos", que necesita un motivo específico por solicitud — para eso
  /// sigue existiendo "Revisar" una por una).
  Future<void> _aprobarSeleccionadas(List<SolicitudAutorizacion> todas) async {
    final admin = ref.read(sessionProvider);
    if (admin == null) return;
    final repo = ref.read(operacionesRepositoryProvider);
    final idsAProcesar = {..._seleccionadas};

    setState(() => _procesandoLote = true);
    var fallidas = 0;
    for (final id in idsAProcesar) {
      final solicitud = todas.firstWhere((s) => s.id == id);
      try {
        await repo.resolverSolicitud(
          solicitudId: id,
          aprobar: true,
          resueltaPor: admin.nombreCompleto,
          litrosAutorizados: solicitud.litrosSolicitados,
        );
      } catch (_) {
        fallidas++;
      }
    }
    if (!mounted) return;
    setState(() {
      _procesandoLote = false;
      _seleccionadas.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fallidas == 0
              ? '${idsAProcesar.length} solicitudes aprobadas.'
              : '${idsAProcesar.length - fallidas} aprobadas, $fallidas no se pudieron procesar.',
        ),
      ),
    );
  }

  Future<void> _rechazarSeleccionadas(List<SolicitudAutorizacion> todas) async {
    final motivo = await _DialogoMotivoLote.show(context);
    if (motivo == null || !mounted) return;

    final admin = ref.read(sessionProvider);
    if (admin == null) return;
    final repo = ref.read(operacionesRepositoryProvider);
    final idsAProcesar = {..._seleccionadas};

    setState(() => _procesandoLote = true);
    var fallidas = 0;
    for (final id in idsAProcesar) {
      try {
        await repo.resolverSolicitud(
          solicitudId: id,
          aprobar: false,
          resueltaPor: admin.nombreCompleto,
          motivo: motivo,
        );
      } catch (_) {
        fallidas++;
      }
    }
    if (!mounted) return;
    setState(() {
      _procesandoLote = false;
      _seleccionadas.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fallidas == 0
              ? '${idsAProcesar.length} solicitudes rechazadas.'
              : '${idsAProcesar.length - fallidas} rechazadas, $fallidas no se pudieron procesar.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final choferes = ref.watch(authRepositoryProvider).listarChoferes();
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final solicitudes = repo.todasLasSolicitudes;
    final nombresPorChoferId = {
      for (final c in choferes) c.id: c.nombreCompleto,
    };
    final solicitudInicialId = widget.solicitudIdInicial;
    if (solicitudInicialId != null &&
        _solicitudInicialAtendida != solicitudInicialId) {
      _solicitudInicialAtendida = solicitudInicialId;
      final indice = solicitudes.indexWhere((s) => s.id == solicitudInicialId);
      if (indice >= 0) {
        final solicitud = solicitudes[indice];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _revisar(
            solicitud,
            nombresPorChoferId[solicitud.choferId] ?? solicitud.choferId,
          );
        });
      }
    }

    final pendientes = solicitudes
        .where((s) => s.estado == EstadoSolicitud.pendiente)
        .length;
    final aprobadas = solicitudes.where(
      (s) => s.estado == EstadoSolicitud.aprobada,
    );
    final litrosAutorizados = aprobadas.fold(
      0.0,
      (suma, s) => suma + (s.litrosAutorizados ?? s.litrosSolicitados),
    );

    final filtradas = solicitudes.where(_coincideFiltro).toList();
    final mostradas = filtradas.take(_limiteMostradas).toList();

    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Autorizaciones',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Revisa y resuelve las solicitudes de carga de combustible.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          StatTileRow(
            tiles: [
              StatTile(
                icono: Icons.hourglass_top_outlined,
                valor: '$pendientes',
                etiqueta: 'Por revisar',
                color: colors.textSecondary,
                destacado: pendientes > 0,
                onTap: () =>
                    setState(() => _filtroVista = _FiltroEstado.pendientes),
              ),
              StatTile(
                icono: Icons.local_gas_station_outlined,
                valor: litrosAutorizados.toStringAsFixed(0),
                etiqueta: 'L autorizados',
                color: AppSectionColors.autorizaciones,
                onTap: () =>
                    setState(() => _filtroVista = _FiltroEstado.aprobadas),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BarraPresupuesto(
            restante: repo.presupuestoRestante,
            total: repo.presupuestoSemanalTotal,
            etiquetaSemana: repo.etiquetaSemanaActual,
          ),
          const SizedBox(height: 24),
          IosSegmentedControl<_FiltroEstado>(
            valor: _filtroVista,
            opciones: const {
              _FiltroEstado.todas: 'Todas',
              _FiltroEstado.pendientes: 'Por autorizar',
              _FiltroEstado.aprobadas: 'Aprobadas',
              _FiltroEstado.ajustadas: 'Ajustadas',
              _FiltroEstado.rechazadas: 'Rechazadas',
            },
            onChanged: (f) => setState(() {
              _filtroVista = f;
              _seleccionadas.clear();
            }),
          ),
          if (_seleccionadas.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BarraAccionesLote(
              cantidad: _seleccionadas.length,
              procesando: _procesandoLote,
              onAprobar: () => _aprobarSeleccionadas(solicitudes),
              onRechazar: () => _rechazarSeleccionadas(solicitudes),
              onCancelar: () => setState(() => _seleccionadas.clear()),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Column(
              key: ValueKey(_filtroVista),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (filtradas.isEmpty)
                  EstadoVacio(
                    icono: Icons.assignment_outlined,
                    mensaje: _filtroVista == _FiltroEstado.todas
                        ? 'Aún no hay solicitudes registradas.'
                        : _filtroVista == _FiltroEstado.pendientes
                        ? 'No hay solicitudes por autorizar.'
                        : 'No hay solicitudes con este filtro.',
                  )
                else ...[
                  for (final grupo in agruparPorFecha(
                    mostradas,
                    (s) => s.creadaEn,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GroupedSection(
                        header: grupo.etiqueta,
                        children: [
                          for (final s in grupo.items)
                            _SolicitudTile(
                              key: ValueKey('solicitud-${s.id}'),
                              solicitud: s,
                              nombreChofer:
                                  nombresPorChoferId[s.choferId] ?? s.choferId,
                              onRevisar: () => _revisar(
                                s,
                                nombresPorChoferId[s.choferId] ?? s.choferId,
                              ),
                              seleccionada: _seleccionadas.contains(s.id),
                              onCambiarSeleccion:
                                  s.estado == EstadoSolicitud.pendiente
                                  ? (marcada) =>
                                        _alternarSeleccion(s.id, marcada)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  if (filtradas.length > mostradas.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Mostrando las $_limiteMostradas más recientes de ${filtradas.length}.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de un solo campo para el motivo de rechazo COMPARTIDO por
/// todas las solicitudes de un rechazo en lote — igual que
/// `RevisarSolicitudDialog` exige motivo al rechazar una por una, aquí se
/// pide una sola vez y se aplica igual a cada solicitud seleccionada.
class _DialogoMotivoLote extends StatefulWidget {
  const _DialogoMotivoLote();

  static Future<String?> show(BuildContext context) {
    return mostrarDialogoApp<String>(
      context,
      builder: (_) => const _DialogoMotivoLote(),
    );
  }

  @override
  State<_DialogoMotivoLote> createState() => _DialogoMotivoLoteState();
}

class _DialogoMotivoLoteState extends State<_DialogoMotivoLote> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final motivo = _controller.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'Explica por qué se rechazan.');
      return;
    }
    Navigator.of(context).pop(motivo);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rechazar solicitudes seleccionadas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Este motivo se aplicará a todas las solicitudes elegidas.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Motivo del rechazo'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AvisoError(mensaje: _error!),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmar,
                  child: const Text('Rechazar todas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barra de acciones que aparece mientras haya solicitudes pendientes
/// seleccionadas — antes había que abrir un diálogo por solicitud aunque
/// hubiera 20 pendientes idénticas por revisar.
class _BarraAccionesLote extends StatelessWidget {
  const _BarraAccionesLote({
    required this.cantidad,
    required this.procesando,
    required this.onAprobar,
    required this.onRechazar,
    required this.onCancelar,
  });

  final int cantidad;
  final bool procesando;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              cantidad == 1 ? '1 seleccionada' : '$cantidad seleccionadas',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: colors.primary),
            ),
          ),
          if (procesando)
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            TextButton(onPressed: onCancelar, child: const Text('Cancelar')),
            const SizedBox(width: 4),
            OutlinedButton(
              onPressed: onRechazar,
              style: OutlinedButton.styleFrom(foregroundColor: colors.error),
              child: const Text('Rechazar'),
            ),
            const SizedBox(width: 8),
            AppElevatedButton(
              onPressed: onAprobar,
              cargando: false,
              child: const Text('Aprobar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({
    super.key,
    required this.solicitud,
    required this.nombreChofer,
    required this.onRevisar,
    this.seleccionada = false,
    this.onCambiarSeleccion,
  });

  final SolicitudAutorizacion solicitud;
  final String nombreChofer;
  final VoidCallback? onRevisar;

  /// `null` = esta solicitud no se puede seleccionar (no está pendiente).
  final bool seleccionada;
  final ValueChanged<bool>? onCambiarSeleccion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final esPendiente = solicitud.estado == EstadoSolicitud.pendiente;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onCambiarSeleccion != null) ...[
                Checkbox(
                  value: seleccionada,
                  onChanged: (v) => onCambiarSeleccion!(v ?? false),
                ),
                const SizedBox(width: 4),
              ],
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Text(
                  nombreChofer.isNotEmpty ? nombreChofer[0].toUpperCase() : '?',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${solicitud.litrosSolicitados.toStringAsFixed(1)} L · $nombreChofer',
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (solicitud.esUrgente) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.bolt, size: 14, color: colors.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Solicitud: ${formatearFechaCorta(solicitud.creadaEn)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                    if (solicitud.litrosAutorizados != null &&
                        solicitud.litrosAutorizados !=
                            solicitud.litrosSolicitados) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Autorizado: ${solicitud.litrosAutorizados!.toStringAsFixed(1)} L',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    if (solicitud.comentario != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        solicitud.comentario!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              EstadoSolicitudBadge(estadoVisual: solicitud.estadoVisual),
            ],
          ),
          if (esPendiente && onRevisar != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onRevisar,
                child: const Text('Revisar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
