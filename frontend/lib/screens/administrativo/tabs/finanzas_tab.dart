import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/precio_combustible.dart';
import '../../../models/solicitud_autorizacion.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/barra_presupuesto.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/responsive_scroll_view.dart';
import '../../../widgets/stat_tile.dart';
import '../../../widgets/stat_tile_row.dart';
import '../editar_precio_dialog.dart';

/// Pestaña "Finanzas": presupuesto semanal y precios de combustible
/// vigentes (editables).
class FinanzasTab extends ConsumerStatefulWidget {
  const FinanzasTab({super.key});

  @override
  ConsumerState<FinanzasTab> createState() => _FinanzasTabState();
}

class _FinanzasTabState extends ConsumerState<FinanzasTab> {
  Future<void> _editarPrecio(PrecioCombustible precio) async {
    final guardado = await EditarPrecioDialog.show(context, precio);
    if (guardado == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final aprobadas = repo.todasLasSolicitudes.where(
      (s) => s.estado == EstadoSolicitud.aprobada,
    );
    final litrosAutorizados = aprobadas.fold(
      0.0,
      (suma, s) => suma + (s.litrosAutorizados ?? s.litrosSolicitados),
    );

    return ResponsiveScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Finanzas', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Presupuesto semanal y precios de combustible vigentes.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          BarraPresupuesto(
            restante: repo.presupuestoRestante,
            total: repo.presupuestoSemanalTotal,
            etiquetaSemana: repo.etiquetaSemanaActual,
          ),
          const SizedBox(height: 12),
          StatTileRow(
            tiles: [
              StatTile(
                icono: Icons.local_gas_station_outlined,
                valor: litrosAutorizados.toStringAsFixed(0),
                etiqueta: 'L autorizados',
                color: AppSectionColors.autorizaciones,
              ),
              StatTile(
                icono: Icons.payments_outlined,
                valor: '\$${repo.presupuestoEjercido.toStringAsFixed(0)}',
                etiqueta: 'Ejercido esta semana',
                color: AppSectionColors.finanzas,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Precios de combustible',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          GroupedSection(
            children: [
              for (final p in repo.precios)
                GroupedRow(
                  titulo: p.tipoCombustible,
                  icono: Icons.local_gas_station_outlined,
                  iconoColor: AppSectionColors.finanzas,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${p.precioPorLitro.toStringAsFixed(2)} / L',
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: colors.primary),
                      ),
                      IconButton(
                        tooltip: 'Editar precio',
                        onPressed: () => _editarPrecio(p),
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colors.textSecondary,
                          size: 20,
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
