part of otdartlib.test.atext_changeset;


void changeset_test() {
  clone(obj) {
    return JSON.decode(JSON.encode(obj));
  }

  var errMatcher = (msg) => predicate((Exception e) => new RegExp(msg).hasMatch(e.toString()));
  
  group('Changeset', () {
    var sampleLines = [{'a': '*0+2|1+2', 's': 'abc\n'}, { 'a': '+4*1|1+2', 's': 'defgh\n'} ];
    var samplePool = [['author', 'x'], ['bold', true], ['italic', true], ['author','y']];
    
    getDoc() {
      return new ADocument.unpack(clone({ 'lines': sampleLines, 'pool': samplePool}));
    }
  
    group('applyTo', () {
      apply(name, cs, expected, [err, doc]) {
        test(name, () {
          if (doc == null) doc = getDoc();
          if(err != null) {
            expect(() => new Changeset.unpack(cs)..applyTo(doc), throwsA(errMatcher(err)));
          }
          else {
            new Changeset.unpack(cs)..applyTo(doc);
            expect(doc.pack()['lines'], expected);
          }
        });
      }
  
      // we test most of the mutation procedures in the ALinesMutator-tests
      apply('complex mutation with formatting',
        {'op': 'X:a>1=1^3*0=1*0|1=2*1=4*2|1-2*1|1+3\$h\nij\n', 'p': [['italic', true], ['author', 'y'], ['bold', true], ['author', 'x']], 'u': 'y'},
        [{'a': '*0+1*2|1+3', 's': 'abc\n'}, {'a': '*3|1+7', 's': 'defgij\n'}]
        );
  
      apply('throws if removed does not match actual', 
        {'op': 'X:a<1=1-1\$b', 'p': [], 'u': 'y'},
        null,
        'not match removed'
        );
    });
  
    group('invert', () {
      test('can invert complex mutation', () {
        var newDoc = getDoc();
        var cs = new Changeset.unpack({'op': 'X:a>1=1^3*0=1*0|1=2*1=4*2|1-2*1|1+3\$h\nij\n', 'p': [['italic', true], ['author', 'y'], ['bold', true], ['author', 'x']], 'u': 'y'})
          ..applyTo(newDoc);
        
        var inv = cs.invert();
  
        expect(inv.pack(), equals({ 'op': 'X:b<1=1^0*1=1^0|1=2^2=4*2|1-3*3|1+2\$ij\nh\n',  'p': [['italic', true], ['author', 'x'], ['author', 'y'], ['bold', true]], 'u': 'y' }));
  
        inv.applyTo(newDoc);
        expect(newDoc.pack(), equals(getDoc().pack()));
      });
    });
  
    group('compose', () {
      compose(name, cs1, cs2, res, [err]) {
        test(name, () {
          cs1 = new Changeset.unpack({'op': cs1, 'p': samplePool});
          cs2 = new Changeset.unpack({'op': cs2, 'p': samplePool});
          if(err != null) {
            expect(() => cs1.compose(cs2), throwsA(errMatcher(err)));
          } else {
            expect(cs1.compose(cs2).pack(samplePool)['op'], equals(res));
          }
        });
      }
  
      compose('simple', 'X:0>3+3\$abc', 'X:3>3=3+3\$def', 'X:0>6+6\$abcdef');
      compose('with newline', 'X:0>2+2\$ab', 'X:2>1|1+1\$\n', 'X:0>3|1+1+2\$\nab');
      compose('delete inserted', 'X:0>3+3\$abc', 'X:3<1=1-1\$b', 'X:0>2+2\$ac');
      compose('delete from format', 'X:3>0*0=3', 'X:3<1=1*0-1\$b', 'X:3<1*0=1-1*0=1\$b');
      compose('delete from unformat', 'X:3>0^0=3', 'X:3<1=1-1\$b', 'X:3<1^0=1*0-1^0=1\$b');
      compose('delete inserted and insert new', 'X:0>3+3\$abc', 'X:3<1-2+1\$abd', 'X:0>2+2\$dc');
//       test zip slicer
      compose('delete big + delete small with lines', 'X:8<4-4\$abcd', 'X:4<2|2-2\$\n\n', 'X:8<6|2-6\$abcd\n\n');
      compose('reformat string', 'X:0>4*0+2*1+2\$abcd', 'X:4>0*1=1*2=2*0=1', 'X:0>4*0*1+1*0*2+1*1*2+1*0*1+1\$abcd');
      compose('throw on removal not match', 'X:0>3+3\$abc', 'X:3<1=1-1\$c', null, 'not match');
      compose('throw on versions not match', 'X:0>3+3\$abc', 'X:4>1+1\$c', null, 'not composable');

      compose('format and then remove chars', 'X:4>0*0=2', 'X:4<2*0*1-2\$ab', 'X:4<2*1-2\$ab');
      compose('remove format and then remove chars', 'X:4>0^0=2', 'X:4<2*1-2\$ab', 'X:4<2*0*1-2\$ab');
      compose('complete remove & insert, tests split components', 'X:3<3|1-3\$12\n', 'X:0>2+2\$XY', 'X:3<1|1-3+2\$12\nXY');

      compose('compose with out of bounds insert', 'X:2>1+1\$a', 'X:3>1=3+1\$b', 'X:2>2+1=2+1\$ab');
      compose('remove char past changeset bounds', 'X:4>0*0=2', 'X:4<1=3-1\$a', 'X:4<1*0=2=1-1\$a');
      compose('remove overflows removed', 'X:6<1=3-1\$b', 'X:5<2=2-2\$ac', 'X:6<3=2-3\$abc');
    });


    group('transform', () {
      transform(name, cs1, cs2, side, res, [err]) {
        test(name, () {
          cs1 = new Changeset.unpack({'op': cs1, 'p': samplePool});
          cs2 = new Changeset.unpack({'op': cs2, 'p': samplePool});
          if(err != null) {
            expect(() => cs1.transform(cs2, side), throwsA(errMatcher(err)));
          } else {
            if(res is String) {
              expect(cs1.transform(cs2, side).pack(samplePool)['op'], equals(res));
            } else {
              expect(cs1.transform(cs2, side), res);
            }
          }
        });
      }
  
      transform('insert tie break left', 'X:0>2+2\$ab', 'X:0>2+2\$cd', 'left', 'X:2>2=2+2\$ab');
      transform('insert tie break right', 'X:0>2+2\$cd', 'X:0>2+2\$ab', 'right', 'X:2>2+2\$cd');
      transform('insert tie break by newline', 'X:0>2+2\$ab', 'X:0>1|1+1\$\n', 'left', 'X:1>2+2\$ab');
      transform('insert tie break by newline left op', 'X:0>1|1+1\$\n', 'X:0>2+2\$ab', 'left', 'X:2>1=2|1+1\$\n');
      transform('insert tie break by newline (no affect of side=right)', 'X:0>2+2\$ab', 'X:0>1|1+1\$\n', 'right', 'X:1>2+2\$ab');
      transform('insert tie break by newline left op (no affect of side=right)', 'X:0>1|1+1\$\n', 'X:0>2+2\$ab', 'right', 'X:2>1=2|1+1\$\n');
      transform('insert tie break left when both newlines', 'X:0>2|1+1+1\$\na', 'X:0>2|1+1+1\$\nb', 'left', 'X:2>2|1=1=1|1+1+1\$\na');
      transform('insert tie break right when both newlines', 'X:0>2|1+1+1\$\nb', 'X:0>2|1+1+1\$\na', 'right', 'X:2>2|1+1+1\$\nb');
      transform('tie break when one of the ops is insert', 'X:2>1+1\$a', 'X:2<1-1\$b', 'left', 'X:1>1+1\$a');
      transform('tie break when one of the ops is insert (no affect of side=right)', 'X:2>1+1\$a', 'X:2<1-1\$b', 'right', 'X:1>1+1\$a');
      transform('insert false-tie by multi insert with newline', 'X:0>1+1\$a', 'X:0>2*0+1*1|1+1\$b\n', 'left', 'X:2>1=1+1\$a');
      transform('insert false-tie by multi insert with newline (right)', 'X:0>1+1\$a', 'X:0>2*0+1*1|1+1\$b\n', 'right', 'X:2>1+1\$a');
      transform('insert false-tie by multi insert with newline left op', 'X:0>2*0+1*1|1+1\$b\n', 'X:0>1+1\$a', 'left', 'X:1>2=1*0+1*1|1+1\$b\n');
      transform('insert false-tie by multi insert with newline left op (right)', 'X:0>2*0+1*1|1+1\$b\n', 'X:0>1+1\$a', 'right', 'X:1>2*0+1=1*1|1+1\$b\n');

      transform('remove when part was removed', 'X:8<4-4\$abcd', 'X:8<2-2\$ab', 'left', 'X:6<2-2\$cd');
      transform('remove part when all was removed', 'X:8<2-2\$ab', 'X:8<4-4\$abcd', 'left', 'X:4>0');
      transform('remove from other keep', 'X:8<2-2\$ab', 'X:8>0*0=4', 'left', 'X:8<2*0-2\$ab');
      transform('keep affected by remove', 'X:8>2=8+2\$ab', 'X:8<4-4\$abcd', 'left', 'X:4>2=4+2\$ab');
      transform('keep collapsed by remove', 'X:8>2=4+2\$ab', 'X:8<6-6\$abcdef', 'left', 'X:2>2+2\$ab');
      transform('keep moved by bigger insert', 'X:4>1|1=4+1\$a', 'X:4>5+5\$bcdef', 'left', 'X:9>1|1=9+1\$a');
      transform('longer op should not inject bad keeps into transformed op', 'X:4>1=1-2+3\$abcde', 'X:4>4=4|1+4\$qwe\n', 'left', 'X:8>1=1-2+3\$abcde');

      transform('both keeps', 'X:4>0*0*1=4', 'X:4>0=2*2*3=2', 'left', 'X:4>0*0*1=2^3*0*1=2');
      transform('push formatting op by insert', 'X:2>1^0*3=2+1\$a', 'X:2>4*0+4\$abcd', 'left', 'X:6>1=4^0*3=2+1\$a');
      transform('split formatting by insert', 'X:4>0*0=4', 'X:4>2=2*1+2\$ab', 'left', 'X:6>0*0=2=2*0=2');

      transform('remove what was reformatted', 'X:2<2*0*1-2\$ab', 'X:2>0^0*2*3=2', 'left', 'X:2<2*3*1*2-2\$ab');
    });
  });
}