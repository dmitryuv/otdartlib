part of otdartlib.test.atext_changeset;

void opComponent_test() {
  var errMatcher = (msg) => predicate((Exception e) => new RegExp(msg).hasMatch(e.toString()));

  group('OpComponent', () {
    test('test constructor', () {
      expect(new OpComponent.keep(0, 0).opcode, equals('='));
      expect(new OpComponent.insert(0, 0, new AttributeList(), '').opcode, equals('+'));
      expect(new OpComponent.remove(0, 0, new AttributeList(), '').opcode, equals('-'));
      expect(new OpComponent.empty().charBank, equals(''));
      expect(() => new OpComponent('+', 2, 1, new AttributeList(), '\na'), throwsA(errMatcher('should end up with newline')));
    });

    test('equal', () {
      var pool = [['foo', 'bar']];
      test(c1, c2, ignoreOpcode, res) {
        c1 = new OpComponent(c1[0], c1[1], c1[2], new AttributeList.unpack(c1[3], pool), c1[4]);
        c2 = new OpComponent(c2[0], c2[1], c2[2], new AttributeList.unpack(c2[3], pool), c2[4]);
        if(ignoreOpcode) {
          expect(c1.equalsButOpcode(c2), equals(res));
        } else {
          expect(c1 == c2, equals(res));
        }
      }
      test(['+', 1, 0, null, 'a'], ['+', 2, 0, null, 'ab'], false, false);
      test(['+', 1, 0, '*0', 'a'], ['+', 1, 0, '*0', 'a'], false, true);
      test(['-', 1, 0, '*0', 'a'], ['+', 1, 0, '*0', 'a'], true, true);
      test(['=', 1, 0, '*0', 'b'], ['+', 1, 0, '*0', 'a'], true, true);
      test(['+', 1, 0, '*0', 'a'], ['=', 1, 0, '*0', ''], true, true);
    });
  
    test('slice', () {
      var c = new OpComponent('+', 5, 2, new AttributeList(), 'ab\nc\n');
//      var s = c.sliceRight(3, 1);
//      var r = new OpComponent('+', 2, 1, new AttributeList(), 'c\n');
//      print('${c.sliceRight(3, 1).hashCode}, ${new OpComponent('+', 2, 1, new AttributeList(), 'c\n').hashCode}');
//      print('$s, $r');
      expect(c.sliceRight(3, 1), equals(new OpComponent('+', 2, 1, new AttributeList(), 'c\n')));
      expect(c.sliceLeft(3, 1), equals(new OpComponent('+', 3, 1, new AttributeList(), 'ab\n')));
    });
  
    group('invert', () {
      testInvert(name, opcode, atts, expectedOpcode, expectedAtts) {
        test(name, () {
          atts = new AttributeList.unpack(atts, [['foo','bar']]);
          expectedAtts = new AttributeList.unpack(expectedAtts, [['foo','bar']]);
          var c = new OpComponent(opcode, 1, 0, atts, 'a').invert();
          expect(c, equals(new OpComponent(expectedOpcode, 1, 0, expectedAtts, 'a')));
        });
      }
  
      testInvert('insert invertion', '+', '*0', '-', '*0');
      testInvert('remove invertion', '-', '^0', '+', '^0');
      testInvert('format invertion', '=', '*0', '=', '^0');
    });

    group('append', () {
      var alist = new AttributeList.unpack('*0', [['foo','bar']]);
      var c = new OpComponent('+', 3, 1, alist, 'ab\n');
      test('same type', () {
        expect(c.append(c), equals(new OpComponent('+', 6, 2, alist, 'ab\nab\n')));
      });
      test('to empty', () {
        expect(new OpComponent.empty().append(c), equals(c));
      });
      test('throw if not compatible', () {
        expect(() {
            var c2 = new OpComponent.keep(1, 0);
            c.append(c2);
          }, throwsA(errMatcher('cannot append')));
        expect(() {
            var c2 = new OpComponent(c.opcode, c.chars, c.lines, new AttributeList.unpack('*0', [['x', 'y']]), c.charBank);
            c.append(c2);
          }, throwsA(errMatcher('cannot append')));
      });
      test('skip no-ops', () {
        expect(c.append(new OpComponent.empty()), equals(c));
      });
    });

    test('slicer', () {
      var c = new OpComponent('+', 4, 2, new AttributeList(), 'a\nb\n');
      var slicer = c.slicer;
      expect(slicer.nextLine(), equals(new OpComponent('+', 2, 1, new AttributeList(), 'a\n')));
      expect(slicer.next(2, 1), equals(new OpComponent('+', 2, 1, new AttributeList(), 'b\n')));
      expect(slicer.isEmpty, equals(true));
      expect(slicer.current, equals(new OpComponent('+', 0, 0, new AttributeList(), '')));
    });

    test('pack', () {
      var pool = [['foo','bar'], ['x','y']];
      var c = new OpComponent('+', 10, 2, new AttributeList.unpack('*0*1', pool), '1234\n6789\n');
      expect(c.pack(pool), equals(new AString(atts: '*0*1|2+a', text: '1234\n6789\n')));
    });
  });
}