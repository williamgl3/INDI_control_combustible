import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_borders.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import 'formato_numero.dart';

/// Celda numérica editable "en el lugar" — como una hoja de cálculo: se
/// ve como texto normal (con una pista visual sutil de que es editable),
/// al tocarla se vuelve un campo de texto, y al confirmar (Enter o quitar
/// el foco) llama [onGuardar] y vuelve a mostrarse como texto. Usada en
/// Finanzas (precio, presupuesto) y Concentrado (litros, km) — antes cada
/// edición necesitaba abrir un diálogo modal aparte.
class CeldaEditable extends StatefulWidget {
  const CeldaEditable({
    super.key,
    required this.valor,
    required this.onGuardar,
    this.prefijo = '',
    this.sufijo = '',
    this.decimales = 2,
    this.estilo,
    this.textAlign = TextAlign.start,
    this.anchoEdicion = 92,
  });

  final double valor;

  /// Se llama solo si el valor cambió y es válido. Si lanza una excepción,
  /// la celda vuelve a modo edición mostrando el error en vez de perder lo
  /// que el usuario escribió.
  final Future<void> Function(double nuevoValor) onGuardar;
  final String prefijo;
  final String sufijo;
  final int decimales;
  final TextStyle? estilo;
  final TextAlign textAlign;
  final double anchoEdicion;

  @override
  State<CeldaEditable> createState() => _CeldaEditableState();
}

class _CeldaEditableState extends State<CeldaEditable> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _editando = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editando && !_guardando) {
        _confirmar();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _empezarEdicion() {
    _controller.text = widget.valor.toStringAsFixed(widget.decimales);
    setState(() {
      _editando = true;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  Future<void> _confirmar() async {
    final parseado = double.tryParse(_controller.text.trim());
    if (parseado == null || parseado < 0) {
      setState(() => _error = 'Valor inválido');
      return;
    }
    if (parseado == widget.valor) {
      setState(() => _editando = false);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.onGuardar(parseado);
      HapticFeedback.selectionClick();
      if (mounted) {
        setState(() {
          _editando = false;
          _guardando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo guardar';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      }
    }
  }

  void _cancelar() {
    setState(() {
      _editando = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_guardando) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_editando) {
      return Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.escape): const _CancelarIntent(),
        },
        child: Actions(
          actions: {
            _CancelarIntent: CallbackAction<_CancelarIntent>(
              onInvoke: (_) => _cancelar(),
            ),
          },
          child: SizedBox(
            width: widget.anchoEdicion,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textAlign: widget.textAlign,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: widget.estilo,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                filled: true,
                fillColor: colors.surface,
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: AppRadii.inputRadius,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.inputRadius,
                  borderSide: BorderSide(
                    color: colors.primary,
                    width: AppBorders.focus,
                  ),
                ),
              ),
              onSubmitted: (_) => _confirmar(),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Editar valor',
      child: InkWell(
        borderRadius: AppRadii.inputRadius,
        onTap: _empezarEdicion,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: AppRadii.inputRadius,
            color: colors.primary.withValues(alpha: 0.05),
          ),
          child: Text(
            '${widget.prefijo}${formatearNumeroConDecimales(widget.valor, widget.decimales)}${widget.sufijo}',
            style: widget.estilo,
            textAlign: widget.textAlign,
          ),
        ),
      ),
    );
  }
}

class _CancelarIntent extends Intent {
  const _CancelarIntent();
}
