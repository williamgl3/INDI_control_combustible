import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_logger.dart';
import '../../../core/providers.dart';
import '../../../models/registro_auditoria.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/chip_filtro.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/fecha_formato.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/skeleton_loader.dart';

/// Traduce la clave de acción del backend (snake_case, ej. `'editar_carga'`)
/// a un verbo conjugado para el título de la fila. Los datos de ejemplo
/// (mocks) ya mandan el verbo directo (ej. `'aprobó'`), así que caen en el
/// `default` y se muestran tal cual, sin cambios.
String _accionLegible(String accion) {
  switch (accion) {
    case 'aprobar_solicitud':
      return 'aprobó';
    case 'rechazar_solicitud':
      return 'rechazó';
    case 'editar_carga':
      return 'editó';
    case 'editar_precio':
      return 'editó el precio de';
    case 'editar_presupuesto_semanal':
      return 'editó';
    case 'editar_vehiculo':
      return 'editó';
    case 'registrar_servicio_mantenimiento':
      return 'registró servicio de';
    case 'resolver_incidencia':
      return 'resolvió';
    case 'activar_usuario':
      return 'activó';
    case 'desactivar_usuario':
      return 'desactivó';
    case 'resetear_password_usuario':
      return 'reseteó la contraseña de';
    case 'crear_administrativo':
      return 'creó';
    default:
      return accion;
  }
}

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
  String? _filtroEntidad;

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

  // Estos son los valores REALES que manda el backend (`entidad:` en cada
  // `registrarAuditoria(...)` de src/services/*.ts) — antes decía
  // 'solicitud'/'incidencia', que nunca coincidía con lo que en realidad
  // llega ('solicitud_autorizacion'/'incidencia_vehiculo'), así que estos
  // dos filtros nunca mostraban nada contra el backend real.
  static const _entidadesFiltrables = [
    'solicitud_autorizacion',
    'carga',
    'precio_combustible',
    'configuracion',
    'vehiculo',
    'incidencia_vehiculo',
    'usuario',
  ];

  String _etiquetaEntidad(String entidad) {
    switch (entidad) {
      case 'solicitud_autorizacion':
        return 'Solicitudes';
      case 'carga':
        return 'Cargas';
      case 'precio_combustible':
        return 'Precios';
      case 'configuracion':
        return 'Presupuesto';
      case 'vehiculo':
        return 'Vehículos';
      case 'incidencia_vehiculo':
        return 'Incidencias';
      case 'usuario':
        return 'Usuarios';
      default:
        return entidad;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repo = ref.watch(auditoriaRepositoryProvider);
    final registros = _filtroEntidad == null
        ? repo.registros
        : repo.registros.where((r) => r.entidad == _filtroEntidad).toList();

    return ContenidoResponsivo(
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
          if (!_cargando && _error == null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChipFiltro(
                  etiqueta: 'Todas',
                  seleccionado: _filtroEntidad == null,
                  onTap: () => setState(() => _filtroEntidad = null),
                ),
                for (final entidad in _entidadesFiltrables)
                  ChipFiltro(
                    etiqueta: _etiquetaEntidad(entidad),
                    seleccionado: _filtroEntidad == entidad,
                    onTap: () => setState(() => _filtroEntidad = entidad),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          if (_cargando)
            const SkeletonGroupedSection()
          else if (_error != null)
            EstadoVacio(icono: Icons.error_outline, mensaje: _error!)
          else if (registros.isEmpty)
            EstadoVacio(
              icono: Icons.history_outlined,
              mensaje: _filtroEntidad == null
                  ? 'Aún no hay actividad registrada.'
                  : 'No hay actividad de este tipo.',
            )
          else ...[
            GroupedSection(
              header: 'Actividad reciente',
              children: [
                for (final r in registros) _RegistroRow(registro: r),
              ],
            ),
            const SizedBox(height: 16),
            if (!repo.sinMasRegistros && _filtroEntidad == null)
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
      case 'solicitud_autorizacion':
        return Icons.assignment_outlined;
      case 'carga':
        return Icons.local_gas_station_outlined;
      case 'precio_combustible':
        return Icons.payments_outlined;
      case 'configuracion':
        return Icons.account_balance_wallet_outlined;
      case 'vehiculo':
        return Icons.local_shipping_outlined;
      case 'incidencia_vehiculo':
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
    final accion = _accionLegible(registro.accion);
    final detalle = registro.detalleLegible;
    return GroupedRow(
      titulo: '${registro.usuarioNombre} $accion $_entidadLegible',
      subtitulo: detalle.isEmpty ? null : detalle,
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
      case 'solicitud_autorizacion':
        return 'una solicitud';
      case 'carga':
        return 'una carga';
      case 'precio_combustible':
        return 'un precio';
      case 'configuracion':
        return 'el presupuesto';
      case 'vehiculo':
        return 'un vehículo';
      case 'incidencia_vehiculo':
        return 'una incidencia';
      case 'usuario':
        return 'un usuario';
      default:
        return registro.entidad;
    }
  }
}
