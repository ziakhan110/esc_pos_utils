import 'dart:convert';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_utils/src/extensions.dart';

import 'commands.dart';

class TextGenerator extends Generator {
  PosStyles globalStyles =
      PosStyles(fontType: PosFontType.fontA, align: PosAlign.center);

  TextGenerator(
    super._paperSize,
    super._profile, {
    super.spaceBetweenRows = 5,
    super.chineseEnabled = false,
    this.globalStyles = const PosStyles(fontType: PosFontType.fontA),
  }) : super();

  @override
  List<int> text(
    String text, {
    PosStyles? styles,
    int linesAfter = 0,
  }) {
    List<int> bytes = [];
    bytes += setStyles(styles ?? globalStyles);

    bytes += latin1.encode(text);

    bytes += emptyLines(linesAfter + 1);
    return bytes;
  }

  List<int> row(List<PosColumn> cols, {String? charset}) {
  final isSumValid = cols.fold(0, (int sum, col) => sum + col.width) == 12;

  if (!isSumValid) {
    throw Exception('Total columns width must be equal to 12');
  }

  List<int> bytes = [];
  bool shouldPrintNewLine = false;
  List<PosColumn> newCols = [];

  int lineCharacters = getMaxCharsPerLine();

  for (var i = 0; i < cols.length; i++) {
    var col = cols[i];
    bytes += cAlignCenter;

    int colWidth = (lineCharacters * col.width / 12).floor();

    // Subtract spaceBetweenRows width from all columns except the last one
    if (spaceBetweenRows > 0 && i < cols.length - 1) {
      colWidth -= spaceBetweenRows;
    }

    bytes += setStyles(col.styles);

    final text = _setTextPadding(
      col.text.trimToWidth(colWidth),
      col.styles.align,
      colWidth,
    );

    if (col.text.length > colWidth) {
      shouldPrintNewLine = true;
      newCols.add(PosColumn(
        text: col.text.substring(colWidth),
        width: col.width,
        styles: col.styles,
      ));
    } else {
      newCols.add(PosColumn(
        text: " ",
        styles: col.styles,
        width: col.width,
      ));
    }

    if (charset != null) {
      bytes += Encoding.getByName(charset)?.encode(text) ?? [];
    } else {
      bytes += encode(text);
    }

    // Add spaces between columns
    if (spaceBetweenRows > 0 && i < cols.length - 1) {
      bytes += encode(' ' * spaceBetweenRows);
    }
  }

  bytes += emptyLines(1);
  if (shouldPrintNewLine) {
    bytes += row(newCols, charset: charset);
  }
  return bytes;
}

  String _setTextPadding(String text, PosAlign align, int width) {
    switch (align) {
      case PosAlign.left:
        return text.padRight(width);
      case PosAlign.center:
        return text.center(width);
      case PosAlign.right:
        return text.padLeft(width);
    }
  }

}
