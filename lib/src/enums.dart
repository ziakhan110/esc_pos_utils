/*
 * esc_pos_utils
 * Created by Andrey U.
 * 
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

enum PosAlign { left, center, right }
enum PosCutMode { full, partial }
enum PosDrawer { pin2, pin5 }

/// Choose image printing function
/// bitImageRaster: GS v 0 (obsolete)
/// graphics: GS ( L
enum PosImageFn { bitImageRaster, graphics }

enum PosFontType { fontA, fontB }

class PosTextSize {
  const PosTextSize._internal(this.value);
  final int value;
  static const size1 = PosTextSize._internal(1);
  static const size2 = PosTextSize._internal(2);
  static const size3 = PosTextSize._internal(3);
  static const size4 = PosTextSize._internal(4);
  static const size5 = PosTextSize._internal(5);
  static const size6 = PosTextSize._internal(6);
  static const size7 = PosTextSize._internal(7);
  static const size8 = PosTextSize._internal(8);

  static int decSize(PosTextSize height, PosTextSize width) => 16 * (width.value - 1) + (height.value - 1);
}

enum PaperWidth { mm80, mm58 }

class PaperSize {
  PosFontType fontType;
  final PaperWidth value;
  final int fontACharWidth;
  final int fontBCharWidth;
  int fontACharsPerLine;
  int fontBCharsPerLine;
  static PaperSize mm58 = PaperSize(PaperWidth.mm58);
  static PaperSize mm80 = PaperSize(PaperWidth.mm58);
  PaperSize(
    this.value, {
    this.fontType = PosFontType.fontA,
    this.fontACharWidth = 12,
    this.fontBCharWidth = 9,
    this.fontACharsPerLine = 48,
    this.fontBCharsPerLine = 64,
  });

  int get width {
    if (this.fontType == PosFontType.fontA) {
      return this.fontACharWidth * this.fontACharsPerLine;
    } else {
      return this.fontBCharWidth * this.fontACharsPerLine;
    }
  }
}

class PosBeepDuration {
  const PosBeepDuration._internal(this.value);
  final int value;
  static const beep50ms = PosBeepDuration._internal(1);
  static const beep100ms = PosBeepDuration._internal(2);
  static const beep150ms = PosBeepDuration._internal(3);
  static const beep200ms = PosBeepDuration._internal(4);
  static const beep250ms = PosBeepDuration._internal(5);
  static const beep300ms = PosBeepDuration._internal(6);
  static const beep350ms = PosBeepDuration._internal(7);
  static const beep400ms = PosBeepDuration._internal(8);
  static const beep450ms = PosBeepDuration._internal(9);
}
