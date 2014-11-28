part of otdartlib.test.ottypes;

void json0_test() {
  clone(obj) => JSON.decode(JSON.encode(obj));
  var errMatcher = (msg) => predicate((Exception e) => new RegExp(msg).hasMatch(e.toString()));

  var json0 = new OT_json0();
  OT_json0.registerSubtype(new OT_text0());
  
  group('json0', () {
    group('sanity', () {
      group('#create()', () => test('returns null', () => expect(json0.create(), equals(null))));
      
      group('#invert()', () {
        test('optional insert inverts to delete', () =>
          expect(json0.invert([{'p':['foo'], 'oin':1}]), equals([{'p':['foo'], 'od':1}])));
      });

      group('#compose()', () {
        test('od, oi -() { od+oi', () {
          expect(json0.compose([{'p':['foo'],'od':1}],[{'p':['foo'],'oi':2}]), equals([{'p':['foo'], 'od':1, 'oi':2}]));
          expect(json0.compose([{'p':['foo'],'od':1}],[{'p':['bar'],'oi':2}]), equals([{'p':['foo'], 'od':1},{'p':['bar'], 'oi':2}]));
        });
        test('merges od+oi, od+oi () { od+oi', () =>
          expect(json0.compose([{'p':['foo'],'od':1,'oi':3}],[{'p':['foo'],'od':3,'oi':2}]), equals([{'p':['foo'], 'od':1, 'oi':2}])));
        test('oi,oin -> oi', () =>
          expect(json0.compose([{'p':['foo'],'oi':1}],[{'p':['foo'],'oin':2}]), equals([{'p':['foo'], 'oi':1}])));
        test('oin,oin` -> oin', () =>
          expect(json0.compose([{'p':['foo'],'oin':1}],[{'p':['foo'],'oin':2}]), equals([{'p':['foo'], 'oin':1}])));
        test('od,oin -> od+oi', () =>
          expect(json0.compose([{'p':['foo'],'od':1}],[{'p':['foo'],'oin':2}]), equals([{'p':['foo'], 'od':1, 'oi':2}])));
        test('od+oi,oin -> od+oi', () =>
          expect(json0.compose([{'p':['foo'],'od':1,'oi':3}],[{'p':['foo'],'oin':2}]), equals([{'p':['foo'], 'od':1, 'oi':3}])));
      });
      
      // Strings should be handled internally by the text type. We'll just do some basic sanity checks here.
      group('string subtype', () {
        group('#apply()', () {
          test('works', () {
            expect(json0.apply('a', [{'p':[], 't':'text0', 'o':[{'p':1, 'i':'bc'}]}]), equals('abc'));
            expect(json0.apply('abc', [{'p':[], 't':'text0', 'o':[{'p':0, 'd':'a'}]}]), equals('bc'));
            expect(json0.apply({'x':'a'}, [{'p':['x'], 't':'text0', 'o':[{'p':1, 'i':'bc'}]}]), equals({'x':'abc'}));
          });
        });
      });

      group('#transform()', () {
        test('returns sane values', () {
          t(op1, op2) {
            expect(json0.transform(op1, op2, 'left'), equals(op1));
            expect(json0.transform(op1, op2, 'right'), equals(op1));
          }
    
          t([], []);
          t([{'p':['foo'], 'oi':1}], []);
          t([{'p':['foo'], 'oi':1}], [{'p':['bar'], 'oi':2}]);
        });
      });
    });
    
    group('number', () {
      test('Adds a number', () {
        expect(json0.apply(1, [{'p':[], 'na':2}]), equals(3));
        expect(json0.apply([1], [{'p':[0], 'na':2}]), equals([3]));
      });

      test('compresses two adds together in compose', () {
        expect(json0.compose([{'p':['a', 'b'], 'na':1}], [{'p':['a', 'b'], 'na':2}]), equals([{'p':['a', 'b'], 'na':3}]));
        expect(json0.compose([{'p':['a'], 'na':1}], [{'p':['b'], 'na':2}]), equals([{'p':['a'], 'na':1}, {'p':['b'], 'na':2}]));
      });
  
      test('doesn\'t overwrite values when it merges na in append', () {
        var rightHas = 21;
        var leftHas = 3;
  
        var rightOp = [{"p":[],"od":0,"oi":15},{"p":[],"na":4},{"p":[],"na":1},{"p":[],"na":1}];
        var leftOp = [{"p":[],"na":4},{"p":[],"na":-1}];
        var r_l = json0.transformX(rightOp, leftOp);
  
        var s_c = json0.apply(rightHas, r_l[1]);
        var c_s = json0.apply(leftHas, r_l[0]);
        expect(s_c, equals(c_s));
      }); 
    });
  

    group('list', () {
      group('apply', () {
        test('inserts', () {
          expect(json0.apply(['b', 'c'], [{'p':[0], 'li':'a'}]), equals(['a', 'b', 'c']));
          expect(json0.apply(['a', 'c'], [{'p':[1], 'li':'b'}]), equals(['a', 'b', 'c']));
          expect(json0.apply(['a', 'b'], [{'p':[2], 'li':'c'}]), equals(['a', 'b', 'c']));
        });
  
        test('deletes', () {
          expect(json0.apply(['a', 'b', 'c'], [{'p':[0], 'ld':'a'}]), equals(['b', 'c']));
          expect(json0.apply(['a', 'b', 'c'], [{'p':[1], 'ld':'b'}]), equals(['a', 'c']));
          expect(json0.apply(['a', 'b', 'c'], [{'p':[2], 'ld':'c'}]), equals(['a', 'b']));
          
          expect(() { 
            expect(json0.apply(['a', 'b', 'c'], [{'p':[2], 'ld':'y'}]), equals(['a', 'b']));
          }, throwsA(errMatcher('does not match')));
        });
  
        test('replaces', () {
          expect(json0.apply(['a', 'x', 'b'], [{'p':[1], 'ld':'x', 'li':'y'}]), equals(['a', 'y', 'b']));
          
          expect(() { 
            expect(json0.apply(['a', 'x', 'b'], [{'p':[1], 'ld':'z', 'li':'y'}]), equals(['a', 'y', 'b']));
          }, throwsA(errMatcher('does not match')));
        });
  
        test('moves', () {
          expect(json0.apply(['b', 'a', 'c'], [{'p':[1], 'lm':0}]), equals(['a', 'b', 'c']));
        });
      });

      group('#transform()', () {
        test('bumps paths when list elements are inserted or removed', () {
          expect(json0.transform([{'p':[1, 200], 'na': 2}], [{'p':[0], 'li':'x'}], 'left'), equals([{'p':[2, 200], 'na': 2}]));
          expect(json0.transform([{'p':[0, 201], 'na': 2}], [{'p':[0], 'li':'x'}], 'right'), equals([{'p':[1, 201], 'na': 2}]));
          expect(json0.transform([{'p':[0, 202], 'na': 2}], [{'p':[1], 'li':'x'}], 'left'), equals([{'p':[0, 202], 'na': 2}]));

          expect(json0.transform([{'p':[1], 't':'text0', 'o':[{'p':200, 'i':'hi'}]}], [{'p':[0], 'li':'x'}], 'left'), equals([{'p':[2], 't':'text0', 'o':[{'p':200, 'i':'hi'}]}]));
          expect(json0.transform([{'p':[0], 't':'text0', 'o':[{'p':201, 'i':'hi'}]}], [{'p':[0], 'li':'x'}], 'right'), equals([{'p':[1], 't':'text0', 'o':[{'p':201, 'i':'hi'}]}]));
          expect(json0.transform([{'p':[0], 't':'text0', 'o':[{'p':202, 'i':'hi'}]}], [{'p':[1], 'li':'x'}], 'left'), equals([{'p':[0], 't':'text0', 'o':[{'p':202, 'i':'hi'}]}]));
  
          expect(json0.transform([{'p':[1, 203], 'na': 2}], [{'p':[0], 'ld':'x'}], 'left'), equals([{'p':[0, 203], 'na': 2}]));
          expect(json0.transform([{'p':[0, 204], 'na': 2}], [{'p':[1], 'ld':'x'}], 'left'), equals([{'p':[0, 204], 'na': 2}]));
          expect(json0.transform([{'p':['x',3], 'na': 2}], [{'p':['x',0,'x'], 'li':0}], 'left'), equals([{'p':['x',3], 'na': 2}]));
          expect(json0.transform([{'p':['x',3,'x'], 'na': 2}], [{'p':['x',5], 'li':0}], 'left'), equals([{'p':['x',3,'x'], 'na': 2}]));
          expect(json0.transform([{'p':['x',3,'x'], 'na': 2}], [{'p':['x',0], 'li':0}], 'left'), equals([{'p':['x',4,'x'], 'na': 2}]));

          expect(json0.transform([{'p':[1], 't':'text0', 'o':[{'p':203, 'i':'hi'}]}], [{'p':[0], 'ld':'x'}], 'left'), equals([{'p':[0], 't':'text0', 'o':[{'p':203, 'i':'hi'}]}]));
          expect(json0.transform([{'p':[0], 't':'text0', 'o':[{'p':204, 'i':'hi'}]}], [{'p':[1], 'ld':'x'}], 'left'), equals([{'p':[0], 't':'text0', 'o':[{'p':204, 'i':'hi'}]}]));
          expect(json0.transform([{'p':['x'], 't':'text0', 'o':[{'p':3, 'i':'hi'}]}], [{'p':['x',0,'x'], 'li':0}], 'left'), equals([{'p':['x'], 't':'text0', 'o':[{'p':3,'i': 'hi'}]}]));
  
          expect(json0.transform([{'p':[0],'ld':2}], [{'p':[0],'li':1}], 'left'), equals([{'p':[1],'ld':2}]));
          expect(json0.transform([{'p':[0],'ld':2}], [{'p':[0],'li':1}], 'right'), equals([{'p':[1],'ld':2}]));
        });
          
        test('converts ops on deleted elements to noops', () {
          expect(json0.transform([{'p':[1, 0], 'na': 2}], [{'p':[1], 'ld':0}], 'left'), equals([]));
          expect(json0.transform([{'p':[1], 't':'text0', 'o':[{'p':0, 'i':'hi'}]}], [{'p':[1], 'ld':'x'}], 'left'), equals([]));
          expect(json0.transform([{'p':[0],'li':'x'}], [{'p':[0],'ld':'y'}], 'left'), equals([{'p':[0],'li':'x'}]));
          expect(json0.transform([{'p':[0],'na':-3}], [{'p':[0],'ld':48}], 'left'), equals([]));
        });
  
        test('converts ops on replaced elements to noops', () {
          expect(json0.transform([{'p':[1, 0], 'na': 2}], [{'p':[1], 'ld':'x', 'li':'y'}], 'left'), equals([]));
          expect(json0.transform([{'p':[1], 't':'text0', 'o':[{'p':0, 'i':'hi'}]}], [{'p':[1], 'ld':'x', 'li':'y'}], 'left'), equals([]));
          expect(json0.transform([{'p':[0], 'li':'hi'}], [{'p':[0], 'ld':'x', 'li':'y'}], 'left'), equals([{'p':[0], 'li':'hi'}]));
        });
  
        test('changes deleted data to reflect edits', () {
  //          expect(json0.transform([{'p':[1], 'ld':'a'}], [{'p':[1, 1], 'si':'bc'}], 'left'), equals([{'p':[1], 'ld':'abc'}]));
          expect(json0.transform([{'p':[1], 'ld':'a'}], [{'p':[1], 't':'text0', 'o':[{'p':1, 'i':'bc'}]}], 'left'), equals([{'p':[1], 'ld':'abc'}]));
          expect(json0.transform([{'p':[1], 'ld':2}], [{'p':[1], 'na': 3}], 'left'), equals([{'p':[1], 'ld':5}]));
        });
  
        test('Puts the left op first if two inserts are simultaneous', () {
          expect(json0.transform([{'p':[1], 'li':'a'}], [{'p':[1], 'li':'b'}], 'left'), equals([{'p':[1], 'li':'a'}]));
          expect(json0.transform([{'p':[1], 'li':'b'}], [{'p':[1], 'li':'a'}], 'right'), equals([{'p':[2], 'li':'b'}]));
        });
  
        test('converts an attempt to re-delete a list element into a no-op', () {
          expect(json0.transform([{'p':[1], 'ld':'x'}], [{'p':[1], 'ld':'x'}], 'left'), equals([]));
          expect(json0.transform([{'p':[1], 'ld':'x'}], [{'p':[1], 'ld':'x'}], 'right'), equals([]));
        });
      });
  
  
      group('#compose()', () {
        test('composes insert then delete into a no-op', () {
          expect(json0.compose([{'p':[1], 'li':'abc'}], [{'p':[1], 'ld':'abc'}]), equals([]));
          expect(json0.transform([{'p':[0],'ld':null,'li':"x"}], [{'p':[0],'li':"The"}], 'right'), equals([{'p':[1],'ld':null,'li':'x'}]));
        });

        test('doesn\'t change the original object', () {
          var a = [{'p':[0],'ld':'abc','li':null}];
          expect(json0.compose(a, [{'p':[0],'ld':null}]), equals([{'p':[0],'ld':'abc'}]));
          expect(a, equals([{'p':[0],'ld':'abc','li':null}]));
        });
        
        test('compose with empty move', () =>
          expect(json0.compose([{"p":[0],"li":null}],[{"p":[0],"lm":0}]), equals([{"p":[0],"li":null}])));
  
        test('composes together adjacent string ops', () {
//          expect(json0.compose([{'p':[100], 'si':'h'}], [{'p':[101], 'si':'i'}]), equals([{'p':[100], 'si':'hi'}]));
          expect(json0.compose([{'p':[], 't':'text0', 'o':[{'p':100, 'i':'h'}]}], [{'p':[], 't':'text0', 'o':[{'p':101, 'i':'i'}]}]), equals([{'p':[], 't':'text0', 'o':[{'p':100, 'i':'hi'}]}]));
        });
      });

      test('moves ops on a moved element with the element', () {
        expect(json0.transform([{'p':[4], 'ld':'x'}], [{'p':[4], 'lm':10}], 'left'), equals([{'p':[10], 'ld':'x'}]));
        expect(json0.transform([{'p':[4, 1], 'na':1}], [{'p':[4], 'lm':10}], 'left'), equals([{'p':[10, 1], 'na':1}]));
        expect(json0.transform([{'p':[4], 't':'text0', 'o':[{'p':1, 'i':'a'}]}], [{'p':[4], 'lm':10}], 'left'), equals([{'p':[10], 't':'text0', 'o':[{'p':1, 'i':'a'}]}]));
        expect(json0.transform([{'p':[4, 1], 'li':'a'}], [{'p':[4], 'lm':10}], 'left'), equals([{'p':[10, 1], 'li':'a'}]));
        expect(json0.transform([{'p':[4, 1], 'ld':'b', 'li':'a'}], [{'p':[4], 'lm':10}], 'left'), equals([{'p':[10, 1], 'ld':'b', 'li':'a'}]));
  
        expect(json0.transform([{'p':[0],'li':null}], [{'p':[0],'lm':1}], 'left'), equals([{'p':[0],'li':null}]));
        // [_,_,_,_,5,6,7,_]
        // c: [_,_,_,_,5,'x',6,7,_]   p:5 'li':'x'
        // s: [_,6,_,_,_,5,7,_]       p:5 'lm':1
        // correct: [_,6,_,_,_,5,'x',7,_]
        expect(json0.transform([{'p':[5],'li':'x'}], [{'p':[5],'lm':1}], 'left'), equals([{'p':[6],'li':'x'}]));
        // [_,_,_,_,5,6,7,_]
        // c: [_,_,_,_,5,6,7,_]  p:5 'ld':6
        // s: [_,6,_,_,_,5,7,_]  p:5 'lm':1
        // correct: [_,_,_,_,5,7,_]
        expect(json0.transform([{'p':[5],'ld':6}], [{'p':[5],'lm':1}], 'left'), equals([{'p':[1],'ld':6}]));
        //#expect([{'p':[0],'li':{}}], json0.transform([{'p':[0],'li':{}}], [{'p':[0],'lm':0}], 'right'
        expect(json0.transform([{'p':[0],'li':[]}], [{'p':[1],'lm':0}], 'left'), equals([{'p':[0],'li':[]}]));
        expect(json0.transform([{'p':[2],'li':'x'}], [{'p':[0],'lm':1}], 'left'), equals([{'p':[2],'li':'x'}]));
      });
  
      test('moves target index on ld/li', () {
        expect(json0.transform([{'p':[0], 'lm': 2}], [{'p':[1], 'ld':'x'}], 'left'), equals([{'p':[0],'lm':1}]));
        expect(json0.transform([{'p':[2], 'lm': 4}], [{'p':[1], 'ld':'x'}], 'left'), equals([{'p':[1],'lm':3}]));
        expect(json0.transform([{'p':[0], 'lm': 2}], [{'p':[1], 'li':'x'}], 'left'), equals([{'p':[0],'lm':3}]));
        expect(json0.transform([{'p':[2], 'lm': 4}], [{'p':[1], 'li':'x'}], 'left'), equals([{'p':[3],'lm':5}]));
        expect(json0.transform([{'p':[0], 'lm': 0}], [{'p':[0], 'li':28}], 'left'), equals([{'p':[1],'lm':1}]));
      });
  
      test('tiebreaks lm vs. ld/li', () {
        expect(json0.transform([{'p':[0], 'lm': 2}], [{'p':[0], 'ld':'x'}], 'left'), equals([]));
        expect(json0.transform([{'p':[0], 'lm': 2}], [{'p':[0], 'ld':'x'}], 'right'), equals([]));
        expect(json0.transform([{'p':[0], 'lm': 2}], [{'p':[0], 'li':'x'}], 'left'), equals([{'p':[1], 'lm':3}]));
        expect(json0.transform([{'p':[0], 'lm': 2}], [{'p':[0], 'li':'x'}], 'right'), equals([{'p':[1], 'lm':3}]));
      });
  
      test('replacement vs. deletion', () => 
        expect(json0.transform([{'p':[0],'ld':'x','li':'y'}], [{'p':[0],'ld':'x'}], 'right'), equals([{'p':[0],'li':'y'}])));
  
      test('replacement vs. insertion', () =>
        expect(json0.transform([{'p':[0],'ld':{},'li':"brillig"}], [{'p':[0],'li':36}], 'left'), equals([{'p':[1],'ld':{},'li':"brillig"}])));
  
      test('replacement vs. replacement', () {
        expect(json0.transform([{'p':[0],'ld':null,'li':[]}], [{'p':[0],'ld':null,'li':0}], 'right'), equals([]));
        expect(json0.transform([{'p':[0],'ld':null,'li':0}], [{'p':[0],'ld':null,'li':[]}], 'left'), equals([{'p':[0],'ld':[],'li':0}]));
      });
  
      test('composes replace with delete of replaced element results in insert', () =>
        expect(json0.compose([{'p':[2],'ld':[],'li':null}], [{'p':[2],'ld':null}]), equals([{'p':[2],'ld':[]}])));

      test('lm vs lm', () {
        expect(json0.transform([{'p':[0],'lm':2}], [{'p':[2],'lm':1}], 'left'), equals([{'p':[0],'lm':2}]));
        expect(json0.transform([{'p':[3],'lm':3}], [{'p':[5],'lm':0}], 'left'), equals([{'p':[4],'lm':4}]));
        expect(json0.transform([{'p':[2],'lm':0}], [{'p':[1],'lm':0}], 'left'), equals([{'p':[2],'lm':0}]));
        expect(json0.transform([{'p':[2],'lm':0}], [{'p':[1],'lm':0}], 'right'), equals([{'p':[2],'lm':1}]));
        expect(json0.transform([{'p':[2],'lm':0}], [{'p':[5],'lm':0}], 'right'), equals([{'p':[3],'lm':1}]));
        expect(json0.transform([{'p':[2],'lm':0}], [{'p':[5],'lm':0}], 'left'), equals([{'p':[3],'lm':0}]));
        expect(json0.transform([{'p':[2],'lm':5}], [{'p':[2],'lm':0}], 'left'), equals([{'p':[0],'lm':5}]));
        expect(json0.transform([{'p':[2],'lm':5}], [{'p':[2],'lm':0}], 'left'), equals([{'p':[0],'lm':5}]));
        expect(json0.transform([{'p':[1],'lm':0}], [{'p':[0],'lm':5}], 'right'), equals([{'p':[0],'lm':0}]));
        expect(json0.transform([{'p':[1],'lm':0}], [{'p':[0],'lm':1}], 'right'), equals([{'p':[0],'lm':0}]));
        expect(json0.transform([{'p':[0],'lm':1}], [{'p':[1],'lm':0}], 'left'), equals([{'p':[1],'lm':1}]));
        expect(json0.transform([{'p':[0],'lm':1}], [{'p':[5],'lm':0}], 'right'), equals([{'p':[1],'lm':2}]));
        expect(json0.transform([{'p':[2],'lm':1}], [{'p':[5],'lm':0}], 'right'), equals([{'p':[3],'lm':2}]));
        expect(json0.transform([{'p':[3],'lm':1}], [{'p':[1],'lm':3}], 'left'), equals([{'p':[2],'lm':1}]));
        expect(json0.transform([{'p':[1],'lm':3}], [{'p':[3],'lm':1}], 'left'), equals([{'p':[2],'lm':3}]));
        expect(json0.transform([{'p':[2],'lm':6}], [{'p':[0],'lm':1}], 'left'), equals([{'p':[2],'lm':6}]));
        expect(json0.transform([{'p':[2],'lm':6}], [{'p':[0],'lm':1}], 'right'), equals([{'p':[2],'lm':6}]));
        expect(json0.transform([{'p':[2],'lm':6}], [{'p':[1],'lm':0}], 'left'), equals([{'p':[2],'lm':6}]));
        expect(json0.transform([{'p':[2],'lm':6}], [{'p':[1],'lm':0}], 'right'), equals([{'p':[2],'lm':6}]));
        expect(json0.transform([{'p':[0],'lm':1}], [{'p':[2],'lm':1}], 'left'), equals([{'p':[0],'lm':2}]));
        expect(json0.transform([{'p':[2],'lm':1}], [{'p':[0],'lm':1}], 'right'), equals([{'p':[2],'lm':0}]));
        expect(json0.transform([{'p':[0],'lm':0}], [{'p':[1],'lm':0}], 'left'), equals([{'p':[1],'lm':1}]));
        expect(json0.transform([{'p':[0],'lm':1}], [{'p':[1],'lm':3}], 'left'), equals([{'p':[0],'lm':0}]));
        expect(json0.transform([{'p':[2],'lm':1}], [{'p':[3],'lm':2}], 'left'), equals([{'p':[3],'lm':1}]));
        expect(json0.transform([{'p':[3],'lm':2}], [{'p':[2],'lm':1}], 'left'), equals([{'p':[3],'lm':3}]));
      });
  
      test('changes indices correctly around a move', () {
        expect(json0.transform([{'p':[0,0],'li':{}}], [{'p':[1],'lm':0}], 'left'), equals([{'p':[1,0],'li':{}}]));
        expect(json0.transform([{'p':[1],'lm':0}], [{'p':[0],'ld':{}}], 'left'), equals([{'p':[0],'lm':0}]));
        expect(json0.transform([{'p':[0],'lm':1}], [{'p':[1],'ld':{}}], 'left'), equals([{'p':[0],'lm':0}]));
        expect(json0.transform([{'p':[6],'lm':0}], [{'p':[2],'ld':{}}], 'left'), equals([{'p':[5],'lm':0}]));
        expect(json0.transform([{'p':[1],'lm':0}], [{'p':[2],'ld':{}}], 'left'), equals([{'p':[1],'lm':0}]));
        expect(json0.transform([{'p':[2],'lm':1}], [{'p':[1],'ld':3}], 'right'), equals([{'p':[1],'lm':1}]));
  
        expect(json0.transform([{'p':[2],'ld':{}}], [{'p':[1],'lm':2}], 'right'), equals([{'p':[1],'ld':{}}]));
        expect(json0.transform([{'p':[1],'ld':{}}], [{'p':[2],'lm':1}], 'left'), equals([{'p':[2],'ld':{}}]));
  
  
        expect(json0.transform([{'p':[1],'ld':{}}], [{'p':[0],'lm':1}], 'right'), equals([{'p':[0],'ld':{}}]));
  
        expect(json0.transform([{'p':[1],'ld':1,'li':2}], [{'p':[1],'lm':0}], 'left'), equals([{'p':[0],'ld':1,'li':2}]));
        expect(json0.transform([{'p':[1],'ld':2,'li':3}], [{'p':[0],'lm':1}], 'left'), equals([{'p':[0],'ld':2,'li':3}]));
        expect(json0.transform([{'p':[0],'ld':3,'li':4}], [{'p':[1],'lm':0}], 'left'), equals([{'p':[1],'ld':3,'li':4}]));
      });

      test('li vs lm', () {
        li(p) => [{'p':[p],'li':[]}];
        lm(f,t) => [{'p':[f],'lm':t}];
        var xf = json0.transform;
  
        expect(xf(li(0), lm(1, 3), 'left'), equals(li(0)));
        expect(xf(li(1), lm(1, 3), 'left'), equals(li(1)));
        expect(xf(li(2), lm(1, 3), 'left'), equals(li(1)));
        expect(xf(li(3), lm(1, 3), 'left'), equals(li(2)));
        expect(xf(li(4), lm(1, 3), 'left'), equals(li(4)));
  
        expect(xf(lm(1, 3), li(0), 'right'), equals(lm(2, 4)));
        expect(xf(lm(1, 3), li(1), 'right'), equals(lm(2, 4)));
        expect(xf(lm(1, 3), li(2), 'right'), equals(lm(1, 4)));
        expect(xf(lm(1, 3), li(3), 'right'), equals(lm(1, 4)));
        expect(xf(lm(1, 3), li(4), 'right'), equals(lm(1, 3)));
  
        expect(xf(li(0), lm(1, 2), 'left'), equals(li(0)));
        expect(xf(li(1), lm(1, 2), 'left'), equals(li(1)));
        expect(xf(li(2), lm(1, 2), 'left'), equals(li(1)));
        expect(xf(li(3), lm(1, 2), 'left'), equals(li(3)));
  
        expect(xf(li(0), lm(3, 1), 'left'), equals(li(0)));
        expect(xf(li(1), lm(3, 1), 'left'), equals(li(1)));
        expect(xf(li(2), lm(3, 1), 'left'), equals(li(3)));
        expect(xf(li(3), lm(3, 1), 'left'), equals(li(4)));
        expect(xf(li(4), lm(3, 1), 'left'), equals(li(4)));
  
        expect(xf(lm(3, 1), li(0), 'right'), equals(lm(4, 2)));
        expect(xf(lm(3, 1), li(1), 'right'), equals(lm(4, 2)));
        expect(xf(lm(3, 1), li(2), 'right'), equals(lm(4, 1)));
        expect(xf(lm(3, 1), li(3), 'right'), equals(lm(4, 1)));
        expect(xf(lm(3, 1), li(4), 'right'), equals(lm(3, 1)));
  
        expect(xf(li(0), lm(2, 1), 'left'), equals(li(0)));
        expect(xf(li(1), lm(2, 1), 'left'), equals(li(1)));
        expect(xf(li(2), lm(2, 1), 'left'), equals(li(3)));
        expect(xf(li(3), lm(2, 1), 'left'), equals(li(3)));
      });
    });

    group('object', () {
      test('passes sanity checks', () {
        expect(json0.apply({'x':'a'}, [{'p':['y'], 'oi':'b'}]), equals({'x':'a', 'y':'b'}));
        expect(json0.apply({'x':'a'}, [{'p':['x'], 'od':'a'}]), equals({}));
        expect(json0.apply({'x':'a'}, [{'p':['x'], 'od':'a', 'oi':'b'}]), equals({'x':'b'}));
        expect(json0.apply({'x':'a'}, [{'p':['x'], 'oin': 'b'}]), equals({'x':'a'}));
        
        expect(() { 
          expect(json0.apply({'x':'a'}, [{'p':['x'], 'od':'z'}]), equals({}));
        }, throwsA(errMatcher('does not match')));
        expect(() { 
          expect(json0.apply({'x':['a',{'y':'z'}]}, [{'p':['x'], 'od':['a',{'y':'zz'}], 'oi':'b'}]), equals({'x':'b'}));
        }, throwsA(errMatcher('does not match')));
      });

      test('Ops on deleted elements become noops', () {
        // text and subtype operations does not exists but still works b/z they're NOOPed
        expect(json0.transform([{'p':[1, 0], 'na':1}], [{'p':[1], 'od':'x'}], 'left'), equals([]));
        expect(json0.transform([{'p':[1], 't':'text0', 'o':[{'p':0, 'i':'hi'}]}], [{'p':[1], 'od':'x'}], 'left'), equals([]));
        expect(json0.transform([{'p':[9],'si':"bite "}], [{'p':[],'od':"agimble s", 'oi':null}], 'right'), equals([]));
        expect(json0.transform([{'p':[], 't':'text0', 'o':[{'p':9, 'i':"bite "}]}], [{'p':[], 'od':"agimble s", 'oi':null}], 'right'), equals([]));
      });

      test('Ops on replaced elements become noops', () {
        expect(json0.transform([{'p':[1, 0], 'si':'hi'}], [{'p':[1], 'od':'x', 'oi':'y'}], 'left'), equals([]));
        expect(json0.transform([{'p':[1], 't':'text0', 'o':[{'p':0, 'i':'hi'}]}], [{'p':[1], 'od':'x', 'oi':'y'}], 'left'), equals([]));
      });

      test('Deleted data is changed to reflect edits', () {
//      expect(json0.transform([{'p':[1], 'od':'a'}], [{'p':[1, 1], 'si':'bc'}], 'left'), equals([{'p':[1], 'od':'abc'}]));
        expect(json0.transform([{'p':[1], 'od':'a'}], [{'p':[1], 't':'text0', 'o':[{'p':1, 'i':'bc'}]}], 'left'), equals([{'p':[1], 'od':'abc'}]));
        expect(json0.transform([{'p':[],'od':22,'oi':[]}], [{'p':[],'na':3}], 'left'), equals([{'p':[],'od':25,'oi':[]}]));
        expect(json0.transform([{'p':[],'od':{'toves':0},'oi':4}], [{'p':["toves"],'od':0,'oi':""}], 'left'), equals([{'p':[],'od':{'toves':""},'oi':4}]));
//      expect(json0.transform([{'p':[],'od':"thou and ",'oi':[]}], [{'p':[7], 'sd':"d "}], 'left'), equals([{'p':[],'od':"thou an",'oi':[]}]));
        expect(json0.transform([{'p':[],'od':"thou and ",'oi':[]}], [{'p':[], 't':'text0', 'o':[{'p':7, 'd':"d "}]}], 'left'), equals([{'p':[],'od':"thou an",'oi':[]}]));
        expect(json0.transform([{'p':["bird"],'na':2}], [{'p':[],'od':{'bird':38},'oi':20}], 'right'), equals([]));
        expect(json0.transform([{'p':[],'od':{'bird':38},'oi':20}], [{'p':["bird"],'na':2}], 'left'), equals([{'p':[],'od':{'bird':40},'oi':20}]));
        expect(json0.transform([{'p':["He"],'od':[]}], [{'p':["The"],'na':-3}], 'right'), equals([{'p':['He'],'od':[]}]));
        expect(json0.transform([{'p':["He"],'oi':{}}], [{'p':[],'od':{},'oi':"the"}], 'left'), equals([]));
      });

      test('If two inserts are simultaneous, the lefts insert will win', () {
        expect(json0.transform([{'p':[1], 'oi':'a'}], [{'p':[1], 'oi':'b'}], 'left'), equals([{'p':[1], 'oi':'a', 'od':'b'}]));
        expect(json0.transform([{'p':[1], 'oi':'b'}], [{'p':[1], 'oi':'a'}], 'right'), equals([]));
      });

      test('parallel ops on different keys miss each other', () {
        expect(json0.transform([{'p':['a'], 'oi':'x'}], [{'p':['b'], 'oi':'z'}], 'left'), equals([{'p':['a'], 'oi': 'x'}]));
        expect(json0.transform([{'p':['a'], 'oi':'x'}], [{'p':['b'], 'od':'z'}], 'left'), equals([{'p':['a'], 'oi': 'x'}]));
        expect(json0.transform([{'p':["in","he"],'oi':{}}], [{'p':["and"],'od':{}}], 'right'), equals([{'p':["in","he"],'oi':{}}]));
//      expect(json0.transform([{'p':['x',0],'si':"his "}], [{'p':['y'],'od':0,'oi':1}], 'right'), equals([{'p':['x',0],'si':"his "}]));
        expect(json0.transform([{'p':['x'],'t':'text0', 'o':[{'p':0, 'i':"his "}]}], [{'p':['y'],'od':0,'oi':1}], 'right'), equals([{'p':['x'], 't':'text0', 'o':[{'p':0, 'i':"his "}]}]));
      });

      test('replacement vs. deletion', () =>
        expect(json0.transform([{'p':[],'od':[''],'oi':{}}], [{'p':[],'od':['']}], 'right'), equals([{'p':[],'oi':{}}])));

      test('replacement vs. replacement', () {
        expect(json0.transform([{'p':[],'od':['']},{'p':[],'oi':{}}], [{'p':[],'od':['']},{'p':[],'oi':null}], 'right'), equals([]));
        expect(json0.transform([{'p':[],'od':['']},{'p':[],'oi':{}}], [{'p':[],'od':['']},{'p':[],'oi':null}], 'left'), equals([{'p':[],'od':null,'oi':{}}]));
        expect(json0.transform([{'p':[],'od':[''],'oi':{}}], [{'p':[],'od':[''],'oi':null}], 'left'), equals([{'p':[],'od':null,'oi':{}}]));
        expect(json0.transform([{'p':[],'od':[''],'oi':{}}], [{'p':[],'od':[''],'oi':null}], 'right'), equals([]));

        // test diamond property
        var rightOps = [ {"p":[],"od":null,"oi":{}} ];
        var leftOps = [ {"p":[],"od":null,"oi":""} ];
        var rightHas = json0.apply(null, rightOps);
        var leftHas = json0.apply(null, leftOps);

        var l_r = json0.transformX(leftOps, rightOps);
        expect(json0.apply(rightHas, l_r[0]), equals(leftHas));
        expect(json0.apply(leftHas, l_r[1]), equals(leftHas));
      });

      test('An attempt to re-delete a key becomes a no-op', () {
        expect(json0.transform([{'p':['k'], 'od':'x'}], [{'p':['k'], 'od':'x'}], 'left'), equals([]));
        expect(json0.transform([{'p':['k'], 'od':'x'}], [{'p':['k'], 'od':'x'}], 'right'), equals([]));
      });
      
      test('Optional insert vs insert', () {
        // TODO try to fix these cases
//        expect(json0.transform([{'p': [], 'oin': 1}, {'p': [], 'od': 1}], [{'p':[], 'oi':2}], 'left'), equals([]));
//        expect(json0.transform([{'p': [], 'oin': 1}, {'p': [], 'od': 1}], [{'p':[], 'oi':2}], 'right'), equals([{'p': [], 'oi': 2}]));

//        expect(json0.transform([{'p': [], 'oin': 1}, {'p': [], 'na': 2}, {'p': [], 'od': 3}], [{'p':[], 'oi':2}], 'right'), equals([{'p': [], 'oi': 2}]));

        expect(json0.transform([{'p':[1], 'oin':'a'}], [{'p':[1], 'oi':'b'}], 'left'), equals([]));
        expect(json0.transform([{'p':[1], 'oin':'a'}], [{'p':[1], 'oi':'b'}], 'right'), equals([{'p':[1], 'od':'a', 'oi':'b'}]));
      });

      test('Optional vs optional, no one wins', () {
        expect(json0.transform([{'p':[1], 'oin':'a'}], [{'p':[1], 'oin':'b'}], 'left'), equals([]));
        expect(json0.transform([{'p':[1], 'oin':'a'}], [{'p':[1], 'oin':'b'}], 'right'), equals([]));
      });    
    });

    group('randomizer', () {
      test('passes', () {
        new Fuzzer(new FuzzerJson0Impl()).runTest(json0, 1000);
      });
      
      test('passes with oin', () {
        new Fuzzer(new FuzzerJson0Impl(oin: true)).runTest(json0, 1000);
      });
    });
  });
}