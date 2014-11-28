part of otdartlib.test.atext_changeset;

void opComponent_test() {
  var errMatcher = (msg) => predicate((Exception e) => new RegExp(msg).hasMatch(e.toString()));

  group('OpComponent', () {
    test('test constructor', () {
      var pool = [['foo','bar']];
      expect(new OpComponent('=').opcode, equals('='));
      expect(new OpComponent(null).charBank, equals(null));
      expect(() => new OpComponent('+', 2, 1, null, '\na'), throwsA(errMatcher('should end up with newline')));
    });

    test('clear', () {
      expect(new OpComponent()..clear(), equals(new OpComponent()));
    });
  
    test('clone', () {
      var pool = [['foo','bar']];
      var orig = new OpComponent('+', 2, 1, new AttributeList.unpack('*0',pool), 'a\n');
      expect(orig.clone(), equals(orig));
      expect(orig.copyTo(new OpComponent()), equals(orig));
      // clear charbank on opcode override to '='
      expect(orig.copyTo(new OpComponent(), '='), equals(new OpComponent('=', 2, 1, new AttributeList.unpack('*0',pool), '')));
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
  
    test('trim', () {
      var c = new OpComponent('+', 5, 2, null, 'ab\nc\n');
      expect(c.clone()..trimLeft(3, 1), equals(new OpComponent('+', 2, 1, null, 'c\n')));
      expect(c.clone()..trimRight(3, 1), equals(new OpComponent('+', 3, 1, null, 'ab\n')));
    });
  
    group('invert', () {
      testInvert(name, opcode, atts, expectedOpcode, expectedAtts) {
        test(name, () {
          atts = new AttributeList.unpack(atts, [['foo','bar']]);
          expectedAtts = new AttributeList.unpack(expectedAtts, [['foo','bar']]);
          var c = new OpComponent(opcode, 1, 0, atts, 'a').inverted();
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
        expect(c.clone()..append(c), equals(new OpComponent('+', 6, 2, alist, 'ab\nab\n')));
      });
      test('to empty', () {
        expect(new OpComponent()..append(c), equals(c));
      });
      test('throw if not compatible', () {
        expect(() {
            var c2 = c.clone()
                ..opcode = '=';
            c.clone()..append(c2);
          }, throwsA(errMatcher('cannot append')));
        expect(() {
            var c2 = c.clone()
              ..attribs = new AttributeList.unpack('*0', [['x', 'y']]);
            c.clone()..append(c2);
          }, throwsA(errMatcher('cannot append')));
      });
      test('skip no-ops', () {
        expect(c.clone()..append(new OpComponent()), equals(c));
      });
    });

    test('takeLine', () {
      var c = new OpComponent('+', 4, 2, null, 'a\nb\n');
      expect(c.takeLine(), equals(new OpComponent('+', 2, 1, null, 'a\n')));
      expect(c.takeLine(), equals(new OpComponent('+', 2, 1, null, 'b\n')));
      expect(c, equals(new OpComponent('', 0, 0, null, '')));
    });

    test('pack', () {
      var pool = [['foo','bar'], ['x','y']];
      var c = new OpComponent('+', 10, 2, new AttributeList.unpack('*0*1', pool), '1234\n6789\n');
      expect(c.pack(pool), equals(new AString(atts: '*0*1|2+a', text: '1234\n6789\n')));
    });

    test('skip', () {
      var c = new OpComponent('+', 4, 2, null, 'a\nb\n');
      var c2 = new OpComponent();
      c.copyTo(c2).skip();
      expect(c2.opcode, equals(''));
      expect(c2.isEmpty, equals(true));

      c.copyTo(c2).skipIfEmpty();
      expect(c2, equals(c));

      c.copyTo(c2)
        ..trimRight(0, 0)
        ..skipIfEmpty();
      expect(c2, equals(new OpComponent('', 0, 0, null, '')));
    });
  });
}