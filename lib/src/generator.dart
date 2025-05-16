/*
 * esc_pos_utils
 * Created by Andrey U.
 * 
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */
import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:image/image.dart';

import 'commands.dart';

class Generator {
  PosStyles globalStyles =
      PosStyles(fontType: PosFontType.fontA, align: PosAlign.center);

  // Ticket config
  final PaperSize _paperSize;
  CapabilityProfile _profile;

  // Global styles
  String? _codeTable;
  bool chineseEnabled = false;

  // Current styles
  int spaceBetweenRows;

  Generator(
    this._paperSize,
    this._profile, {
    this.spaceBetweenRows = 5,
    this.chineseEnabled = false,
    this.globalStyles = const PosStyles(fontType: PosFontType.fontA),
  });

  // ************************ Internal helpers ************************
  int _getMaxCharsPerLine([PosFontType? font]) {
    if (font != null)
      return (font == PosFontType.fontA)
          ? this._paperSize.fontACharsPerLine
          : this._paperSize.fontBCharsPerLine;
    return (globalStyles.fontType == PosFontType.fontA)
        ? this._paperSize.fontACharsPerLine
        : this._paperSize.fontBCharsPerLine;
  }

  double _getCharWidth([PosStyles? styles]) {
    if (styles?.fontType != null)
      return (styles?.fontType == PosFontType.fontA)
          ? this._paperSize.fontACharWidth.toDouble()
          : this._paperSize.fontBCharWidth.toDouble();
    else
      return (globalStyles.fontType == PosFontType.fontA)
          ? this._paperSize.fontACharWidth.toDouble()
          : this._paperSize.fontBCharWidth.toDouble();
  }

  double _colIndToPosition(int colInd) {
    final double width = _getMaxCharsPerLine() * _getCharWidth();
    if (colInd == 0) {
      return 0;
    } else {
      return ((width * colInd) / 12) - 1;
    }
  }

  @protected
  Uint8List encode(String text) {
    List<int> textBytes = [];

    // Check if the text contains Chinese characters
    final bool containsChinese = _containsChinese(text);

    if (containsChinese && chineseEnabled) {
      // Enable Kanji/Chinese character mode
      textBytes += cKanjiOn.codeUnits;

      // Encode with GB2312 (or GBK, which is backward-compatible)
      textBytes += gbk_bytes.encode(text);

      // Disable Kanji mode after printing
      textBytes += cKanjiOff.codeUnits;
      return Uint8List.fromList(textBytes);
    } else {
      // Filter out non-Windows1252 characters
      final filteredText = String.fromCharCodes(
        text.runes.where((int rune) => rune >= 0x00 && rune <= 0xFF),
      );
      List<int> textBytes = [];
      textBytes += cKanjiOff.codeUnits;
      textBytes += latin1.encode(filteredText);
      return Uint8List.fromList(textBytes);
    }
  }

  bool _containsChinese(String text) {
    final chineseRegex = RegExp(r'[\u4E00-\u9FFF]');
    return chineseRegex.hasMatch(text);
  }

  /// Generate multiple bytes for a number: In lower and higher parts, or more parts as needed.
  ///
  /// [value] Input number
  /// [bytesNb] The number of bytes to output (1 - 4)
  List<int> _intLowHigh(int value, int bytesNb) {
    final dynamic maxInput = 256 << (bytesNb * 8) - 1;

    if (bytesNb < 1 || bytesNb > 4) {
      throw Exception('Can only output 1-4 bytes');
    }
    if (value < 0 || value > maxInput) {
      throw Exception(
          'Number is too large. Can only output up to $maxInput in $bytesNb bytes');
    }

    final List<int> res = <int>[];
    int buf = value;
    for (int i = 0; i < bytesNb; ++i) {
      res.add(buf % 256);
      buf = buf ~/ 256;
    }
    return res;
  }

  /// Extract slices of an image as equal-sized blobs of column-format data.
  ///
  /// [image] Image to extract from
  /// [lineHeight] Printed line height in dots
  List<List<int>> _toColumnFormat(Image imgSrc, int lineHeight) {
    final Image image = Image.from(imgSrc); // make a copy

    // Determine new width: closest integer that is divisible by lineHeight
    final int widthPx = (image.width + lineHeight) - (image.width % lineHeight);
    final int heightPx = image.height;

    // Create a black bottom layer
    final biggerImage = copyResize(image,
        width: widthPx, height: heightPx, interpolation: Interpolation.linear);
    //fill(biggerImage, color: ColorRgb8(0, 0, 0));
    fill(biggerImage, color: ColorRgb8(0, 0, 0));
    // Insert source image into bigger one
    compositeImage(biggerImage, image, dstX: 0, dstY: 0);

    int left = 0;
    final List<List<int>> blobs = [];

    while (left < widthPx) {
      final Image slice = copyCrop(biggerImage,
          x: left, y: 0, width: lineHeight, height: heightPx);
      if (slice.numChannels > 2) grayscale(slice);
      final imgBinary =
          (slice.numChannels > 1) ? slice.convert(numChannels: 1) : slice;
      final bytes = imgBinary.getBytes();
      blobs.add(bytes);
      left += lineHeight;
    }

    return blobs;
  }

  /// Image rasterization
  List<int> _toRasterFormat(Image imgSrc) {
    final Image image = Image.from(imgSrc); // make a copy
    final int widthPx = image.width;
    final int heightPx = image.height;

    grayscale(image);
    invert(image);

    // R/G/B channels are same -> keep only one channel
    final List<int> oneChannelBytes = [];
    final List<int> buffer = image.getBytes(order: ChannelOrder.rgba);
    for (int i = 0; i < buffer.length; i += 4) {
      oneChannelBytes.add(buffer[i]);
    }

    // Add some empty pixels at the end of each line (to make the width divisible by 8)
    if (widthPx % 8 != 0) {
      final targetWidth = (widthPx + 8) - (widthPx % 8);
      final missingPx = targetWidth - widthPx;
      final extra = Uint8List(missingPx);
      for (int i = 0; i < heightPx; i++) {
        final pos = (i * widthPx + widthPx) + i * missingPx;
        oneChannelBytes.insertAll(pos, extra);
      }
    }

    // Pack bits into bytes
    return _packBitsIntoBytes(oneChannelBytes);
  }

  /// Merges each 8 values (bits) into one byte
  List<int> _packBitsIntoBytes(List<int> bytes) {
    const pxPerLine = 8;
    final List<int> res = <int>[];
    const threshold = 127; // set the greyscale -> b/w threshold here
    for (int i = 0; i < bytes.length; i += pxPerLine) {
      int newVal = 0;
      for (int j = 0; j < pxPerLine; j++) {
        newVal = _transformUInt32Bool(
          newVal,
          pxPerLine - j,
          bytes[i + j] > threshold,
        );
      }
      res.add(newVal ~/ 2);
    }
    return res;
  }

  /// Replaces a single bit in a 32-bit unsigned integer.
  int _transformUInt32Bool(int uInt32, int shift, bool newValue) {
    return ((0xFFFFFFFF ^ (0x1 << shift)) & uInt32) |
        ((newValue ? 1 : 0) << shift);
  }

  // ************************ (end) Internal helpers  ************************

  //**************************** Public command generators ************************
  /// Clear the buffer and reset text styles
  List<int> reset() {
    List<int> bytes = [];
    bytes += cInit.codeUnits;
    globalStyles = PosStyles();
    return bytes;
  }

  /// Set global code table which will be used instead of the default printer's code table
  /// (even after resetting)
  List<int> setGlobalCodeTable(String codeTable) {
    List<int> bytes = [];
    _codeTable = codeTable;
    bytes += Uint8List.fromList(
      List.from(cCodeTable.codeUnits)..add(_profile.getCodePageId(codeTable)),
    );
    return bytes;
  }

  /// Set global font which will be used instead of the default printer's font
  /// (even after resetting)
  void setGlobalFont(PosFontType? font) {
    globalStyles = globalStyles.copyWith(fontType: font);
  }

  List<int> _setStyles(PosStyles styles) {
    List<int> bytes = [];
    PosAlign? align;
    if (styles.align != globalStyles.align) {
      align = styles.align;
    } else {
      align = globalStyles.align;
    }
    // Set font
    PosFontType? fontType;
    if (globalStyles.fontType != null && styles.fontType == null) {
      fontType = globalStyles.fontType;
    }
    if (styles.fontType != null) {
      fontType = styles.fontType;
    }
    bytes += latin1.encode(align == PosAlign.left
        ? cAlignLeft
        : (align == PosAlign.center ? cAlignCenter : cAlignRight));
    bytes += styles.bold ? cBoldOn.codeUnits : cBoldOff.codeUnits;
    bytes += styles.turn90 ? cTurn90On.codeUnits : cTurn90Off.codeUnits;
    bytes += styles.reverse ? cReverseOn.codeUnits : cReverseOff.codeUnits;
    bytes +=
        styles.underline ? cUnderline1dot.codeUnits : cUnderlineOff.codeUnits;

    bytes +=
        fontType == PosFontType.fontA ? cFontA.codeUnits : cFontB.codeUnits;

    // Characters size
    bytes += Uint8List.fromList(
      List.from(cSizeGSn.codeUnits)
        ..add(PosTextSize.decSize(styles.height, styles.width)),
    );

    // Set local code table
    if (styles.codeTable != null) {
      bytes += Uint8List.fromList(
        List.from(cCodeTable.codeUnits)
          ..add(_profile.getCodePageId(styles.codeTable)),
      );
    } else if (_codeTable != null) {
      bytes += Uint8List.fromList(
        List.from(cCodeTable.codeUnits)
          ..add(_profile.getCodePageId(_codeTable)),
      );
    } else if (globalStyles.codeTable != null) {
      bytes += Uint8List.fromList(
        List.from(cCodeTable.codeUnits)
          ..add(_profile.getCodePageId(globalStyles.codeTable)),
      );
    }
    return bytes;
  }

  /// Sens raw command(s)
  List<int> rawBytes(List<int> cmd, {bool isKanji = false}) {
    List<int> bytes = [];
    if (!isKanji) {
      bytes += cKanjiOff.codeUnits;
    }
    bytes += Uint8List.fromList(cmd);
    return bytes;
  }

  List<int> text(
    String text, {
    PosStyles? styles,
    int linesAfter = 0,
  }) {
    List<int> bytes = [];
    bytes += _text(
      encode(text),
      styles: styles,
    );
    // Ensure at least one line break after the text
    bytes += emptyLines(linesAfter + 1);
    return bytes;
  }

  /// Skips [n] lines
  ///
  /// Similar to [feed] but uses an alternative command
  List<int> emptyLines(int n) {
    List<int> bytes = [];
    if (n > 0) {
      bytes += List.filled(n, '\n').join().codeUnits;
    }
    return bytes;
  }

  /// Skips [n] lines
  ///
  /// Similar to [emptyLines] but uses an alternative command
  List<int> feed(int n) {
    List<int> bytes = [];
    if (n >= 0 && n <= 255) {
      bytes += Uint8List.fromList(
        List.from(cFeedN.codeUnits)..add(n),
      );
    }
    return bytes;
  }

  /// Cut the paper
  ///
  /// [mode] is used to define the full or partial cut (if supported by the printer)
  List<int> cut({PosCutMode mode = PosCutMode.full}) {
    List<int> bytes = [];
    bytes += emptyLines(5);
    if (mode == PosCutMode.partial) {
      bytes += cCutPart.codeUnits;
    } else {
      bytes += cCutFull.codeUnits;
    }
    return bytes;
  }

  /// Print selected code table.
  ///
  /// If [codeTable] is null, global code table is used.
  /// If global code table is null, default printer code table is used.
  List<int> printCodeTable({String? codeTable}) {
    List<int> bytes = [];
    bytes += cKanjiOff.codeUnits;

    if (codeTable != null) {
      bytes += Uint8List.fromList(
        List.from(cCodeTable.codeUnits)..add(_profile.getCodePageId(codeTable)),
      );
    }

    bytes += Uint8List.fromList(List<int>.generate(256, (i) => i));

    // Back to initial code table
    if (_codeTable != null) bytes += setGlobalCodeTable(_codeTable!);
    return bytes;
  }

  /// Beeps [n] times
  ///
  /// Beep [duration] could be between 50 and 450 ms.
  List<int> beep(
      {int n = 3, PosBeepDuration duration = PosBeepDuration.beep450ms}) {
    List<int> bytes = [];
    if (n <= 0) {
      return [];
    }

    int beepCount = n;
    if (beepCount > 9) {
      beepCount = 9;
    }

    bytes += Uint8List.fromList(
      List.from(cBeep.codeUnits)..addAll([beepCount, duration.value]),
    );

    beep(n: n - 9, duration: duration);
    return bytes;
  }

  /// Reverse feed for [n] lines (if supported by the printer)
  List<int> reverseFeed(int n) {
    List<int> bytes = [];
    bytes += Uint8List.fromList(
      List.from(cReverseFeedN.codeUnits)..add(n),
    );
    return bytes;
  }

  /// Print a row.
  ///
  /// A row contains up to 12 columns. A column has a width between 1 and 12.
  /// Total width of columns in one row must be equal 12.
  List<int> row(List<PosColumn> cols) {
    List<int> bytes = [];
    Map<String, List<PosColumn>> rows = {'current': cols, 'next': []};

    final isSumValid = cols.fold(0, (int sum, col) => sum + col.width) == 12;

    if (!isSumValid) {
      throw Exception('Total columns width must be equal to 12');
    }

    void _processRow() {
      for (int i = 0; i < rows['current']!.length; ++i) {
        PosColumn col = rows['current']![i];

        int colInd = rows['current']!
            .sublist(0, i)
            .fold(0, (int sum, col) => sum + col.width);
        double charWidth = _getCharWidth(col.styles);
        double fromPos = _colIndToPosition(colInd);
        final double toPos =
            _colIndToPosition(colInd + col.width) - spaceBetweenRows;
        int maxCharacters = ((toPos - fromPos) / charWidth).floor();

        int realCharacters = col.text.length;
        if (realCharacters > maxCharacters) {
          rows['next']!.add(PosColumn(
            text: col.text.substring(maxCharacters),
            width: col.width,
            styles: col.styles,
          ));
          col.text = col.text.substring(0, maxCharacters);
        } else {
          rows['next']!
              .add(PosColumn(text: '', width: col.width, styles: col.styles));
        }
        bytes += _text(
          encode(col.text),
          styles: col.styles,
          colInd: colInd,
          colWidth: col.width,
        );
      }
    }

    while (rows['current']!.any((col) => col.text.isNotEmpty)) {
      _processRow();
      bytes += emptyLines(1);
      rows['current'] = rows['next']!;
      rows['next'] = [];
    }

    return bytes;
  }

  /// Print an image using (ESC *) command
  ///
  /// [image] is an instance of class from [Image library](https://pub.dev/packages/image)
  List<int> image(Image imgSrc, {PosAlign align = PosAlign.center}) {
    List<int> bytes = [];
    // Image alignment
    bytes += _setStyles(PosStyles().copyWith(align: align));

    final Image image = Image.from(imgSrc); // make a copy

    invert(image);
    flip(image, direction: FlipDirection.horizontal);
    final Image imageRotated = copyRotate(image, angle: 270);

    const int lineHeight = 3;
    final List<List<int>> blobs = _toColumnFormat(imageRotated, lineHeight * 8);

    // Compress according to line density
    // Line height contains 8 or 24 pixels of src image
    // Each blobs[i] contains greyscale bytes [0-255]
    // const int pxPerLine = 24 ~/ lineHeight;
    for (int blobInd = 0; blobInd < blobs.length; blobInd++) {
      blobs[blobInd] = _packBitsIntoBytes(blobs[blobInd]);
    }

    final int heightPx = imageRotated.height;
    const int densityByte = 1 + 32;

    final List<int> header = List.from(cBitImg.codeUnits);
    header.add(densityByte);
    header.addAll(_intLowHigh(heightPx, 2));

    // Adjust line spacing (for 16-unit line feeds): ESC 3 0x10 (HEX: 0x1b 0x33 0x10)
    bytes += [27, 51, 16];
    for (int i = 0; i < blobs.length; ++i) {
      bytes += List.from(header)
        ..addAll(blobs[i])
        ..addAll('\n'.codeUnits);
    }
    // Reset line spacing: ESC 2 (HEX: 0x1b 0x32)
    bytes += [27, 50];
    return bytes;
  }

  /// Print an image using (GS v 0) obsolete command
  ///
  /// [image] is an instance of class from [Image library](https://pub.dev/packages/image)
  List<int> imageRaster(
    Image image, {
    PosAlign align = PosAlign.center,
    bool highDensityHorizontal = true,
    bool highDensityVertical = true,
    PosImageFn imageFn = PosImageFn.bitImageRaster,
  }) {
    List<int> bytes = [];
    // Image alignment
    bytes += _setStyles(PosStyles().copyWith(align: align));

    final int widthPx = image.width;
    final int heightPx = image.height;
    final int widthBytes = (widthPx + 7) ~/ 8;
    final List<int> rasterizedData = _toRasterFormat(image);

    if (imageFn == PosImageFn.bitImageRaster) {
      // GS v 0
      final int densityByte =
          (highDensityVertical ? 0 : 1) + (highDensityHorizontal ? 0 : 2);

      final List<int> header = List.from(cRasterImg2.codeUnits);
      header.add(densityByte); // m
      header.addAll(_intLowHigh(widthBytes, 2)); // xL xH
      header.addAll(_intLowHigh(heightPx, 2)); // yL yH
      bytes += List.from(header)..addAll(rasterizedData);
    } else if (imageFn == PosImageFn.graphics) {
      // 'GS ( L' - FN_112 (Image data)
      final List<int> header1 = List.from(cRasterImg.codeUnits);
      header1.addAll(_intLowHigh(widthBytes * heightPx + 10, 2)); // pL pH
      header1.addAll([48, 112, 48]); // m=48, fn=112, a=48
      header1.addAll([1, 1]); // bx=1, by=1
      header1.addAll([49]); // c=49
      header1.addAll(_intLowHigh(widthBytes, 2)); // xL xH
      header1.addAll(_intLowHigh(heightPx, 2)); // yL yH
      bytes += List.from(header1)..addAll(rasterizedData);

      // 'GS ( L' - FN_50 (Run print)
      final List<int> header2 = List.from(cRasterImg.codeUnits);
      header2.addAll([2, 0]); // pL pH
      header2.addAll([48, 50]); // m fn[2,50]
      bytes += List.from(header2);
    }
    return bytes;
  }

  /// Print a barcode
  ///
  /// [width] range and units are different depending on the printer model (some printers use 1..5).
  /// [height] range: 1 - 255. The units depend on the printer model.
  /// Width, height, font, text position settings are effective until performing of ESC @, reset or power-off.
  List<int> barcode(
    Barcode barcode, {
    int? width,
    int? height,
    BarcodeFont? font,
    BarcodeText textPos = BarcodeText.below,
    PosAlign align = PosAlign.center,
  }) {
    List<int> bytes = [];
    // Set alignment
    bytes += _setStyles(PosStyles().copyWith(align: align));

    // Set text position
    bytes += cBarcodeSelectPos.codeUnits + [textPos.value];

    // Set font
    if (font != null) {
      bytes += cBarcodeSelectFont.codeUnits + [font.value];
    }

    // Set width
    if (width != null && width >= 0) {
      bytes += cBarcodeSetW.codeUnits + [width];
    }
    // Set height
    if (height != null && height >= 1 && height <= 255) {
      bytes += cBarcodeSetH.codeUnits + [height];
    }

    // Print barcode
    final header = cBarcodePrint.codeUnits + [barcode.type!.value];
    if (barcode.type!.value <= 6) {
      // Function A
      bytes += header + barcode.data! + [0];
    } else {
      // Function B
      bytes += header + [barcode.data!.length] + barcode.data!;
    }
    return bytes;
  }

  /// Print a QR Code
  List<int> qrcode(
    String text, {
    PosAlign align = PosAlign.center,
    QRSize size = QRSize.Size4,
    QRCorrection cor = QRCorrection.L,
  }) {
    List<int> bytes = [];
    // Set alignment
    bytes += _setStyles(PosStyles().copyWith(align: align));
    QRCode qr = QRCode(text, size, cor);
    bytes += qr.bytes;
    return bytes;
  }

  /// Open cash drawer
  List<int> drawer({PosDrawer pin = PosDrawer.pin2}) {
    List<int> bytes = [];
    if (pin == PosDrawer.pin2) {
      bytes += cCashDrawerPin2.codeUnits;
    } else {
      bytes += cCashDrawerPin5.codeUnits;
    }
    return bytes;
  }

  /// Print horizontal full width separator
  /// If [len] is null, then it will be defined according to the paper width
  List<int> hr({
    String ch = '-',
    int? len,
    int linesAfter = 0,
    PosStyles? styles,
  }) {
    List<int> bytes = [];
    int n = len ?? _getMaxCharsPerLine(styles?.fontType);
    String ch1 = ch.length == 1 ? ch : ch[0];
    bytes += text(List.filled(n, ch1).join(), linesAfter: linesAfter);
    bytes += _setStyles(styles ?? globalStyles);
    return bytes;
  }

  List<int> textEncoded(
    Uint8List textBytes, {
    PosStyles? styles,
    int linesAfter = 0,
    int? maxCharsPerLine,
  }) {
    List<int> bytes = [];
    bytes += _text(textBytes, styles: styles);
    // Ensure at least one line break after the text
    bytes += emptyLines(linesAfter + 1);
    return bytes;
  }

  // ************************ (end) Public command generators ************************

  // ************************ (end) Internal command generators ************************
  /// Generic print for internal use
  ///
  /// [colInd] range: 0..11. If null: do not define the position
  List<int> _text(
    Uint8List textBytes, {
    PosStyles? styles,
    int colInd = 0,
    int? colWidth,
  }) {
    List<int> bytes = [];
    double charWidth = _getCharWidth(styles);
    double fromPos = _colIndToPosition(colInd);

    // Align
    if (colWidth != null) {
      final double toPos =
          _colIndToPosition(colInd + colWidth) - spaceBetweenRows;
      final double textLen = textBytes.length * charWidth;

      if (styles?.align == PosAlign.right) {
        fromPos = toPos - textLen;
      } else if (styles?.align == PosAlign.center) {
        fromPos = fromPos + (toPos - fromPos) / 2 - textLen / 2;
      }
      if (fromPos < 0) {
        fromPos = 0;
      }
    }

    // Set absolute horizontal print position using ESC $ nL nH
    final position = fromPos.round();
    final nL = position & 0xFF;
    final nH = (position >> 8) & 0xFF;
    bytes += [0x1B, 0x24, nL, nH]; // ESC $ command

    bytes += _setStyles(styles ?? globalStyles);
    bytes += textBytes;
    return bytes;
  }
// ************************ (end) Internal command generators ************************
}
