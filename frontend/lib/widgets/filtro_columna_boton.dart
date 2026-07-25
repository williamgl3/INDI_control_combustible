import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_dialog.dart';

/// Ícono de filtro por columna — como el de un encabezado de Excel, pero
/// resuelto con una hoja de selección con casillas + buscador en vez del
/// dropdown angosto de Excel. [seleccionados] vacío significa "sin filtro
/// (todos)" — así el ícono puede mostrar de un vistazo si esa columna
/// tiene un filtro activo.
class FiltroColumnaBoton<T> extends StatelessWidget {
  const FiltroColumnaBoton({
    super.key,
    required this.titulo,
    required this.opciones,
    required this.etiquetaDe,
    required this.seleccionados,
    required this.onCambiar,
  });

  final String titulo;
  final List<T> opciones;
  final String Function(T) etiquetaDe;

  /// Vacío = sin filtro activo (se muestran todas las filas).
  final Set<T> seleccionados;
  final ValueChanged<Set<T>> onCambiar;

  bool get _activo => seleccionados.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: _activo ? 'Filtro activo: $titulo' : 'Filtrar por $titulo',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _abrirFiltro(context),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            _activo ? Icons.filter_alt : Icons.filter_alt_outlined,
            size: 16,
            color: _activo ? colors.primary : colors.textMuted,
          ),
        ),
      ),
    );
  }

  Future<void> _abrirFiltro(BuildContext context) async {
    final resultado = await mostrarDialogoApp<Set<T>>(
      context,
      builder: (_) => _DialogoFiltroColumna<T>(
        titulo: titulo,
        opciones: opciones,
        etiquetaDe: etiquetaDe,
        seleccionadosIniciales: seleccionados,
      ),
    );
    if (resultado != null) onCambiar(resultado);
  }
}

class _DialogoFiltroColumna<T> extends StatefulWidget {
  const _DialogoFiltroColumna({
    required this.titulo,
    required this.opciones,
    required this.etiquetaDe,
    required this.seleccionadosIniciales,
  });

  final String titulo;
  final List<T> opciones;
  final String Function(T) etiquetaDe;
  final Set<T> seleccionadosIniciales;

  @override
  State<_DialogoFiltroColumna<T>> createState() =>
      _DialogoFiltroColumnaState<T>();
}

class _DialogoFiltroColumnaState<T> extends State<_DialogoFiltroColumna<T>> {
  late Set<T> _seleccionados = {...widget.seleccionadosIniciales};
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final opcionesFiltradas = _busqueda.isEmpty
        ? widget.opciones
        : widget.opciones
              .where(
                (o) => widget
                    .etiquetaDe(o)
                    .toLowerCase()
                    .contains(_busqueda.toLowerCase()),
              )
              .toList();

    return AppDialogShell(
      maxWidth: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrar por ${widget.titulo}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (widget.opciones.length > 6)
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final opcion in opcionesFiltradas)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(widget.etiquetaDe(opcion)),
                      value: _seleccionados.contains(opcion),
                      onChanged: (marcado) {
                        setState(() {
                          if (marcado ?? false) {
                            _seleccionados.add(opcion);
                          } else {
                            _seleccionados.remove(opcion);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _seleccionados = {}),
                child: const Text('Limpiar'),
              ),
              const Spacer(),
              Text(
                _seleccionados.isEmpty
                    ? 'Mostrando todos'
                    : '${_seleccionados.length} seleccionados',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_seleccionados),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
