part of otdartlib.test.atext_changeset;

void componentList_test() {
  clone(obj) {
    return JSON.decode(JSON.encode(obj));
  }
  
  var errMatcher = (msg) => predicate((Exception e) => new RegExp(msg).hasMatch(e.toString()));
  
  group('ComponentList', (){
    var unpacked = new AString( 
        atts: '-c*3*4+6|3=a^1^3*2*5+1=1-1+1*0+1=1-1+1|c=c=2*0|2=2-1=3+1',
        text: '12345678901212345611111111'
      );
    var unpackedPool = [
      ['author', '1'],
      ['bold','true'],
      ['color', '#333'],
      ['foo', 'bar'],
      ['list', '1'],
      ['underline','true']
      ];
  
  
    test('test unpack & repack with old pool', () {
      var ops = new ComponentList.unpack(unpacked, unpackedPool);
      var res = ops.toAString(clone(unpackedPool));
  
      expect(res.atts, equals(unpacked.atts));
      expect(res.text, equals(unpacked.text));
      expect(res.dLen, equals(-4));
      expect(res.pool, equals(unpackedPool));
    });
  
    test('test unpack & repack with new pool', () {
      var ops = new ComponentList.unpack(unpacked, unpackedPool);
      var res = ops.toAString();
  
      // pool will be rebuilt with new indexes
      expect(res.atts, equals('-c*0*1+6|3=a^2^0*3*4+1=1-1+1*5+1=1-1+1|c=c=2*5|2=2-1=3+1'));
      expect(res.text, equals(unpacked.text));
      expect(res.dLen, equals(-4));
      expect(res.pool, equals([
        ['foo', 'bar'],
        ['list', '1'],
        ['bold','true'],
        ['color', '#333'],
        ['underline', 'true'],
        ['author', '1']
        ]));
    });
  
    test('throws on incomplete charBank', () {
      var test = new AString(atts: unpacked.atts, text: '1234');

      expect(() => new ComponentList.unpack(test, unpackedPool), throwsA(isRangeError));
    });

    testPack(name, ops, String res, lenChange) {
      var pool = [['foo','bar'], ['zoo','moo']];
      test(name, () {
        ops = ops.map((o) { 
          var a = new AttributeList.unpack(o[3], pool);
          return new OpComponent(o[0], o[1], o[2], a, o[4]);
        });
        var list = new ComponentList()..addAll(ops);
  
        var parts = res.split(r'$').toList();
        var packed = list.toAString(pool);
        expect(packed, equals(new AString(atts: parts[0], text: parts.sublist(1).join(r'$'))));
        expect(packed.dLen, equals(lenChange));
      });
    }
  
    testPack('can merge inline ops', [['+', 1, 0, '*0', 'a'], ['+', 2, 0, '*0', 'bc']], r'*0+3$abc', 3);
    testPack('don\'t merge on different attribs', [['+', 1, 0, '*1', 'a'], ['+', 2, 0, '*0', 'bc']], r'*1+1*0+2$abc', 3);
    testPack('don\'t merge on different opcodes', [['-', 1, 0, '*0', 'a'], ['+', 2, 0, '*0', 'bc']], r'*0-1*0+2$abc', 1);
    testPack('merge multiline and inline ops', [['+', 1, 0, '*0', 'a'], ['+', 2, 1, '*0', 'b\n'], ['+', 2, 1, '*0', 'c\n'], ['+', 2, 0, '*0', 'de']], '*0|2+5*0+2\$ab\nc\nde', 7);
    testPack('drop trailing pure "keep"', [['+', 1, 0, '*0', 'a'], ['=', 2, 0, '', '']], r'*0+1$a', 1);
    testPack('keep formatting trailing "keep"', [['+', 1, 0, '*0', 'a'], ['=', 2, 0, '*1', '']], r'*0+1*1=2$a', 1);
  
    testPack('smart: put removes before inserts', [['+', 2, 0, '', 'ab'],['-', 2, 0, '', 'cd']], r'-2+2$cdab', 0);
    testPack('smart: split by keep operation', [['+', 2, 0, '', 'ab'],['=', 2, 0, '', ''],['-', 2, 0, '', 'cd']], r'+2=2-2$abcd', 0);
    testPack('smart: remove final pure keeps', [['+', 2, 0, '', 'ab'],['=', 2, 0, '', '']], r'+2$ab', 2);
  
    test('invert components', () {
      var list = new ComponentList.from(new ComponentList.unpack(unpacked, unpackedPool).inverted);
      var res = list.toAString(unpackedPool);
      expect(res.atts, equals('*3*4-6+c|3=a^1^3*2*5-1=1-1*0-1+1=1-1+1|c=c=2^0|2=2+1=3-1'));
      expect(res.text, equals('12345612345678901211111111'));
    });
  
    test('test reorder', () {
      test(ops, res) {
        ops = ops.map((o) {
          return new OpComponent(o, 1, 0, null, 'x');
        });

        var list = new ComponentList()
          ..addAll(ops)
          ..sort();
        var codes = list.map((c) => c.opcode);
        
        expect(codes, equals(res));
      }
      test(['+','-','='], ['-','+','=']);
      test(['+','=','-','+','-','+','-'],['+','=','-','-','-','+','+']);
    });
  });
}