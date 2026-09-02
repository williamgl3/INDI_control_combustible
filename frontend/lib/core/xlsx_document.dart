import 'dart:typed_data';

import 'package:archive/archive.dart';

enum XlsxCellStyle {
  normal,
  header,
  dateTime,
  decimal,
  oneDecimal,
  currency,
  total,
}

class XlsxCell {
  const XlsxCell.text(this.value, {this.style = XlsxCellStyle.normal});
  const XlsxCell.number(num? this.value, {this.style = XlsxCellStyle.decimal});
  const XlsxCell.dateTime(DateTime this.value) : style = XlsxCellStyle.dateTime;

  final Object? value;
  final XlsxCellStyle style;
}

/// Construye un libro Office Open XML tabular, sin fórmulas provenientes de
/// datos capturados por usuarios. Incluye tipos numéricos, fechas, autofiltro
/// y encabezado congelado.
Uint8List construirXlsx({
  required String nombreHoja,
  required List<String> encabezados,
  required List<List<XlsxCell>> filas,
  List<double>? anchos,
}) {
  if (encabezados.isEmpty) {
    throw ArgumentError.value(
      encabezados,
      'encabezados',
      'No puede estar vacío.',
    );
  }
  if (filas.any((fila) => fila.length != encabezados.length)) {
    throw ArgumentError(
      'Todas las filas deben tener ${encabezados.length} celdas.',
    );
  }

  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
    ..addFile(ArchiveFile.string('_rels/.rels', _rootRelationships))
    ..addFile(ArchiveFile.string('xl/workbook.xml', _workbook(nombreHoja)))
    ..addFile(
      ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRelationships),
    )
    ..addFile(ArchiveFile.string('xl/styles.xml', _styles))
    ..addFile(
      ArchiveFile.string(
        'xl/worksheets/sheet1.xml',
        _worksheet(encabezados, filas, anchos),
      ),
    );
  return ZipEncoder().encodeBytes(archive);
}

String _worksheet(
  List<String> encabezados,
  List<List<XlsxCell>> filas,
  List<double>? anchos,
) {
  final totalFilas = filas.length + 1;
  final ultimaColumna = _nombreColumna(encabezados.length);
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    )
    ..write(
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" '
      'topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>',
    )
    ..write('<sheetFormatPr defaultRowHeight="18"/>');
  if (anchos != null && anchos.length == encabezados.length) {
    buffer.write('<cols>');
    for (var i = 0; i < anchos.length; i++) {
      buffer.write(
        '<col min="${i + 1}" max="${i + 1}" width="${anchos[i]}" '
        'customWidth="1"/>',
      );
    }
    buffer.write('</cols>');
  }
  buffer
    ..write('<sheetData>')
    ..write('<row r="1" ht="24" customHeight="1">');
  for (var i = 0; i < encabezados.length; i++) {
    buffer.write(
      _celdaXml(
        i + 1,
        1,
        XlsxCell.text(encabezados[i], style: XlsxCellStyle.header),
      ),
    );
  }
  buffer.write('</row>');
  for (var rowIndex = 0; rowIndex < filas.length; rowIndex++) {
    final excelRow = rowIndex + 2;
    buffer.write('<row r="$excelRow">');
    for (
      var columnIndex = 0;
      columnIndex < filas[rowIndex].length;
      columnIndex++
    ) {
      buffer.write(
        _celdaXml(columnIndex + 1, excelRow, filas[rowIndex][columnIndex]),
      );
    }
    buffer.write('</row>');
  }
  buffer
    ..write('</sheetData>')
    ..write('<autoFilter ref="A1:$ultimaColumna$totalFilas"/>')
    ..write('</worksheet>');
  return buffer.toString();
}

String _celdaXml(int columna, int fila, XlsxCell celda) {
  final referencia = '${_nombreColumna(columna)}$fila';
  final style = celda.style.index;
  final valor = celda.value;
  if (valor == null) return '<c r="$referencia" s="$style"/>';
  if (valor is DateTime) {
    final local = valor.toLocal();
    final sinZona = DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
    );
    final serial =
        sinZona.difference(DateTime(1899, 12, 30)).inMilliseconds /
        Duration.millisecondsPerDay;
    return '<c r="$referencia" s="$style"><v>$serial</v></c>';
  }
  if (valor is num) {
    if (!valor.isFinite) return '<c r="$referencia" s="$style"/>';
    return '<c r="$referencia" s="$style"><v>$valor</v></c>';
  }
  final texto = _escapeXml(valor.toString());
  return '<c r="$referencia" s="$style" t="inlineStr">'
      '<is><t xml:space="preserve">$texto</t></is></c>';
}

String _nombreColumna(int indice) {
  var actual = indice;
  final caracteres = <int>[];
  while (actual > 0) {
    actual--;
    caracteres.add(65 + (actual % 26));
    actual ~/= 26;
  }
  return String.fromCharCodes(caracteres.reversed);
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _workbook(String nombreHoja) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="${_escapeXml(nombreHoja)}" sheetId="1" '
    'r:id="rId1"/></sheets></workbook>';

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _rootRelationships =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

const _workbookRelationships =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<numFmts count="4"><numFmt numFmtId="164" formatCode="dd/mm/yyyy hh:mm"/>'
    '<numFmt numFmtId="165" formatCode="0.00"/>'
    '<numFmt numFmtId="166" formatCode="0.0"/>'
    '<numFmt numFmtId="167" formatCode="[\$\$-es-MX]#,##0.00"/></numFmts>'
    '<fonts count="3"><font><sz val="11"/><name val="Aptos"/></font>'
    '<font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Aptos"/></font>'
    '<font><b/><sz val="11"/><name val="Aptos"/></font></fonts>'
    '<fills count="3"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FF1463FF"/>'
    '<bgColor indexed="64"/></patternFill></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="7"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="167" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';
