import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_sub_header.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/ios_segmented_control.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/stat_tile_row.dart';
import '../../router/route_paths.dart';
import '../administrativo/tabs/dashboard_calculo.dart';

/// Dashboard personal del chofer: cuánto ha consumido, cómo va su
/// rendimiento (km/L) y qué tan cerca está de su patrón habitual — la
/// misma lógica que ya usa el sistema para auto-aprobarlo o mandarlo a
/// revisión manual, pero antes invisible para el propio chofer.
class ChoferDashboardScreen extends ConsumerStatefulWidget {
  const ChoferDashboardScreen({super.key, this.mostrarComoTab = false});

  /// `true` cuando esta pantalla vive embebida como una pestaña de
  /// [ChoferHomeShell] (sin `Scaffold`/`AppBar`/botón de volver propios)
  /// en vez de empujada como ruta independiente.
  final bool mostrarComoTab;

  @override
  ConsumerState<ChoferDashboardScreen> createState() =>
      _ChoferDashboardScreenState();
}

class _ChoferDashboardScreenState extends ConsumerState<ChoferDashboardScreen> {
  PeriodoDashboard _periodo = PeriodoDashboard.semana;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final perfil = ref.watch(sessionProvider);
    if (perfil == null) return const SizedBox.shrink();

    final repo = ref.watch(operacionesRepositoryProvider);
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final ahora = DateTime.now();
    final todasMisCargas = repo.cargasDeChofer(perfil.id);
    final cargas = todasMisCargas
        .where((c) => cargaDentroDePeriodo(c.creadaEn, _periodo, ahora))
        .toList();

    final tipoCombustiblePorVehiculo = {
      for (final v in vehiculosRepo.todos) v.id: v.tipoCombustible,
    };
    final desglose = desglosarPorCombustible(
      cargas,
      tipoCombustiblePorVehiculo,
    );
    final serie = agruparLitrosPorSubperiodo(cargas, _periodo, ahora);

    final totalLitros = cargas.fold(0.0, (s, c) => s + c.litrosCargados);

    // Rendimiento (km/L) de cada carga del periodo que ya tenga su cierre
    // de día registrado — ordenado cronológicamente para la tendencia.
    final cargasOrdenadas = [...cargas]
      ..sort((a, b) => a.creadaEn.compareTo(b.creadaEn));
    final puntosRendimiento = <double>[];
    for (final carga in cargasOrdenadas) {
      final cierre = repo.cierreDe(carga);
      if (cierre == null) continue;
      final rendimiento = repo.rendimientoDe(cierre)?.rendimiento;
      if (rendimiento != null) puntosRendimiento.add(rendimiento);
    }
    final rendimientoPromedio = puntosRendimiento.isEmpty
        ? null
        : puntosRendimiento.reduce((a, b) => a + b) / puntosRendimiento.length;

    final cuerpoDashboard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroConsumo(
          totalLitros: totalLitros,
          rendimientoPromedio: rendimientoPromedio,
          colors: colors,
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
        StatTileRow(
          tiles: [
            StatTile(
              icono: Icons.local_gas_station_outlined,
              valor: totalLitros.toStringAsFixed(0),
              etiqueta: 'Litros del periodo',
              color: colors.primary,
            ),
            StatTile(
              icono: Icons.speed_outlined,
              valor: rendimientoPromedio == null
                  ? '—'
                  : rendimientoPromedio.toStringAsFixed(1),
              etiqueta: 'Rendimiento promedio',
              color: colors.success,
            ),
            StatTile(
              icono: Icons.receipt_long_outlined,
              valor: cargas.length.toString(),
              etiqueta: 'Cargas registradas',
              color: colors.info,
            ),
          ],
        ),
        const SizedBox(height: 20),
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
              if (cargas.isEmpty)
                EstadoVacio(
                  icono: Icons.bar_chart_outlined,
                  mensaje: 'Todavía no registras cargas en este periodo.',
                  textoAccion: 'Solicitar carga',
                  onAccion: () => context.push(RoutePaths.choferTipoOperacion),
                )
              else ...[
                if (serie.isNotEmpty) ...[
                  _TarjetaBarras(serie: serie),
                  const SizedBox(height: 16),
                ],
                if (puntosRendimiento.length >= 2) ...[
                  _TarjetaRendimiento(puntos: puntosRendimiento),
                  const SizedBox(height: 16),
                ],
                if (desglose.isNotEmpty) _TarjetaDona(desglose: desglose),
              ],
            ],
          ),
        ),
      ],
    );

    final encabezado = BrandSubHeader(
      titulo: 'Mi consumo',
      onBack: widget.mostrarComoTab ? null : () => context.pop(),
    );

    if (widget.mostrarComoTab) {
      return SafeArea(
        child: ContenidoResponsivo(
          paddingSuperior: 0,
          paddingInferior: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              encabezado,
              Padding(
                padding: const EdgeInsets.all(20),
                child: cuerpoDashboard,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          encabezado,
          Expanded(
            child: SafeArea(
              top: false,
              child: ContenidoResponsivo(child: cuerpoDashboard),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroConsumo extends StatelessWidget {
  const _HeroConsumo({
    required this.totalLitros,
    required this.rendimientoPromedio,
    required this.colors,
  });

  final double totalLitros;
  final double? rendimientoPromedio;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryHover],
        ),
        borderRadius: AppRadii.cardRadius,
        // Variante intencional de `AppShadows.floating`, no un olvido: es
        // un glow de marca (color primary, no negro) sobre el degradado
        // de la propia tarjeta, no una sombra neutra — migrarla al token
        // le quitaría el efecto.
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LITROS CONSUMIDOS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  totalLitros.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Selecciona un periodo para comparar tu consumo, rendimiento y cargas registradas.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_gas_station_rounded,
            color: Colors.white.withValues(alpha: 0.25),
            size: 64,
          ),
        ],
      ),
    );
  }
}

class _TarjetaBarras extends StatelessWidget {
  const _TarjetaBarras({required this.serie});

  final List<SegmentoLitros> serie;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxLitros = serie
        .map((s) => s.litros)
        .fold(0.0, (a, b) => a > b ? a : b);
    final techo = maxLitros <= 0 ? 10.0 : maxLitros * 1.2;

    return AppCard(
      floating: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
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
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.textPrimary,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)} L',
                      TextStyle(
                        color: colors.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
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
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              colors.primary.withValues(alpha: 0.55),
                              colors.primary,
                            ],
                          ),
                          width: 16,
                          borderRadius: BorderRadius.circular(6),
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

class _TarjetaRendimiento extends StatelessWidget {
  const _TarjetaRendimiento({required this.puntos});

  final List<double> puntos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxY = puntos.fold(0.0, (a, b) => a > b ? a : b) * 1.2;
    final minY = (puntos.fold(puntos.first, (a, b) => a < b ? a : b) * 0.8)
        .clamp(0, double.infinity);

    return AppCard(
      floating: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rendimiento (km/L)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Por cada carga con día ya cerrado, en orden.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: minY.toDouble(),
                maxY: maxY <= 0 ? 10 : maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => colors.textPrimary,
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '${s.y.toStringAsFixed(1)} km/L',
                            TextStyle(
                              color: colors.surface,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < puntos.length; i++)
                        FlSpot(i.toDouble(), puntos[i]),
                    ],
                    isCurved: true,
                    color: colors.success,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors.success.withValues(alpha: 0.12),
                    ),
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

class _TarjetaDona extends StatelessWidget {
  const _TarjetaDona({required this.desglose});

  final List<DesgloseCombustible> desglose;

  static const _colores = [
    Color(0xFF0165F9),
    Color(0xFF4C7EE0),
    Color(0xFF146C3C),
    Color(0xFF92610C),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      floating: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Combustible por tipo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: [
                      for (var i = 0; i < desglose.length; i++)
                        PieChartSectionData(
                          value: desglose[i].litros,
                          color: _colores[i % _colores.length],
                          radius: 28,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < desglose.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colores[i % _colores.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                desglose[i].tipo,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              '${desglose[i].porcentaje.toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
