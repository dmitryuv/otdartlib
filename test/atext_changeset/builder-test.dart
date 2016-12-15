part of otdartlib.test.atext_changeset;

builder_test() {
  alist(List atts) {
    var rmv = new Map.fromIterable(atts.where((l) => l[0] == '^'), key: (l) => l[1], value: (l) => l[2]);
    var fmt = new Map.fromIterable(atts.where((l) => l[0] == '*'), key: (l) => l[1], value: (l) => l[2]);        
    return new AttributeList.fromMap(remove: rmv, format: fmt);
  }
  
  group('Builder', () {
    var pool = [['foo','bar'], ['author','x'], ['bold','true'], ['list', 1], ['italic', 'true']];
    var sample = [{'a':'*0+1|1+3', 's':'abc\n'}, {'a':'*1+4|1+1', 's':'defg\n'}];
    var doc = new ADocument.unpack({'lines': sample, 'pool': pool});
  
    group('format', () {
      testFormat(String name, String funcName, int posX, int posY, int lenX, int lenY, List list, String author, String expected, [List expectedAtts]) {
        test(name, () {
          var cs = Changeset.create(doc, author: author)
            ..keep(posX, posY);
          if(funcName == 'format') {
            cs.format(lenX, lenY, alist(list));
          } else {
            cs.removeAllFormat(lenX, lenY);
          }
          var packed = cs.finish().pack();

          expect(packed['op'], equals(expected));
          if(expectedAtts != null) {
            expect(packed['p'], equals(expectedAtts));
          }
        });
      }
      testFormat('add attribute', 'format', 4, 1, 2, 0, [['*', 'bold', 'true']], null, 'X:9>0|1=4*0=2');
      testFormat('remove not existing attribute -> noop', 'format', 4, 1, 2, 0, [['^', 'bold', 'true']], null, 'X:9>0');
      testFormat('remove existing attribute', 'format', 4, 1, 2, 0, [['^', 'author', 'x']], null, 'X:9>0|1=4^0=2');
      testFormat('inject author, removing old one', 'format', 4, 1, 2, 0, [['*', 'italic', 'true']], 'tester', 'X:9>0|1=4^0*1*2=2');
      testFormat('ignore existing attributes', 'format', 4, 1, 2, 0, [['*', 'italic', 'true']], 'x', 'X:9>0|1=4*0=2');
      testFormat('format over different ops', 'format', 0, 0, 9, 2, [['*', 'italic', 'true']], null, 'X:9>0*0|2=9');
      testFormat('ignore attempt to push author via attribs', 'format', 4, 1, 2, 0, ['author', 'ignored'], 'tester', 'X:9>0|1=4^0*1=2', [['author', 'x'], ['author', 'tester']]);
      testFormat('remove all format', 'removeAllFormat', 4, 1, 2, 0, [], null, 'X:9>0|1=4^0=2');
      testFormat('remove all format but inject author', 'removeAllFormat', 4, 1, 2, 0, [], 'tester', 'X:9>0|1=4^0*1=2');
    });
  
    group('insert', () {
      testInsert(name, posX, posY, text, atts, author, expected) {
        test(name, () {
          var cs = Changeset.create(doc, author: author)
            ..keep(posX, posY)
            ..insert(text, alist(atts));
          var packed = cs.finish().pack();
  
          expect(packed['op'], equals(expected));
        });
      }
  
      testInsert('simple insert', 0, 0, 'hello', [], null, r'X:9>5+5$hello');
      testInsert('simple insert with author and attribs', 0, 0, 'hello', [['*', 'bold', 'true']], 'tester', r'X:9>5*0*1+5$hello');
      testInsert('insert multiline text mid line', 2, 0, 'hello\nworld\n', [], null, 'X:9>c=2|2+c\$hello\nworld\n');
      testInsert('insert multiline with tail and author', 2, 0, 'hello\nworld', [], 'tester', 'X:9>b=2*0|1+6*0+5\$hello\nworld');
    });
  
    group('remove', () {
      testRemove(name, posX, posY, N, L, author, expected) {
        test(name, () {
          var cs = Changeset.create(doc, author: author)
            ..keep(posX, posY)
            ..remove(N, L);
          
          var packed = cs.finish().pack();
  
          expect(packed['op'], equals(expected));
        });
      }
  
      testRemove('simple remove', 0, 0, 2, 0, null, r'X:9<2*0-1-1$ab');
      testRemove('remove all', 0, 0, 9, 2, null, 'X:9<9*0-1|1-3*1-4|1-1\$abc\ndefg\n');
    });
  });
}