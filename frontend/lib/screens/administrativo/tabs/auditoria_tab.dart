import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_logger.dart';
import '../../../core/providers.dart';
import '../../../models/registro_auditoria.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/fecha_formato.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/responsive_scroll_view.dart';

/// Pestaña "Auditoría": bitácora cronológica (más reciente primero) de la
/// actividad administrativa — quién hizo qué, sobre qué entidad, y
/// cuándo. Pensada para trazabilidad, no para actuar sobre los registros
/// (son de solo lectura).
class AuditoriaTab extends ConsumerStatefulWidget {
  const AuditoriaTab({super.key});

  @override
  ConsumerState<AuditoriaTab> createState() => _AuditoriaTabState();
}

class _AuditoriaTabState extends ConsumerState<AuditoriaTab> {
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarInicial();
  }

  Future<void> _cargarInicial() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(auditoriaRepositoryProvider).cargarRegistros();
    } catch (e) {
      AppLogger.error('AuditoriaTab._cargarInicial', e);
      if (mounted) {
        setState(() => _error = 'No pudimos cargar la auditoría.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMas() async {
    setState(() => _cargandoMas = true);
    try {
      await ref.read(auditoriaRepositoryProvider).cargarMasRegistros();
    } catch (e) {
      AppLogger.error('AuditoriaTab._cargarMas', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos cargar más registros. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repo = ref.watch(auditoriaRepositoryProvider);
    final registros = repo.registros;

    return ResponsiveScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Auditoría', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Actividad reciente del área administrativa: aprobaciones, '
            'ediciones y cambios de cuenta.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            EstadoVacio(icono: Icons.error_outline, mensaje: _error!)
          else if (registros.isEmpty)
            const EstadoVacio(
              icono: Icons.history_outlined,
              mensaje: 'Aún no hay actividad registrada.',
            )
          else ...[
            GroupedSection(
              header: 'Actividad reciente',
              children: [
                for (final r in registros) _RegistroRow(registro: r),
              ],
            ),
            const SizedBox(height: 16),
            if (!repo.sinMasRegistros)
              Align(
                alignment: Alignment.center,
                child: OutlinedButton(
                  onPressed: _cargandoMas ? null : _cargarMas,
                  child: _cargandoMas
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cargar más'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RegistroRow extends StatelessWidget {
  const _RegistroRow({required this.registro});

  final RegistroAuditoria registro;

  IconData get _icono {
    switch (registro.entidad) {
      case 'solicitud':
        return Icons.assignment_outlined;
      case 'vehiculo':
        return Icons.local_shipping_outlined;
      case 'incidencia':
        return Icons.build_outlined;
      case 'usuario':
        return Icons.person_outline;
      default:
        return Icons.history_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GroupedRow(
      titulo: '${registro.usuarioNombre} ${registro.accion} $_entidadLegible',
      subtitulo: registro.detalle,
      icono: _icono,
      iconoColor: AppSectionColors.auditoria,
      trailing: Text(
        formatearFechaCorta(registro.creadoEn),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
      ),
    );
  }

  String get _entidadLegible {
    switch (registro.entidad) {
      case 'solicitud':
        return 'una solicitud';
      case 'vehiculo':
        return 'un vehículo';
      case 'incidencia':
        return 'una incidencia';
      case 'usuario':
        return 'un usuario';
      default:
        return registro.entidad;
    }
  }
}
