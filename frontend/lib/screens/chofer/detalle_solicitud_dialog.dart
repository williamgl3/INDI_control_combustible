import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/providers.dart';
import '../../data/api_client.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/confirmar_accion_dialog.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/ver_foto_dialog.dart';

/// Detalle de una solicitud propia — antes tocar una fila de "Actividad
/// reciente"/"Mis solicitudes" no hacía nada. Muestra la foto del tablero
/// tomada al pedir (si la hay) y, mientras siga pendiente, deja
/// cancelarla sin tener que esperar a que el admin la resuelva.
class DetalleSolicitudDialog extends ConsumerStatefulWidget {
  const DetalleSolicitudDialog({
    super.key,
    required this.solicitud,
    required this.vehiculo,
  });

  final SolicitudAutorizacion solicitud;
  final Vehiculo? vehiculo;

  static Future<bool?> show(
    BuildContext context, {
    required SolicitudAutorizacion solicitud,
    Vehiculo? vehiculo,
  }) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) =>
          DetalleSolicitudDialog(solicitud: solicitud, vehiculo: vehiculo),
    );
  }

  @override
  ConsumerState<DetalleSolicitudDialog> createState() =>
      _DetalleSolicitudDialogState();
}

class _DetalleSolicitudDialogState
    extends ConsumerState<DetalleSolicitudDialog> {
  bool _cancelando = false;
  String? _errorGeneral;

  Future<void> _cancelar() async {
    final confirmado = await ConfirmarAccionDialog.show(
      context,
      titulo: 'Cancelar solicitud',
      mensaje:
          '¿Seguro que quieres cancelar esta solicitud de '
          '${widget.solicitud.litrosSolicitados.toStringAsFixed(1)} L? No '
          'podrás deshacer esto.',
      textoConfirmar: 'Sí, cancelar',
      destructivo: true,
    );
    if (!confirmado || !mounted) return;

    setState(() {
      _cancelando = true;
      _errorGeneral = null;
    });
    try {
      await ref
          .read(operacionesRepositoryProvider)
          .cancelarSolicitud(widget.solicitud.id);
      ref.read(operacionesTickProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorGeneral = e.mensaje);
    } catch (_) {
      setState(
        () => _errorGeneral = 'No pudimos cancelar tu solicitud. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = widget.solicitud;
    final esPendiente = s.estado == EstadoSolicitud.pendiente;
    final fotoPath = s.fotoTableroPath;

    return AppDialogShell(
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.litrosSolicitados.toStringAsFixed(1)} L solicitados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              EstadoSolicitudBadge(estado: s.estado),
            ],
          ),
          const SizedBox(height: 4),
          if (widget.vehiculo != null)
            Text(
              '${widget.vehiculo!.tipoUnidad} · ${widget.vehiculo!.identificador}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          const SizedBox(height: 16),
          _Dato(etiqueta: 'Actividad', valor: s.actividad),
          _Dato(
            etiqueta: 'Fecha en que se necesita',
            valor: formatearFecha(s.fechaProgramada),
          ),
          if (s.motivoChofer != null)
            _Dato(etiqueta: 'Motivo', valor: s.motivoChofer!),
          if (s.folioAutorizacion != null)
            _Dato(etiqueta: 'Folio', valor: s.folioAutorizacion!),
          if (s.litrosAutorizados != null &&
              s.litrosAutorizados != s.litrosSolicitados)
            _Dato(
              etiqueta: 'Litros autorizados',
              valor: '${s.litrosAutorizados!.toStringAsFixed(1)} L',
            ),
          if (s.comentario != null)
            _Dato(etiqueta: 'Comentario', valor: s.comentario!),
          if (fotoPath != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => VerFotoDialog.show(
                context,
                titulo: 'Foto del tablero',
                url: fotoPath.startsWith('/')
                    ? '${ApiConfig.baseUrl}$fotoPath'
                    : null,
                rutaLocal: fotoPath.startsWith('/') ? null : fotoPath,
              ),
              icon: const Icon(Icons.photo_outlined),
              label: const Text('Ver foto del tablero'),
            ),
          ],
          if (_errorGeneral != null) ...[
            const SizedBox(height: 12),
            AvisoError(mensaje: _errorGeneral!),
          ],
          const SizedBox(height: 20),
          if (esPendiente)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelando
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cerrar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppElevatedButton(
                    onPressed: _cancelar,
                    cargando: _cancelando,
                    child: const Text('Cancelar solicitud'),
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cerrar'),
            ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(valor, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
