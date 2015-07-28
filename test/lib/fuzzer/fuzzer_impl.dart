part of otdartlib.fuzzer;

abstract class FuzzerImpl {
  List generateRandomOp(doc);
  dynamic serialize(doc);

  dynamic clone(obj);
     
  double randomReal() => _RandomUtils.randomReal();

  //# Generate a random int 0 <= k < n
  int randomInt(n) => _RandomUtils.randomInt(n);

  //# Return a random word from a corpus each time the method is called
  String randomWord() => _RandomUtils.randomWord();
}