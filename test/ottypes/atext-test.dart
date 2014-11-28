part of otdartlib.test.ottypes;

void atext_test() {
  group('atext randomizer', () {
    test('passes', () {
      new Fuzzer(new FuzzerATextImpl()).runTest(new OTTypeFactory.from('atext'), 500);
    });
  });
}