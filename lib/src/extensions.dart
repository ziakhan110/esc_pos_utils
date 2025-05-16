extension StringExt on String {
  String center(int width) {
    var str = this;
    if (this.length > width) str = this.substring(0, width);
    var len = str.length;
    var left = str.substring(0, len ~/ 2);
    var right = str.substring(len ~/ 2, len);

    var leftPadded = left.padLeft(width ~/ 2);
    var rightPadded = right.padRight(width ~/ 2);
    return leftPadded + rightPadded;
  }

  String trimToWidth(int width) {
    if (length > width) {
      return substring(0, width);
    } else {
      return this;
    }
  }
}
