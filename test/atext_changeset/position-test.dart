part of otdartlib.test.atext_changeset;

void position_test() {
  group('Positioin', () {
    test('empty constructor', () {
      expect(new Position(), equals(new Position(0, 0)));
    });
  
    test('add', () {
      expect(new Position(1, 1)..add(1, 0), equals(new Position(2, 1)));
      expect(new Position(1, 1)..add(1, 1), equals(new Position(1, 2)));
    });
  
    test('advance', () {
      expect(new Position(1, 1)..advance(1, 1), equals(new Position(0, 2)));
    });
  
    test('subtract', () {
      expect(new Position(5, 5)..subtract(1, 0), equals(new Position(4, 5)));
      expect(new Position(5, 5)..subtract(1, 1), equals(new Position(5, 4)));
    });
  
    test('compare', () {
      expect(new Position(1, 0).before(new Position(0, 1)), equals(true));
    });
  });
}