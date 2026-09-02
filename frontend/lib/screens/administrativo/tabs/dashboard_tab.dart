import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/app_breakpoints.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/formato_numero.dart';
import '../../../widgets/ios_segmented_control.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/stat_tile.dart';
import '../../../widgets/stat_tile_row.dart';
import 'dashboard_calculo.dart';

/// Pestaña "Dashboard": porcentajes y tendencia de consumo de combustible,
/// filtrable por día/semana/mes/año — vista rápida para el área
/// administrativa sin tener que ir al detalle del Concentrado.
class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  PeriodoDashboard _periodo = PeriodoDashboard.semana;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final esMovil = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final repo = ref.watch(operacionesRepositoryProvider);
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final ahora = DateTime.now();
    final cargas = repo.todasLasCargas
        .where((c) => cargaDentroDePeriodo(c.creadaEn, _periodo, ahora))
        .toList();

    final tipoCombustiblePorVehiculo = {
      for (final v in vehiculosRepo.todos) v.id: v.tipoCombustible,
    };

    final totalLitros = cargas.fold(0.0, (s, c) => s + c.litrosCargados);
    final totalImporte = cargas.fold(0.0, (s, c) {
      final vehiculo = vehiculosRepo.porId(c.vehiculoId);
      final precio = vehiculo == null
          ? 0.0
          : repo.precios
                .firstWhere(
                  (p) => p.tipoCombustible == vehiculo.tipoCombustible,
                  orElse: () => repo.precios.first,
                )
                .precioPorLitro;
      return s + c.litrosCargados * precio;
    });

    final desglose = desglosarPorCombustible(
      cargas,
      tipoCombustiblePorVehiculo,
    );
    final serie = agruparLitrosPorSubperiodo(cargas, _periodo, ahora);

    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dashboard administrativo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Resumen de consumo, importe y tendencia por periodo.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (esMovil)
            _MetricasMoviles(
              tiles: [
                StatTile(
                  compacta: true,
                  icono: Icons.local_gas_station_outlined,
                  valor: totalLitros.toStringAsFixed(0),
                  etiqueta: 'Litros cargados',
                  color: AppSectionColors.autorizaciones,
                ),
                StatTile(
                  compacta: true,
                  icono: Icons.payments_outlined,
                  valor: formatearMoneda(totalImporte),
                  etiqueta: 'Importe',
                  color: AppSectionColors.finanzas,
                ),
                StatTile(
                  compacta: true,
                  icono: Icons.receipt_long_outlined,
                  valor: cargas.length.toString(),
                  etiqueta: 'Cargas',
                  color: AppSectionColors.dashboard,
                ),
              ],
            )
          else
            StatTileRow(
              tiles: [
                StatTile(
                  icono: Icons.local_gas_station_outlined,
                  valor: totalLitros.toStringAsFixed(0),
                  etiqueta: 'Litros cargados',
                  color: AppSectionColors.autorizaciones,
                ),
                StatTile(
                  icono: Icons.payments_outlined,
                  valor: formatearMoneda(totalImporte),
                  etiqueta: 'Importe',
                  color: AppSectionColors.finanzas,
                ),
                StatTile(
                  icono: Icons.receipt_long_outlined,
                  valor: cargas.length.toString(),
                  etiqueta: 'Cargas',
                  color: AppSectionColors.dashboard,
                ),
              ],
            ),
          const SizedBox(height: 20),
          IosSegmentedControl<PeriodoDashboard>(
            valor: _periodo,
            opciones: const {
              PeriodoDashboard.dia: 'Día',
              PeriodoDashboard.semana: 'Semana',
              PeriodoDashboard.mes: 'Mes',
              PeriodoDashboard.anio: 'Año',
            },
            onChanged: (p) => setState(() => _periodo = p),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: colors.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  etiquetaPeriodoDashboard(_periodo, ahora),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Column(
              key: ValueKey(_periodo),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cargas.isEmpty && esMovil)
                  const AppCard(
                    child: EstadoVacio(
                      icono: Icons.bar_chart_outlined,
                      mensaje: 'Sin datos para este período',
                    ),
                  )
                else if (cargas.isEmpty)
                  // Le da presencia vertical real al estado vacío en vez
                  // de dejarlo compacto pegado arriba con un vacío
                  // grande debajo — mismo criterio que en
                  // `concentrado_tab.dart`.
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.4,
                    child: const Center(
                      child: EstadoVacio(
                        icono: Icons.bar_chart_outlined,
                        mensaje: 'No hay cargas registradas en este periodo.',
                      ),
                    ),
                  )
                else ...[
                  _TarjetaDesglose(desglose: desglose),
                  if (serie.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _TarjetaTendencia(serie: serie),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricasMoviles extends StatelessWidget {
  const _MetricasMoviles({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final half = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          key: const ValueKey('dashboard-mobile-metrics'),
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              key: const ValueKey('dashboard-mobile-metric-0'),
              width: half,
              child: tiles[0],
            ),
            SizedBox(
              key: const ValueKey('dashboard-mobile-metric-1'),
              width: half,
              child: tiles[1],
            ),
            SizedBox(
              key: const ValueKey('dashboard-mobile-metric-2'),
              width: constraints.maxWidth,
              child: tiles[2],
            ),
          ],
        );
      },
    );
  }
}

class _TarjetaDesglose extends StatelessWidget {
  const _TarjetaDesglose({required this.desglose});

  final List<DesgloseCombustible> desglose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colores = [
      colors.primary,
      colors.primary.withValues(alpha: 0.68),
      const Color(0xFF146C3C),
      const Color(0xFF92610C),
    ];
    final apilado = MediaQuery.sizeOf(context).width < 380;
    final leyenda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < desglose.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colores[i % colores.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    desglose[i].tipo,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${desglose[i].porcentaje.toStringAsFixed(0)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: context.shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Combustible por tipo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Flex(
            direction: apilado ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: [
                      for (var i = 0; i < desglose.length; i++)
                        PieChartSectionData(
                          value: desglose[i].litros,
                          color: colores[i % colores.length],
                          radius: 32,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: apilado ? 0 : 20,
                height: apilado ? AppSpacing.lg : 0,
              ),
              if (apilado) leyenda else Expanded(child: leyenda),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaTendencia extends StatelessWidget {
  const _TarjetaTendencia({required this.serie});

  final List<SegmentoLitros> serie;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxLitros = serie
        .map((s) => s.litros)
        .fold(0.0, (a, b) => a > b ? a : b);
    final techo = maxLitros <= 0 ? 10.0 : maxLitros * 1.2;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: context.shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Litros por sub-periodo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: techo,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= serie.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            serie[i].etiqueta,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < serie.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: serie[i].litros,
                          color: colors.primary,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
