part of otdartlib.test.ottypes;

void text0_test() {
  var text0 = new OT_text0();
  
  group('text0', () {
    group('compose', () {
      // Compose is actually pretty easy
      test('is sane', () {
        expect(text0.compose([], []), equals([]));
        expect(text0.compose([{'i':'x', 'p':0}], []), equals([{'i':'x', 'p':0}]));
        expect(text0.compose([], [{'i':'x', 'p':0}]), equals([{'i':'x', 'p':0}]));
        expect(text0.compose([{'i':'y', 'p':100}], [{'i':'x', 'p':0}]), equals([{'i':'y', 'p':100}, {'i':'x', 'p':0}]));
      });
    });

    group('transform', () {
      test('is sane', () {
        expect(text0.transform([], [], 'left'), equals([]));
        expect(text0.transform([], [], 'right'), equals([]));

        expect(text0.transform([{'i':'y', 'p':100}, {'i':'x', 'p':0}], [], 'left'), equals([{'i':'y', 'p':100}, {'i':'x', 'p':0}]));
        expect(text0.transform([], [{'i':'y', 'p':100}, {'i':'x', 'p':0}], 'right'), equals([]));
      });

      test('inserts', () {
        expect(text0.transformX([{'i':'x', 'p':9}], [{'i':'a', 'p':1}]), equals([[{'i':'x', 'p':10}], [{'i':'a', 'p':1}]]));
        expect(text0.transformX([{'i':'x', 'p':10}], [{'i':'a', 'p':10}]), equals([[{'i':'x', 'p':10}], [{'i':'a', 'p':11}]]));

        expect(text0.transformX([{'i':'x', 'p':11}], [{'d':'a', 'p':9}]), equals([[{'i':'x', 'p':10}], [{'d':'a', 'p':9}]]));
        expect(text0.transformX([{'i':'x', 'p':11}], [{'d':'a', 'p':10}]), equals([[{'i':'x', 'p':10}], [{'d':'a', 'p':10}]]));
        expect(text0.transformX([{'i':'x', 'p':11}], [{'d':'a', 'p':11}]), equals([[{'i':'x', 'p':11}], [{'d':'a', 'p':12}]]));

        expect(text0.transform([{'i':'x', 'p':10}], [{'d':'a', 'p':11}], 'left'), equals([{'i':'x', 'p':10}]));
        expect(text0.transform([{'i':'x', 'p':10}], [{'d':'a', 'p':10}], 'left'), equals([{'i':'x', 'p':10}]));
        expect(text0.transform([{'i':'x', 'p':10}], [{'d':'a', 'p':10}], 'right'), equals([{'i':'x', 'p':10}]));
      });

      test('deletes', () {
        expect(text0.transformX([{'d':'abc', 'p':10}], [{'d':'xy', 'p':4}]), equals([[{'d':'abc', 'p':8}], [{'d':'xy', 'p':4}]]));
        expect(text0.transformX([{'d':'abc', 'p':10}], [{'d':'b', 'p':11}]), equals([[{'d':'ac', 'p':10}], []]));
        expect(text0.transformX([{'d':'b', 'p':11}], [{'d':'abc', 'p':10}]), equals([[], [{'d':'ac', 'p':10}]]));
        expect(text0.transformX([{'d':'abc', 'p':10}], [{'d':'bc', 'p':11}]), equals([[{'d':'a', 'p':10}], []]));
        expect(text0.transformX([{'d':'abc', 'p':10}], [{'d':'ab', 'p':10}]), equals([[{'d':'c', 'p':10}], []]));
        expect(text0.transformX([{'d':'abc', 'p':10}], [{'d':'bcd', 'p':11}]), equals([[{'d':'a', 'p':10}], [{'d':'d', 'p':10}]]));
        expect(text0.transformX([{'d':'bcd', 'p':11}], [{'d':'abc', 'p':10}]), equals([[{'d':'d', 'p':10}], [{'d':'a', 'p':10}]]));
        expect(text0.transformX([{'d':'abc', 'p':10}], [{'d':'xy', 'p':13}]), equals([[{'d':'abc', 'p':10}], [{'d':'xy', 'p':10}]]));
      });
    });

    group('transformCursor', () {
      test('is sane', () {
        expect(text0.transformCursor(0, [], 'right'), equals(0));
        expect(text0.transformCursor(0, [], 'left'), equals(0));
        expect(text0.transformCursor(100, []), equals(100));
      });

      test('works vs insert', () {
        expect(text0.transformCursor(0, [{'i':'asdf', 'p':100}], 'right'), equals(0));
        expect(text0.transformCursor(0, [{'i':'asdf', 'p':100}], 'left'), equals(0));

        expect(text0.transformCursor(200, [{'i':'asdf', 'p':100}], 'right'), equals(204));
        expect(text0.transformCursor(200, [{'i':'asdf', 'p':100}], 'left'), equals(204));

        expect(text0.transformCursor(100, [{'i':'asdf', 'p':100}], 'right'), equals(104));
        expect(text0.transformCursor(100, [{'i':'asdf', 'p':100}], 'left'), equals(100));
      });

      test('works vs delete', () {
        expect(text0.transformCursor(0, [{'d':'asdf', 'p':100}], 'right'), equals(0));
        expect(text0.transformCursor(0, [{'d':'asdf', 'p':100}], 'left'), equals(0));
        expect(text0.transformCursor(0, [{'d':'asdf', 'p':100}]), equals(0));

        expect(text0.transformCursor(200, [{'d':'asdf', 'p':100}]), equals(196));

        expect(text0.transformCursor(100, [{'d':'asdf', 'p':100}]), equals(100));
        expect(text0.transformCursor(102, [{'d':'asdf', 'p':100}]), equals(100));
        expect(text0.transformCursor(104, [{'d':'asdf', 'p':100}]), equals(100));
        expect(text0.transformCursor(105, [{'d':'asdf', 'p':100}]), equals(101));
      });
    });

    group('normalize', () {
      test('is sane', () {
        testUnchanged(op) => expect(text0.normalize(op), equals(op));
        
        testUnchanged([]);
        testUnchanged([{'i':'asdf', 'p':100}]);
        testUnchanged([{'i':'asdf', 'p':100}, {'d':'fdsa', 'p':123}]);
      });
      
      test('adds missing "p":0', () {
        expect(text0.normalize([{'i':'abc'}]), equals([{'i':'abc', 'p':0}]));
        expect(text0.normalize([{'d':'abc'}]), equals([{'d':'abc', 'p':0}]));
        expect(text0.normalize([{'i':'abc'}, {'d':'abc'}]), equals([{'i':'abc', 'p':0}, {'d':'abc', 'p':0}]));
      });
      
      test('converts op to an array', () {
        expect(text0.normalize({'i':'abc', 'p':0}), equals([{'i':'abc', 'p':0}]));
        expect(text0.normalize({'d':'abc', 'p':0}), equals([{'d':'abc', 'p':0}]));
      });
      
      test('works with a really simple op', () =>
        expect(text0.normalize({'i':'abc'}), equals([{'i':'abc', 'p':0}])));

      test('compress inserts', () {
        expect(text0.normalize([{'i':'abc', 'p':10}, {'i':'xyz', 'p':10}]), equals([{'i':'xyzabc', 'p':10}]));
        expect(text0.normalize([{'i':'abc', 'p':10}, {'i':'xyz', 'p':11}]), equals([{'i':'axyzbc', 'p':10}]));
        expect(text0.normalize([{'i':'abc', 'p':10}, {'i':'xyz', 'p':13}]), equals([{'i':'abcxyz', 'p':10}]));
      });

      test('doesnt compress separate inserts', () {
        t(op) => expect(text0.normalize(op), equals(op));

        t([{'i':'abc', 'p':10}, {'i':'xyz', 'p':9}]);
        t([{'i':'abc', 'p':10}, {'i':'xyz', 'p':14}]);
      });

      test('compress deletes', () {
        expect(text0.normalize([{'d':'abc', 'p':10}, {'d':'xy', 'p':8}]), equals([{'d':'xyabc', 'p':8}]));
        expect(text0.normalize([{'d':'abc', 'p':10}, {'d':'xy', 'p':9}]), equals([{'d':'xabcy', 'p':9}]));
        expect(text0.normalize([{'d':'abc', 'p':10}, {'d':'xy', 'p':10}]), equals([{'d':'abcxy', 'p':10}]));
      });

      test('doesnt compress separate deletes', () {
        t(op) => expect(text0.normalize(op), equals(op));

        t([{'d':'abc', 'p':10}, {'d':'xyz', 'p':6}]);
        t([{'d':'abc', 'p':10}, {'d':'xyz', 'p':11}]);
      });
      
      group('randomizer', () { 
        test('passes', () {
          new Fuzzer(new FuzzerText0Impl()).runTest(text0);
//        @slow 4000
//        randomizer text0
        });
      });
    });
  });
}