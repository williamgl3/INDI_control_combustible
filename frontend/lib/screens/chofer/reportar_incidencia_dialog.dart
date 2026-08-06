import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cola_solicitudes_offline.dart';
import '../../core/connectivity_provider.dart';
import '../../core/providers.dart';
import '../../data/api_client.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/aviso_error.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/sin_conexion_dialog.dart';

/// El chofer reporta una falla o incidencia real de un vehículo (ej. "se
/// ponchó una llanta", "el motor hace un ruido raro") — distinto del
/// mantenimiento preventivo por km/horómetro, que es programado, no
/// reactivo a un problema detectado en campo. Llega directo a la pestaña
/// de Mantenimiento del panel admin.
class ReportarIncidenciaDialog extends ConsumerStatefulWidget {
  const ReportarIncidenciaDialog({super.key, required this.vehiculo});

  final Vehiculo vehiculo;

  static Future<bool?> show(BuildContext context, {required Vehiculo vehiculo}) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => ReportarIncidenciaDialog(vehiculo: vehiculo),
    );
  }

  @override
  ConsumerState<ReportarIncidenciaDialog> createState() =>
      _ReportarIncidenciaDialogState();
}

class _ReportarIncidenciaDialogState
    extends ConsumerState<ReportarIncidenciaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();

  bool _cargando = false;
  String? _errorGeneral;

  /// Opcional — no toda incidencia es fotografiable (ej. "ruido raro en
  /// el motor"), a diferencia de las fotos de carga/cierre que sí son
  /// obligatorias.
  String? _fotoPath;
  bool _cargandoFoto = false;

  Future<void> _tomarFoto() async {
    setState(() => _cargandoFoto = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) _fotoPath = ruta;
        _cargandoFoto = false;
      });
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _reportar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    final descripcion = _descripcionController.text.trim();

    // Sin conexión detectada de entrada: se encola directo, igual que en
    // SolicitarCargaScreen — evita esperar el timeout de red.
    if (ref.read(conectividadProvider).valueOrNull == false) {
      await _encolarSinConexion(descripcion);
      return;
    }

    try {
      await ref
          .read(incidenciasRepositoryProvider)
          .reportar(
            vehiculoId: widget.vehiculo.id,
            descripcion: descripcion,
            fotoPath: _fotoPath,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.status == null) {
        // Sin `status` HTTP = nunca llegó a un servidor — posible falso
        // positivo del chequeo de conectividad de arriba.
        await _encolarSinConexion(descripcion);
        return;
      }
      setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Encola el reporte para reintentarlo al reconectar (ver
  /// `cola_solicitudes_offline.dart`) — la foto es opcional aquí (a
  /// diferencia de las otras 3 colas, donde es obligatoria).
  Future<void> _encolarSinConexion(String descripcion) async {
    final ahora = DateTime.now();
    await ref
        .read(colaIncidenciasOfflineProvider)
        .agregar(
          IncidenciaPendienteOffline(
            idLocal: 'offline-${ahora.microsecondsSinceEpoch}',
            vehiculoId: widget.vehiculo.id,
            descripcion: descripcion,
            creadaEn: ahora,
            fotoPath: _fotoPath,
          ),
        );
    ref.read(operacionesTickProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _cargando = false);
    await SinConexionDialog.show(
      context,
      mensaje:
          'Guardamos tu reporte en este dispositivo. Se enviará solo en '
          'cuanto vuelvas a tener señal — no hace falta que lo repitas.',
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialogShell(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reportar falla o incidencia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.vehiculo.tipoUnidad} · ${widget.vehiculo.etiquetaUnidad}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            CapturaFotoField(
              etiqueta: 'Foto de la falla (opcional)',
              icono: Icons.photo_camera_outlined,
              rutaFoto: _fotoPath,
              cargando: _cargandoFoto,
              onTomarFoto: _tomarFoto,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Ej. se ponchó una llanta, ruido raro en el motor…',
              ),
              minLines: 2,
              maxLines: 5,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Describe la falla o incidencia.'
                  : null,
            ),
            if (_errorGeneral != null) ...[
              const SizedBox(height: 12),
              AvisoError(mensaje: _errorGeneral!),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppElevatedButton(
                    onPressed: _reportar,
                    cargando: _cargando,
                    child: const Text('Reportar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
