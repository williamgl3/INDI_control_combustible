import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/estadistica_carga_provider.dart';
import '../../core/providers.dart';
import '../../models/estadistica_carga_dia.dart';
import '../../router/route_paths.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chofer_operation_scaffold.dart';
import '../../widgets/estado_vacio.dart';
import '../../models/carga.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/stat_tile_row.dart';

/// Pantalla de estadísticas de carga del día actual — muestra resumen de
/// litros cargados, rendimiento (km/L), historial de cada carga y estado
/// del día. Solo lectura, sin edición.
class EstadisticasCargaScreen extends ConsumerWidget {
  const EstadisticasCargaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(estadisticaCargaHoyProvider);
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);

    final vehiculo = stats.vehiculoId.isNotEmpty
        ? vehiculosRepo.porId(stats.vehiculoId)
        : null;

    return ChoferOperationScaffold(
      titulo: 'Estadísticas de carga',
      child: stats.isEmpty
          ? _EstadoVacio(
              onSolicitar: () => context.push(RoutePaths.choferTipoOperacion),
            )
          : _Contenido(
              stats: stats,
              etiquetaVehiculo: vehiculo != null
                  ? '${vehiculo.etiquetaUnidad} · ${vehiculo.modelo ?? vehiculo.tipoUnidad}'
                  : null,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estado vacío
// ---------------------------------------------------------------------------

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.onSolicitar});

  final VoidCallback onSolicitar;

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.local_gas_station_outlined,
      mensaje: 'Aún no has registrado ninguna carga hoy.',
      textoAccion: 'Registrar carga',
      onAccion: onSolicitar,
    );
  }
}

// ---------------------------------------------------------------------------
// Contenido principal
// ---------------------------------------------------------------------------

class _Contenido extends StatelessWidget {
  const _Contenido({required this.stats, this.etiquetaVehiculo});

  final EstadisticaCargaDia stats;
  final String? etiquetaVehiculo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header con vehículo y fecha
        if (etiquetaVehiculo != null) ...[
          _HeaderVehiculo(etiqueta: etiquetaVehiculo!, fecha: stats.fecha),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Tarjetas de métricas
        StatTileRow(
          tiles: [
            StatTile(
              icono: Icons.local_gas_station_rounded,
              valor: '${stats.totalCargas}',
              etiqueta: 'Carga${stats.totalCargas == 1 ? '' : 's'}',
            ),
            StatTile(
              icono: Icons.water_drop_outlined,
              valor: _formatearLitros(stats.litrosTotales),
              etiqueta: 'Litros totales',
            ),
            if (stats.kmRecorridos != null)
              StatTile(
                icono: Icons.speed_rounded,
                valor: _formatearKm(stats.kmRecorridos!),
                etiqueta: 'Km recorridos',
              ),
            if (stats.rendimiento != null)
              StatTile(
                icono: Icons.show_chart_rounded,
                valor: stats.rendimiento!.toStringAsFixed(1),
                etiqueta: 'km/L',
                color: stats.esAnomalo
                    ? Theme.of(context).colorScheme.error
                    : null,
                destacado: stats.esAnomalo,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Historial de cargas
        Text(
          'Detalle de cargas',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final carga in stats.cargas) ...[
          _CargaTile(carga: carga),
          if (carga != stats.cargas.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header de vehículo + fecha
// ---------------------------------------------------------------------------

class _HeaderVehiculo extends StatelessWidget {
  const _HeaderVehiculo({required this.etiqueta, required this.fecha});

  final String etiqueta;
  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(Icons.directions_car_rounded, size: 18, color: colors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            etiqueta,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          _fechaCorta(fecha),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tile de cada carga individual
// ---------------------------------------------------------------------------

class _CargaTile extends StatelessWidget {
  const _CargaTile({required this.carga});

  final Carga carga;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.local_gas_station_rounded,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatearLitros(carga.litrosCargados),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '· ${carga.kmAlCargar.toStringAsFixed(0)} km',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  carga.gasolinera,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _horaCorta(carga.creadaEn),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers de formato
// ---------------------------------------------------------------------------

String _formatearLitros(double litros) {
  if (litros == litros.roundToDouble()) return '${litros.toInt()} L';
  return '${litros.toStringAsFixed(1)} L';
}

String _formatearKm(double km) {
  if (km == km.roundToDouble()) return '${km.toInt()} km';
  return '${km.toStringAsFixed(1)} km';
}

String _fechaCorta(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  return '$d/$m/${fecha.year}';
}

String _horaCorta(DateTime fecha) {
  final h = fecha.hour.toString().padLeft(2, '0');
  final min = fecha.minute.toString().padLeft(2, '0');
  return '$h:$min';
}
