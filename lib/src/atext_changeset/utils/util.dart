part of otdartlib.atext_changeset;

abstract class Clonable {
  dynamic clone();
}

class _util {
  static int parseInt36(String str) => int.parse(str, radix: 36);
  static String toString36(int num) => num.toRadixString(36);
}
