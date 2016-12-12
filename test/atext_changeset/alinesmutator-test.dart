part of otdartlib.test.atext_changeset;

void alinesMutator_test() {
  clone(obj) {
    return JSON.decode(JSON.encode(obj));
  }
  var errMatcher = (msg) => predicate((Exception e) => new RegExp(msg).hasMatch(e.toString()));

  group('ALinesMutator', () {
    var pool = [['foo','bar'], ['author','x'], ['bold','true'], ['list', 1], ['italic', true]];
    var sample = [{'a':'*0+1|1+3', 's':'abc\n'}, {'a':'*1+4|1+1', 's':'defg\n'}];
    clist(list) {
      return new ComponentList()..addAll(
        list.map((item) => new OpComponent(item[0], item[1], item[2], new AttributeList.unpack(item[3], pool), item[4]))    
      );
    }
  
    test('length calculation', () {
      expect(new ALinesMutator(sample, pool).getLength(), equals(9));
    });
  
    test('length calculation when mutate in progress', () {
      var m = new ALinesMutator(clone(sample), pool)
        ..insert(new OpComponent('+', 1, 0, new AttributeList(), 'a'));

      expect(m.getLength(), equals(10));
    });
  
    test('can build document from scratch', () {
      test(lines) {
        var m = new ALinesMutator([], pool);
        lines.forEach((l) {
          var ops = new AStringMutator(new AString.unpack(l), pool).takeRemaining();
          ops.forEach((c) => m.insert(c));
        });
        expect(m.finish(), equals(lines));
      }
  
      test(sample);
      test([{'a':'|1+4', 's':'abc\n'}, {'a':'|1+5', 's':'defg\n'}]);
      test([{'a':'+3', 's': 'abc'}]);
    });
  
    test('can decompose into subcomponents', () {
      var m = new ALinesMutator(sample, pool)
        ..skip(3, 0);
      var ops = new ComponentList()..addAll(m.take(6, 2));
      expect(ops.toAString(pool).pack(), equals({'a':'|1+1*1+4|1+1', 's':'\ndefg\n'}));
    });
  
    test('can insert multiline ops mid-line', () {
      var m = new ALinesMutator(clone(sample), pool)
        ..skip(2, 0)
        ..insert(new OpComponent('+', 4, 2, new AttributeList(), 'X\nY\n'));
      var res = m.finish();
  
      expect(res, equals([{'a':'*0+1|1+3', 's':'abX\n'}, {'a':'|1+2', 's':'Y\n'}, {'a':'|1+2', 's':'c\n'}, {'a':'*1+4|1+1', 's':'defg\n'}]));
    });
  
    test('can remove multiline ops mid-line', () {
      var m = new ALinesMutator(clone(sample)..addAll(sample), pool)
        ..skip(2, 0);
      var removed = m.remove(7, 2);
  
      expect(removed, equals(clist([['+', 2, 1, null, 'c\n'], ['+', 4, 0, '*1', 'defg'], ['+', 1, 1, '', '\n']])));
      expect(m.finish(), equals([{'a':'*0+1+1*0+1|1+3', 's':'ababc\n'},{'a':'*1+4|1+1', 's':'defg\n'}]));
    });
  
    test('removal between lines create at least 2 ops even if they\'re mergeable', () {
      var lines = [{'a':'|1+4', 's':'abc\n'}, {'a':'|1+5', 's':'defg\n'}];
      var m = new ALinesMutator(lines, [])
        ..skip(2, 0);
      var removed = m.remove(7, 2);
      expect(removed, equals(clist([['+', 2, 1, null, 'c\n'], ['+', 5, 1, null, 'defg\n']])));
    });
  
    test('remove last line should not leave empty line', () {
      var lines = [{'a':'|1+4', 's':'abc\n'}, {'a':'|1+5', 's':'defg\n'}];
      var m = new ALinesMutator(lines, [])
        ..skip(4, 1)
        ..remove(5, 1);
      expect(m.finish(), equals([{'a':'|1+4', 's':'abc\n'}]));
    });
  
    test('remove first line should not leave empty line', () {
      var lines = [{'a':'|1+4', 's':'abc\n'}, {'a':'|1+5', 's':'defg\n'}];
      var m = new ALinesMutator(lines, [])  
        ..remove(4, 1);
      expect(m.finish(), equals([{'a':'|1+5', 's':'defg\n'}]));
    });
  
    test('remove complete line from the middle', () {
      var lines = [{'a':'|1+4', 's':'abc\n'}, {'a':'|1+4', 's':'def\n'}, {'a':'|1+4', 's':'ghi\n'}];
      var m = new ALinesMutator(lines, [])  
        ..skip(4, 1)
        ..remove(4, 1);
      expect(m.finish(), equals([{'a':'|1+4', 's':'abc\n'}, {'a':'|1+4', 's':'ghi\n'}]));
    });
  
    test('insert newline when line position is 0 but string was mutated', () {
      var lines = [{"a":"|1+2","s":"a\n"},{"a":"+1","s":"b"}];
      var m = new ALinesMutator(lines, [])
        ..skip(2, 1)
        ..remove(1, 0)
        ..insert(new OpComponent('+', 2, 1, new AttributeList(), 'X\n'));
      
      expect(m.finish(), equals([{"a":"|1+2","s":"a\n"},{"a":"|1+2","s":"X\n"}]));
    });
  
    test('remove from midline to the rest of the doc and insert', () {
      var lines = [{"a":"|1+2","s":"a\n"},{"a":"|1+2","s":"b\n"}];
      var m = new ALinesMutator(lines, [])
        ..skip(1, 0)
        ..remove(3, 2)
        ..insert(new OpComponent('+', 1, 0, new AttributeList(), 'X'));
      
      expect(m.finish(), equals([{"a":"+2","s":"aX"}]));
    });
  
    test('joining lines on removal updates current iterator position', () {
      var m = new ALinesMutator(clone(sample), pool)
        ..skip(3, 0)
        ..remove(1, 1);
  
      expect(m.position, equals(new Position(3, 0)));
    });
  
    test('can do complex mutations', () {
      var localSample = [{'a':'|1+5', 's':'abcd\n'}, {'a':'|1+4', 's':'efg\n'}];
      var m = new ALinesMutator(clone(localSample), pool);
      expect(m.remove(2, 0), equals(clist([['+', 2, 0, null, 'ab']])));
      
      m..skip(3, 1)
        ..insert(new OpComponent('+', 4, 2, new AttributeList(), 'X\nY\n'))
        ..skip(2, 0);
      expect(m.remove(2, m.remaining), equals(clist([['+', 2, 1, null, 'g\n']])));
      
      m.insert(new OpComponent('+', 1, 1, new AttributeList(), '\n'));
      expect(m.finish(), equals([{'a':'|1+3', 's':'cd\n'},{'a':'|1+2', 's':'X\n'}, {'a':'|1+2', 's':'Y\n'}, {'a':'|1+3', 's':'ef\n'}]));
    });
  
    test('multiline format', () {
      var localSample = [{'a':'|1+5', 's':'abcd\n'}, {'a':'|1+4', 's':'efg\n'}];
      var fop = new OpComponent.createFormat(8, 2, new AttributeList.unpack('*0', pool));
      var m = new ALinesMutator(clone(localSample), pool)
        ..skip(1, 0)
        ..applyFormat(fop);
  
      expect(m.finish(), equals([{'a':'+1*0|1+4', 's':'abcd\n'}, {'a':'*0|1+4', 's':'efg\n'}]));
    });
  });
}  
