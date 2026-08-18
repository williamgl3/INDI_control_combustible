import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/xlsx_document.dart';

void main() {
  test('genera un XLSX válido con tipos, filtro y encabezado congelado', () {
    final bytes = construirXlsx(
      nombreHoja: 'Reporte',
      encabezados: const ['Fecha', 'Litros', 'Responsable'],
      anchos: const [20, 12, 28],
      filas: [
        [
          XlsxCell.dateTime(DateTime(2026, 8, 18, 10, 30)),
          const XlsxCell.number(125.5, style: XlsxCellStyle.oneDecimal),
          const XlsxCell.text('José & Asociados'),
        ],
      ],
    );

    expect(bytes.take(2), [0x50, 0x4b]);
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    expect(archive.findFile('xl/workbook.xml'), isNotNull);
    expect(archive.findFile('xl/styles.xml'), isNotNull);

    final sheet = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content,
    );
    expect(sheet, contains('state="frozen"'));
    expect(sheet, contains('<autoFilter ref="A1:C2"/>'));
    expect(sheet, contains('José &amp; Asociados'));
    expect(sheet, contains('<c r="B2" s="4"><v>125.5</v></c>'));
    expect(sheet, isNot(contains('<f>')));
  });

  test('texto que parece fórmula permanece como cadena literal', () {
    final bytes = construirXlsx(
      nombreHoja: 'Seguro',
      encabezados: const ['Dato'],
      filas: const [
        [XlsxCell.text('=HYPERLINK("https://example.com")')],
      ],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final sheet = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content,
    );
    expect(sheet, contains('t="inlineStr"'));
    expect(sheet, contains('=HYPERLINK(&quot;https://example.com&quot;)'));
    expect(sheet, isNot(contains('<f>')));
  });

  test('rechaza filas con una cantidad de columnas incompatible', () {
    expect(
      () => construirXlsx(
        nombreHoja: 'Inválido',
        encabezados: const ['A', 'B'],
        filas: const [
          [XlsxCell.text('solo una')],
        ],
      ),
      throwsArgumentError,
    );
  });
}
