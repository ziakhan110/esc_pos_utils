import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fish = 'Fish & chips';
  const dish = '宫保鸡丁';

  test('English text and rows stay on the Latin path', () async {
    final profile = await CapabilityProfile.load();
    final on = _generator(profile, chineseEnabled: true);
    final off = _generator(profile, chineseEnabled: false);

    expect(on.text(fish), off.text(fish));
    expect(
      on.text(fish,
          styles: const PosStyles(bold: true, align: PosAlign.center)),
      off.text(fish,
          styles: const PosStyles(bold: true, align: PosAlign.center)),
    );
    expect(on.hr(), off.hr());
    expect(on.cut(), off.cut());
    expect(on.feed(2), off.feed(2));
    expect(
      on.row([
        PosColumn(text: '1x', width: 2, styles: const PosStyles(bold: true)),
        PosColumn(text: fish, width: 6),
        PosColumn(
          text: '${String.fromCharCode(156)}12.50',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
      off.row([
        PosColumn(text: '1x', width: 2, styles: const PosStyles(bold: true)),
        PosColumn(text: fish, width: 6),
        PosColumn(
          text: '${String.fromCharCode(156)}12.50',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    expect(_indexOf(on.text(fish), const [0x1C, 0x26]), -1);
  });

  test('Chinese line keeps Kanji on through the line feed and skips CP437',
      () async {
    final profile = await CapabilityProfile.load();
    final generator = _generator(profile, chineseEnabled: true);
    generator.setGlobalCodeTable('CP437');
    final bytes = generator.text(dish, styles: const PosStyles(bold: true));
    final kanjiOn = _indexOf(bytes, const [0x1C, 0x26]);
    final lineFeed = bytes.indexOf(0x0A);
    final kanjiOff = _indexOf(bytes, const [0x1C, 0x2E]);

    expect(kanjiOn, greaterThanOrEqualTo(0));
    expect(lineFeed, greaterThan(kanjiOn));
    expect(kanjiOff, greaterThan(lineFeed));
    expect(_indexOf(bytes, const [0x1B, 0x74]), -1);
    final payload = bytes.sublist(kanjiOn + 2, lineFeed);
    expect(payload.take(2), [0xB9, 0xAC]);
    expect(payload.length, dish.length * 2);
  });

  test('a Chinese name wraps before the price column', () async {
    final profile = await CapabilityProfile.load();
    final generator =
        _generator(profile, chineseEnabled: true, charsPerLine: 32);
    final name = '宫' * 10;
    final bytes = generator.row([
      PosColumn(text: '1x', width: 2),
      PosColumn(text: name, width: 6),
      PosColumn(
        text: '12.50',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    final firstFeed = bytes.indexOf(0x0A);
    expect(firstFeed, greaterThan(0));
    final firstLine = bytes.sublist(0, firstFeed);
    expect(_indexOf(bytes, const [0x1C, 0x2E]), greaterThan(firstFeed));
    expect(_indexOf(firstLine, const [0x1B, 0x74]), -1);
    expect(String.fromCharCodes(firstLine).contains('12.50'), isTrue);
    expect(_count(firstLine, const [0xB9, 0xAC]), 7);
    expect(_count(bytes, const [0xB9, 0xAC]), name.length);
  });

  test('a pound sign inside Chinese text is not a raw GBK lead', () async {
    final profile = await CapabilityProfile.load();
    final generator = _generator(profile, chineseEnabled: true);
    final bytes = generator.text('宫${String.fromCharCode(156)}8');
    final kanjiOn = _indexOf(bytes, const [0x1C, 0x26]);
    final lineFeed = bytes.indexOf(0x0A);
    final payload = bytes.sublist(kanjiOn + 2, lineFeed);

    expect(payload, isNot(contains(0x9C)));
    expect(payload.last, 0x38);
    expect(payload.first, 0xB9);
  });

  test('text generator Chinese lines use Kanji and English lines stay Latin',
      () async {
    final profile = await CapabilityProfile.load();
    final generator = TextGenerator(
      PaperSize(fontACharsPerLine: 48, fontBCharsPerLine: 48),
      profile,
      chineseEnabled: true,
      globalStyles: const PosStyles(fontType: PosFontType.fontA),
      spaceBetweenRows: 5,
    );
    generator.setGlobalCodeTable('CP437');

    final english = generator.text(fish);
    expect(_indexOf(english, const [0x1C, 0x26]), -1);
    expect(String.fromCharCodes(english).contains(fish), isTrue);

    final chinese = generator.text(dish);
    final kanjiOn = _indexOf(chinese, const [0x1C, 0x26]);
    final lineFeed = chinese.indexOf(0x0A);
    final kanjiOff = _indexOf(chinese, const [0x1C, 0x2E]);
    expect(lineFeed, greaterThan(kanjiOn));
    expect(kanjiOff, greaterThan(lineFeed));
    expect(_indexOf(chinese, const [0x1B, 0x74]), -1);
  });
}

Generator _generator(
  CapabilityProfile profile, {
  required bool chineseEnabled,
  int charsPerLine = 48,
}) {
  final generator = Generator(
    PaperSize(
      fontACharsPerLine: charsPerLine,
      fontBCharsPerLine: charsPerLine,
    ),
    profile,
    chineseEnabled: chineseEnabled,
    globalStyles: const PosStyles(fontType: PosFontType.fontA),
    spaceBetweenRows: charsPerLine == 32 ? 1 : 5,
  );
  generator.setGlobalCodeTable('CP437');
  return generator;
}

int _indexOf(List<int> bytes, List<int> pattern) {
  for (var i = 0; i <= bytes.length - pattern.length; i++) {
    var found = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        found = false;
        break;
      }
    }
    if (found) return i;
  }
  return -1;
}

int _count(List<int> bytes, List<int> pattern) {
  var count = 0;
  for (var i = 0; i <= bytes.length - pattern.length; i++) {
    if (_indexOf(bytes.sublist(i), pattern) == 0) count++;
  }
  return count;
}
