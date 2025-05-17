import 'dart:convert';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_utils/src/extensions.dart';

import 'commands.dart';

class TextGenerator extends Generator {
  PosStyles globalStyles =
      PosStyles(fontType: PosFontType.fontA, align: PosAlign.center);
  final PaperSize _paperSize;
  PosFontType? _font;
  int maxCharsPerLine = 0;

  TextGenerator(
    this._paperSize,
    CapabilityProfile _profile, {
    super.chineseEnabled = false,
    this.globalStyles = const PosStyles(fontType: PosFontType.fontA),
  }) : super(_paperSize, _profile);

  @override
  List<int> text(
    String text, {
    PosStyles? styles,
    int linesAfter = 0,
  }) {
    List<int> bytes = [];
    bytes += _setStyle(styles ?? globalStyles);
    bytes += _setAlign(styles?.align ?? globalStyles.align);

    bytes += _setFont();
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
    for (var col in cols) {
      bytes += cAlignCenter.codeUnits;

      int lineCharacters = _charsPerLine();

      int colWidth = (lineCharacters * col.width / 12).floor();

      bytes += _setStyle(col.styles);
      final text = _setTextAlign(
          col.text.trimToWidth(colWidth), col.styles.align, colWidth);
      if (col.text.length > colWidth) {
        shouldPrintNewLine = true;
        newCols.add(PosColumn(
          text: col.text.substring(
            colWidth,
            col.text.length,
          ),
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
        bytes += _setFont();
        bytes += Encoding.getByName(charset)?.encode(text) ?? [];
      } else {
        bytes += encode(text);
      }
    }
    bytes += emptyLines(1);
    if (shouldPrintNewLine) {
      bytes += row(newCols, charset: charset);
    }
    return bytes;
  }

  @override
  List<int> hr({
    String ch = '-',
    int? len,
    int linesAfter = 0,
    PosStyles? styles,
  }) {
    List<int> bytes = [];
    int lineCharacters = _charsPerLine();
    String ch1 = ch.length == 1 ? ch : ch[0];
    bytes +=
        text(List.filled(lineCharacters, ch1).join(), linesAfter: linesAfter);
    bytes += _setStyle(styles ?? globalStyles);
    return bytes;
  }

  List<int> _setFont() {
    if (this._font == PosFontType.fontA) {
      return cFontA.codeUnits;
    } else {
      return cFontB.codeUnits;
    }
  }

  List<int> _setStyle(PosStyles style) {
    List<int> bytes = [];
    if (style.bold) {
      bytes += cBoldOn.codeUnits;
    } else {
      bytes += cBoldOff.codeUnits;
    }
    return bytes += List.from(cSizeGSn.codeUnits)
      ..add(16 * (style.width.value - 1) + (style.height.value - 1));
  }

  String _setTextAlign(String text, PosAlign align, int width) {
    switch (align) {
      case PosAlign.left:
        return text.padRight(width);
      case PosAlign.center:
        return text.center(width);
      case PosAlign.right:
        return text.padLeft(width);
    }
  }

  List<int> _setAlign(PosAlign align) {
    switch (align) {
      case PosAlign.left:
        return cAlignLeft.codeUnits;
      case PosAlign.center:
        return cAlignCenter.codeUnits;
      case PosAlign.right:
        return cAlignRight.codeUnits;
    }
  }

  setMaxCharsPerLine(int chars) {
    this.maxCharsPerLine = chars;
  }

  int _charsPerLine([PosFontType? font]) {
    if (font != null)
      return (font == PosFontType.fontA)
          ? this._paperSize.fontACharsPerLine
          : this._paperSize.fontBCharsPerLine;
    return (globalStyles.fontType == PosFontType.fontA)
        ? this._paperSize.fontACharsPerLine
        : this._paperSize.fontBCharsPerLine;
  }
}
