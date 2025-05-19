/*
 * esc_pos_utils
 * Created by Andrey U.
 * 
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

const int esc = 0x1B;
const int gs = 0x1D;
const int fs = 0x1C;

// Miscellaneous
const List<int> cInit = [esc, 0x40]; // Initialize printer | ESC @
const List<int> cBeep = [esc, 0x42]; // Beeper [count] [duration] | ESC B

// Mech. Control
const List<int> cCutFull = [gs, 0x56, 0x30]; // Full cut | GS V 0
const List<int> cCutPart = [gs, 0x56, 0x31]; // Partial cut | GS V 1

// Character
const List<int> cReverseOn = [gs, 0x42, 0x01]; // Reverse print mode on | GS B 1
const List<int> cReverseOff = [gs, 0x42, 0x00]; // Reverse print mode off | GS B 0
const List<int> cSizeGSn = [gs, 0x21]; // Select character size [N] | GS !
const List<int> cSizeESCn = [esc, 0x21]; // Select character size [N] | ESC !
const List<int> cUnderlineOff = [esc, 0x2D, 0x00]; // Underline off | ESC - 0
const List<int> cUnderline1dot = [esc, 0x2D, 0x01]; // Underline 1-dot | ESC - 1
const List<int> cUnderline2dots = [esc, 0x2D, 0x02]; // Underline 2-dots | ESC - 2
const List<int> cBoldOn = [esc, 0x45, 0x01]; // Bold on | ESC E 1
const List<int> cBoldOff = [esc, 0x45, 0x00]; // Bold off | ESC E 0
const List<int> cFontA = [esc, 0x4D, 0x00]; // Font A | ESC M 0
const List<int> cFontB = [esc, 0x4D, 0x01]; // Font B | ESC M 1
const List<int> cTurn90On = [esc, 0x56, 0x01]; // Rotate 90° on | ESC V 1
const List<int> cTurn90Off = [esc, 0x56, 0x00]; // Rotate 90° off | ESC V 0
const List<int> cCodeTable = [esc, 0x74]; // Select code table [N] | ESC t
const List<int> cKanjiOn = [fs, 0x26]; // Kanji mode on | FS &
const List<int> cKanjiOff = [fs, 0x2E]; // Kanji mode off | FS .

// Print Position
const List<int> cAlignLeft = [esc, 0x61, 0x00]; // Align left | ESC a 0
const List<int> cAlignCenter = [esc, 0x61, 0x01]; // Align center | ESC a 1
const List<int> cAlignRight = [esc, 0x61, 0x02]; // Align right | ESC a 2
const List<int> cPos = [esc, 0x24]; // Set print position [nL] [nH] | ESC $

 // Print
const List<int> cFeedN = [esc, 0x64]; // Print and feed n lines [N] | ESC d
const List<int> cReverseFeedN = [esc, 0x65]; // Reverse feed n lines [N] | ESC e

// Bit Image
const List<int> cRasterImg = [gs, 0x28, 0x4C]; // Print raster bit image | GS ( L
const List<int> cRasterImg2 = [gs, 0x76, 0x30]; // Obsolete raster format | GS v 0
const List<int> cBitImg = [esc, 0x2A]; // Print column image | ESC *

// Barcode
const List<int> cBarcodeSelectPos = [gs, 0x48]; // HRI position | GS H
const List<int> cBarcodeSelectFont = [gs, 0x66]; // HRI font | GS f
const List<int> cBarcodeSetH = [gs, 0x68]; // Barcode height | GS h
const List<int> cBarcodeSetW = [gs, 0x77]; // Barcode width | GS w
const List<int> cBarcodePrint = [gs, 0x6B]; // Print barcode | GS k

// Cash Drawer Open
const List<int> cCashDrawerPin2 = [esc, 0x70, 0x30, 0x3C, 0x78]; // Pulse pin 2 | ESC p 0 60 120
const List<int> cCashDrawerPin5 = [esc, 0x70, 0x31, 0x3C, 0x78]; // Pulse pin 5 | ESC p 1 60 120

// QR Code
const List<int> cQrHeader = [gs, 0x28, 0x6B]; // QR code header | GS ( k