import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity_provider.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/responsive_scroll_view.dart';
import '../../widgets/sin_conexion_dialog.dart';

enum _TipoEvidencia { ticket, tablero, comprobante }

class SubirEvidenciasScreen extends ConsumerStatefulWidget {
  const SubirEvidenciasScreen({super.key, this.mostrarComoTab = false});

  /// `true` cuando esta pantalla vive embebida como una pestaña de
  /// [ChoferHomeShell] (sin BrandHeader ni botón de volver propios, ya
  /// los da el shell) en vez de empujada como ruta independiente.
  final bool mostrarComoTab;

  @override
  ConsumerState<SubirEvidenciasScreen> createState() =>
      _SubirEvidenciasScreenState();
}

class _SubirEvidenciasScreenState extends ConsumerState<SubirEvidenciasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notasController = TextEditingController();
  final _folioController = TextEditingController();

  _TipoEvidencia _tipo = _TipoEvidencia.ticket;
  String? _fotoPath;
  bool _cargandoFoto = false;
  bool _enviando = false;
  String? _errorGeneral;
  bool _guardado = false;

  @override
  void dispose() {
    _notasController.dispose();
    _folioController.dispose();
    super.dispose();
  }

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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fotoPath == null) {
      setState(() => _errorGeneral = 'Toma una foto de la evidencia.');
      return;
    }

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final hayConexion = ref.read(conectividadProvider).valueOrNull ?? true;
    if (!hayConexion) {
      await SinConexionDialog.show(
        context,
        mensaje:
            'La evidencia se guardó localmente y se enviará cuando vuelva la conexión.',
      );
    }

    setState(() {
      _enviando = false;
      _guardado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final perfil = ref.watch(sessionProvider);
    final nombre = perfil?.nombreCompleto.split(' ').first ?? '';

    if (_guardado) {
      if (widget.mostrarComoTab) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: colors.success,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Evidencia guardada',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu evidencia fue registrada exitosamente.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppElevatedButton(
                  onPressed: () => setState(() => _guardado = false),
                  cargando: false,
                  child: const Text('Subir otra evidencia'),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: colors.success,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Evidencia guardada',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu evidencia fue registrada exitosamente.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AppElevatedButton(
                      onPressed: () => context.pop(),
                      cargando: false,
                      child: const Text('Volver al inicio'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            'Tipo de evidencia',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _SelectorTipoEvidencia(
            seleccionado: _tipo,
            onChanged: (t) => setState(() => _tipo = t),
          ),
          const SizedBox(height: 24),
          Text(
            'Foto de la evidencia',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          CapturaFotoField(
            etiqueta: _etiquetaFoto,
            icono: _iconoFoto,
            rutaFoto: _fotoPath,
            cargando: _cargandoFoto,
            onTomarFoto: _tomarFoto,
          ),
          const SizedBox(height: 24),
          Text(
            'Folio / Solicitud asociada (opcional)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _folioController,
            decoration: const InputDecoration(
              hintText: 'Ej: FOL-2026-001',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Notas adicionales',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notasController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe brevemente la evidencia...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          if (_errorGeneral != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: AppRadii.cardRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorGeneral!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          AppElevatedButton(
            onPressed: _guardar,
            cargando: _enviando,
            child: const Text('Guardar evidencia'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );

    if (widget.mostrarComoTab) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Hola, $nombre',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Adjunta fotos o comprobantes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              formContent,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ResponsiveScrollView(
                child: formContent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _etiquetaFoto {
    switch (_tipo) {
      case _TipoEvidencia.ticket:
        return 'Foto del ticket de gasolinera';
      case _TipoEvidencia.tablero:
        return 'Foto del tablero / odómetro';
      case _TipoEvidencia.comprobante:
        return 'Foto del comprobante';
    }
  }

  IconData get _iconoFoto {
    switch (_tipo) {
      case _TipoEvidencia.ticket:
        return Icons.receipt_long_outlined;
      case _TipoEvidencia.tablero:
        return Icons.speed_outlined;
      case _TipoEvidencia.comprobante:
        return Icons.description_outlined;
    }
  }
}

class _SelectorTipoEvidencia extends StatelessWidget {
  const _SelectorTipoEvidencia({
    required this.seleccionado,
    required this.onChanged,
  });

  final _TipoEvidencia seleccionado;
  final ValueChanged<_TipoEvidencia> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: _OpcionTipo(
            icono: Icons.receipt_long_outlined,
            etiqueta: 'Ticket',
            seleccionado: seleccionado == _TipoEvidencia.ticket,
            color: colors.primary,
            onTap: () => onChanged(_TipoEvidencia.ticket),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OpcionTipo(
            icono: Icons.speed_outlined,
            etiqueta: 'Tablero',
            seleccionado: seleccionado == _TipoEvidencia.tablero,
            color: colors.info,
            onTap: () => onChanged(_TipoEvidencia.tablero),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OpcionTipo(
            icono: Icons.description_outlined,
            etiqueta: 'Comprobante',
            seleccionado: seleccionado == _TipoEvidencia.comprobante,
            color: colors.warning,
            onTap: () => onChanged(_TipoEvidencia.comprobante),
          ),
        ),
      ],
    );
  }
}

class _OpcionTipo extends StatelessWidget {
  const _OpcionTipo({
    required this.icono,
    required this.etiqueta,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: seleccionado
          ? color.withValues(alpha: 0.12)
          : colors.surfaceAlt,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                icono,
                color: seleccionado ? color : colors.textMuted,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                etiqueta,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: seleccionado ? color : colors.textMuted,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
