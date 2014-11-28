part of otdartlib.test.ottypes;

void atext_test() {
  group('atext randomizer', () {
    test('passes', () {
      new Fuzzer(new FuzzerATextImpl()).runTest(new OT_atext(), 500);
    });
  });
}