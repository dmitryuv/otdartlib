part of otdartlib.test.atext_changeset;

void astringMutator_test() {
  var errMatcher = (msg) => predicate((Exception e) => new RegExp(msg).hasMatch(e.toString()));
    
  group('AStringMutator', () {
    var pool = [['foo','bar'], ['author','x'], ['bold','true'], ['list', 1], ['italic', true]];
    var sample = new AString(atts: '*0+2*1+4*2+6', text: 'abcdefghijkl' );
    var empty = new AString(atts: '', text: '');
    
    ComponentList clist(List list) {
      return new ComponentList()..addAll(list.map((item) =>
          new OpComponent(item[0], item[1], item[2], new AttributeList.unpack(item[3], pool), item[4]))
      );
    }
  
    test('does not fail on empty strings', () {
      var m = new AStringMutator(empty.clone(), pool);
      expect(m.takeRemaining(), equals(clist([])));
      expect(m.isMutated, equals(false));
    });
  
    test('can build line from scratch', () {
      var m = new AStringMutator(empty.clone(), pool);
      new AStringMutator(sample.clone(), pool).takeRemaining().forEach((c) => m.insert(c));
      expect(m.finish(), equals(sample));
    });
  
    test('return injected component', () {
      var m = new AStringMutator(sample.clone(), pool);
      m.inject(new OpComponent(OpComponent.INSERT, 2, 0, new AttributeList(), 'XX'));
      expect(m.take(3), equals(clist([['+',2,0,null,'XX'],['+',1,0,'*0','a']])));
    });
  
    test('supports newline at the end', () {
      var m = new AStringMutator(new AString(atts: '*0+4|1+1', text: 'abcd\n' ), pool);
      expect(m.takeRemaining(), equals(clist([['+',4,0,'*0','abcd'],['+',1,1,null,'\n']])));
    });
  
    test('can decompose into subcomponents', () {
      var m = new AStringMutator(sample.clone(), pool)
        ..skip(1);
      var c = m.take(2);
      expect(c, equals(clist([['+',1,0,'*0','b'],['+',1,0,'*1','c']])));
  
      c = m.take(1);
      expect(c, equals(clist([['+',1,0,'*1','d']])));
  
      c = m.takeRemaining();
      expect(c, equals(clist([['+',2,0,'*1','ef'],['+',6,0,'*2','ghijkl']])));
  
      expect(m.isMutated, false);
    });
  
    test('can merge inserts', () {
      var m = new AStringMutator(sample.clone(), pool)
        ..skip(3)
        ..insert(new OpComponent('+', 2, 0, new AttributeList.unpack('*1', pool), 'XX'));
  
      expect(m.isMutated, equals(true));
      expect(m.finish(), equals(new AString(atts: '*0+2*1+6*2+6', text: 'abcXXdefghijkl' )));
    });

    test('can do removes', () {
      var m = new AStringMutator(sample.clone(), pool)
        ..skip(1);
      var removed = m.remove(2);
  
      expect(removed, equals(clist([['+', 1, 0, '*0', 'b'], ['+', 1, 0, '*1', 'c']])));
      expect(m.finish(), new AString( atts: '*0+1*1+3*2+6', text: 'adefghijkl' ));
    });
  
    test('accept single newline only at the end of the string', () {
      var m = new AStringMutator(new AString(atts:'+2', text:'ab'), pool);
      var op = new OpComponent('+', 2, 1, new AttributeList(), 'X\n');
  
      expect(() {
        m.insert(op);
      }, throwsA(errMatcher('end of the string')));
  
      m.skip(m.remaining);
  
      expect(() {
        m.insert(new OpComponent('+', 4, 2, new AttributeList(), 'a\nb\n'));
      }, throwsA(errMatcher('end of the string')));
  
      m.insert(op);
      expect(m.finish(), new AString(atts:'|1+4', text:'abX\n'));
  
      expect(() {
        m.insert(op);
      }, throwsA(errMatcher('already have newline')));
    });
  
    test('format string', () {
      var fop = new OpComponent.createFormat(4, 0, new AttributeList.unpack('*4', pool));
      var m = new AStringMutator(sample.clone(), pool)
        ..skip(3)
        ..applyFormat(fop);
  
      expect(m.finish(), new AString(atts: '*0+2*1+1*1*4+3*2*4+1*2+5', text: 'abcdefghijkl'));
      expect(m.isMutated, equals(true));
    });
  
    test('can do complex changes', () {
      var m = new AStringMutator(sample.clone(), pool);
      var removed = m.remove(3);
      expect(removed, equals(clist([['+', 2, 0, '*0', 'ab'], ['+', 1, 0, '*1', 'c']])));
  
      m.insert(new OpComponent('+', 4, 0, new AttributeList.unpack('*3', pool), 'XXXX'));
      m.skip(4);
      removed = m.remove(1);
      expect(removed, equals(clist([['+', 1, 0, '*2', 'h']])));
      // skip to the end
      m.skip(m.remaining);
      m.insert(new OpComponent('+', 3, 0, new AttributeList.unpack('*4', pool), 'YYY'));
  
      expect(m.finish(), new AString(atts: '*3+4*1+3*2+5*4+3', text: 'XXXXdefgijklYYY'));
    });
  
    test('throws on invalid operations', () {
      expect(() {
        new AStringMutator(sample.clone(), pool)
          ..skip(100)
          ..remove(1);
      }, throwsA(errMatcher('unexpected end')));
  
      expect(() {
        new AStringMutator(sample.clone(), pool)
          ..insert(new OpComponent('-', 0, 0, new AttributeList(), ''));
      }, throwsA(errMatcher('bad opcode')));
  
      expect(() {
        new AStringMutator(new AString(atts: '-2', text: 'xx'), pool)
          ..take(1);
      }, throwsA(errMatcher('non-astring')));
  
      expect(() {
        new AStringMutator(new AString(atts: '*0|1+1*1+2|1+1', text: '\nab\n'), pool)
          ..takeRemaining();
      }, throwsA(errMatcher('non-astring')));
    });
  });
}