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

    group('transformRange', () {
      var samplePool = [['author', 'x'], ['bold', true], ['italic', true], ['author','y']];

      range(name, cs, pos, side, res) {
        test(name, () {
          cs = new Changeset.unpack({'op': cs, 'p': samplePool});
          var p = new Position(pos[0], pos[1]);
          expect(p.transform(cs, side), equals(new Position(res[0], res[1])));
        });
      }

      range('push by char insert', 'X:4>2=2+2\$ab', [3, 0], 'left', [5, 0]);
      range('push by newline insert near pos', 'X:4>2=2|1+2\$b\n', [3, 0], 'left', [1, 1]);  //abb\nc_d
      range('push by line insert far away from pos', 'X:4>4|2+2\$\n\n', [1, 2], 'left', [1, 4]);
      range('tie break insert left', 'X:4>2=2+2\$ab', [2, 0], 'left', [2, 0]);
      range('tie break insert right', 'X:4>2=2+2\$ab', [2, 0], 'right', [4, 0]);
      range('remove chars before pos', 'X:8<4-4\$abcd', [6, 0], 'left', [2, 0]);
      range('collapse remove range', 'X:8<4=2-4\$abcd', [4, 0], 'left', [2, 0]);
      range('collapse remove multiline range', 'X:a<4|1=2=1|2-3\$\nb\n', [2, 1], 'left', [1, 1]);
      range('remove multiline range joins pos with cursor', 'X:8<4=2|1-4\$abc\n', [1, 1], 'left', [3, 0]);      // 12abc\nd_e
      range('remove multiline range reduces pos lines', 'X:a<4|2-4\$a\nb\n', [1, 3], 'left', [1, 1]);
      range('keep does not alter pos', 'X:8>2=8+2\$ab', [7, 0], 'left', [7, 0]);
    });
  });
}