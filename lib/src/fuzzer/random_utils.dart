part of otdartlib.fuzzer;

class _RandomUtils {
  //# By default, use a new seed every 6 hours. This balances making test runs stable while debugging
  //# with avoiding obscure bugs caused by a rare seed.
  static int seed = (new DateTime.now().millisecondsSinceEpoch / (1000*60*60*6)).floor();
  
//  static final _random = new MersenneTwister(seed);
  static final _random = new MersenneTwister()..seed(seed);
  
  static List<String> _words = new File(new File(Platform.script.toFilePath()).parent.path + '/../lib/src/fuzzer/jabberwocky.txt')
    .readAsStringSync()
    .split(new RegExp(r'\W+'))..removeWhere((s) => s.isEmpty);
   
  static double randomReal() => _random.rand_real();

  //# Generate a random int 0 <= k < n
  static int randomInt(n) => (randomReal() * n).floor();

  //# Return a random word from a corpus each time the method is called
  static String randomWord() { 
    return _words[randomInt(_words.length)];
  }
}