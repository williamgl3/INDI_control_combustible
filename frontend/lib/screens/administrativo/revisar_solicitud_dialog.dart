import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../data/api_client.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/formato_numero.dart';
import '../../widgets/stepper_numerico.dart';

/// Modal para que un administrativo resuelva manualmente una solicitud
/// [EstadoSolicitud.pendiente]: puede autorizar menos litros de los
/// pedidos (con motivo obligatorio) o rechazarla (también con motivo).
class RevisarSolicitudDialog extends ConsumerStatefulWidget {
  const RevisarSolicitudDialog({
    super.key,
    required this.solicitud,
    required this.nombreChofer,
  });

  final SolicitudAutorizacion solicitud;
  final String nombreChofer;

  static Future<bool?> show(
    BuildContext context, {
    required SolicitudAutorizacion solicitud,
    required String nombreChofer,
  }) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => RevisarSolicitudDialog(
        solicitud: solicitud,
        nombreChofer: nombreChofer,
      ),
    );
  }

  @override
  ConsumerState<RevisarSolicitudDialog> createState() =>
      _RevisarSolicitudDialogState();
}

class _RevisarSolicitudDialogState
    extends ConsumerState<RevisarSolicitudDialog> {
  late double _litrosAutorizados = widget.solicitud.litrosSolicitados;
  final _motivoController = TextEditingController();

  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  bool get _autorizaMenos =>
      _litrosAutorizados < widget.solicitud.litrosSolicitados;

  Future<void> _resolver({required bool aprobar}) async {
    final motivoVacio = _motivoController.text.trim().isEmpty;
    if (!aprobar && motivoVacio) {
      setState(() => _errorGeneral = 'Explica por qué se rechaza.');
      return;
    }
    if (aprobar && _autorizaMenos && motivoVacio) {
      setState(
        () =>
            _errorGeneral = 'Autorizaste menos de lo pedido — explica por qué.',
      );
      return;
    }

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      final admin = ref.read(sessionProvider)!;
      await ref
          .read(operacionesRepositoryProvider)
          .resolverSolicitud(
            solicitudId: widget.solicitud.id,
            aprobar: aprobar,
            resueltaPor: admin.nombreCompleto,
            litrosAutorizados: aprobar ? _litrosAutorizados : null,
            motivo: motivoVacio ? null : _motivoController.text.trim(),
          );
      HapticFeedback.mediumImpact();
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
    final vehiculo = ref
        .read(vehiculosRepositoryProvider)
        .porId(widget.solicitud.vehiculoId);
    final repo = ref.read(operacionesRepositoryProvider);

    return AppDialogShell(
      maxWidth: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.nombreChofer,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            vehiculo == null
                ? 'Vehículo no encontrado'
                : '${vehiculo.modelo ?? vehiculo.tipoUnidad} · '
                      '${vehiculo.etiquetaCompleta ?? vehiculo.etiquetaUnidad} · '
                      '${vehiculo.tipoCombustible ?? 'Sin especificar'}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Para: ${widget.solicitud.fechaProgramada.day.toString().padLeft(2, '0')}/'
            '${widget.solicitud.fechaProgramada.month.toString().padLeft(2, '0')}/'
            '${widget.solicitud.fechaProgramada.year}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            widget.solicitud.actividad,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (widget.solicitud.esUrgente) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: AppRadii.badgeRadius,
              ),
              child: Text(
                'URGENTE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (widget.solicitud.motivoChofer != null) ...[
            const SizedBox(height: 12),
            Text(
              '"${widget.solicitud.motivoChofer}"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DatoReferencia(
                  etiqueta: 'Solicitado',
                  valor:
                      '${widget.solicitud.litrosSolicitados.toStringAsFixed(1)} L',
                ),
              ),
              Expanded(
                child: _DatoReferencia(
                  etiqueta: 'Presup. semana',
                  valor: formatearMoneda(repo.presupuestoRestante),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StepperNumerico(
            etiqueta: 'Litros a autorizar',
            valor: _litrosAutorizados,
            sufijo: 'L',
            decimales: 1,
            onChanged: (v) => setState(() => _litrosAutorizados = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _motivoController,
            decoration: InputDecoration(
              labelText: _autorizaMenos
                  ? 'Motivo (obligatorio: autorizas menos de lo pedido)'
                  : 'Motivo (obligatorio solo si rechazas)',
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cargando ? null : () => _resolver(aprobar: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                  ),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _cargando ? null : () => _resolver(aprobar: true),
                  child: _cargando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Autorizar ${_litrosAutorizados.toStringAsFixed(0)} L',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatoReferencia extends StatelessWidget {
  const _DatoReferencia({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: AppTextStyles.monoData(
            colors.textPrimary,
          ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
