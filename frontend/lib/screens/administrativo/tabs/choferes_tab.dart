import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../models/perfil.dart';
import '../../../router/route_paths.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/responsive_scroll_view.dart';
import '../../../widgets/stat_tile.dart';

/// Pestaña "Choferes": directorio de choferes registrados, cada uno con
/// acceso a su historial completo (solicitudes + cargas).
class ChoferesTab extends ConsumerStatefulWidget {
  const ChoferesTab({super.key});

  @override
  ConsumerState<ChoferesTab> createState() => _ChoferesTabState();
}

class _ChoferesTabState extends ConsumerState<ChoferesTab> {
  Future<void> _verDetalle(Perfil chofer) async {
    await context.push(RoutePaths.administrativoChoferDetalle, extra: chofer);
    if (mounted) setState(() {}); // por si se editó el tope desde el detalle
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final choferes = ref.watch(authRepositoryProvider).listarChoferes();
    ref.watch(operacionesTickProvider);

    return ResponsiveScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choferes', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Directorio de choferes registrados en la obra.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 200,
              child: StatTile(
                icono: Icons.groups_outlined,
                valor: '${choferes.length}',
                etiqueta: 'Choferes',
                color: AppSectionColors.choferes,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (choferes.isEmpty)
            const EstadoVacio(
              icono: Icons.groups_outlined,
              mensaje: 'Aún no hay choferes registrados.',
            )
          else
            GroupedSection(
              header: 'Directorio',
              children: [
                for (final c in choferes)
                  GroupedRow(
                    titulo: c.nombreCompleto,
                    subtitulo: '@${c.usuario}',
                    icono: Icons.person_outline,
                    iconoColor: AppSectionColors.choferes,
                    onTap: () => _verDetalle(c),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
