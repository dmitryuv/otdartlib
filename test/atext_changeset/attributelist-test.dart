part of otdartlib.test.atext_changeset;

void attributeList_test() {
  var errMatcher = (msg) => predicate((Exception e) => new RegExp(msg).hasMatch(e.toString())); 

  group('AttributeList', () {
    test('unpack attributes', () {
      var pool = [['moo', 'zoo'], [], [], [], [], [], [], [], [], [], ['foo', 'bar']];
 
      expect(new AttributeList.unpack('^0*a', pool), equals(new AttributeList.from([
                                                                                        new OpAttribute.remove('moo', 'zoo'), 
                                                                                        new OpAttribute.format('foo', 'bar')])));
    });
  
    test('attribute lists equals', () {
      var list = [['1','2'],['3','4'],['5','6']]
        .map((a) {
          return new OpAttribute.format(a[0], a[1]);
        }).toList();
  
      expect(new AttributeList.from(list), equals(new AttributeList.from(list.reversed.toList())));
      expect(new AttributeList.from(list), isNot(equals(new AttributeList.from(list.sublist(1)))));
    });
  
    group('pack', () {
      var pool = [['foo','true'], ['bar','false'], ['foo', '1']];
            
      testPack(name, atts, res, [err]) {
        test(name, () {
          var unpacked = new AttributeList.unpack(atts, pool);
          if(err != null) {
            expect(() => unpacked.pack(pool), throwsA(errMatcher(err)));
          } else {
            expect(unpacked.pack(pool), equals(res.isEmpty ? atts : res));
          }
        });
      }
      testPack('sort keys', '*0*1', '*1*0');
      testPack('reorder removes before formats','*0^2', '^2*0'); // reorder deletes before insersts
      testPack('throws if multiple ops on the same N', '*0^0', null, 'on the same attrib key');
      testPack('throws if multiple formats or removes ont he same key', '*0*2', null, 'multiple insertions');
    });
  
    group('attribute operations', () {
      var pool = [['foo','true'], ['bar','false'], ['foo', '1'], ['author','x'], ['author','y'], ['author','z']];
      alist(atts) {
        return new AttributeList.unpack(atts, pool);
      }
    
      group('merge', () {
        testMerge(name, att1, att2, res, [err]) {
          test(name, () {
            if(err != null) {
              expect(() => alist(att1).merge(alist(att2)).pack(pool), throwsA(errMatcher(err)));
            } else {
              expect(alist(att1).merge(alist(att2)).pack(pool), equals(res));
            }
          });
        }
  
        testMerge('replace key with same opcode', '*0*1', '*2', '*1*2');
        testMerge('do not replace if different opcode', '*1*0', '^2', '^2*1*0');
        testMerge('add new attrib', '*1*0', '*3', '*3*1*0');
        testMerge('throws for mutual ops', '*0*1', '^0', null, 'mutual ops');
        testMerge('ignores duplicate', '*0', '*0', '*0');
      });
  
      group('compose', () {
        testCompose(name, att1, att2, res, isCompose, [err]) {
          test(name, () {
            if(err != null) {
              expect(() => alist(att1).compose(alist(att2), isComposition: isCompose).pack(pool), throwsA(errMatcher(err)));
            } else {
              expect(alist(att1).compose(alist(att2), isComposition: isCompose).pack(pool), equals(res));
            }
          });
        }
       
        testCompose('insert over empty', '', '*0', '*0', true);
        testCompose('remove over empty', '', '^0', '^0', true);
        testCompose('combine insertions', '*0', '*1', '*1*0', true);
        testCompose('combine insert+remove diff keys', '*0', '^1', '^1*0', true);
        testCompose('collapse insert+remove same key', '*0*1', '^0', '*1', true);
        testCompose('collapse remove+insert same key', '^0', '*0', '', true);
        testCompose('sort output', '*0^2', '*1', '^2*1*0', true);
  
        testCompose('should throw on duplicate num insert', '*0', '*0', null, true, 'identical');
        testCompose('should throw on duplicate num remove', '^0', '^0', null, true, 'identical');
        testCompose('should throw on duplicate key insert', '*0', '*2', null, true, 'multiple');
        testCompose('should throw on duplicate key remove', '^0', '^2', null, true, 'multiple');
        testCompose('should throw on applying remove to non-existing att', '*0', '^1', null, false, 'non-existing');
      });
  
      group('transform', () {
        testTransform(name, att1, att2, res, [err]) {
          test(name, () {
            if(err != null) {
              expect(() => alist(att1).transform(alist(att2)).pack(pool), throwsA(errMatcher(err)));
            } else {
              expect(alist(att1).transform(alist(att2)).pack(pool), equals(res));
            }
          });
        }
  
        testTransform('do nothing after empty atts', '*1*0', '', '*1*0');
        testTransform('do nothing for empty atts', '', '*1*0', '');
        testTransform('ignore second insertion', '*0', '*0', '');
        testTransform('ignore second deletion', '^0', '^0', '');
        testTransform('replace insertion with same key', '*2', '*0', '^0*2');
        testTransform('replace replaced insertion with same key', '^3*4', '^3*5', '^5*4');
        testTransform('take lexically earlier value left', '*2', '*0', '^0*2');
        testTransform('take lexically earlier value right', '*0', '*2', '');
  
        testTransform('throw on removal of the same key but different value', '^0', '^2', null, 'invalid');
        testTransform('throw on opposite removal on N', '^0', '*0', null, 'invalid');
        testTransform('throw on opposite insertion on N', '*0', '^0', null, 'invalid');
        testTransform('throw on removal of inserted key with different value', '^2', '*0', null, 'invalid');
        testTransform('throw on removal of removed key with different value', '^2', '^0', null, 'invalid');
      });
      
      group('format', () {
        testFormat(name, att1, att2, res, [err]) {
          test(name, () {
            if(err != null) {
              expect(() => alist(att1).format(alist(att2)).pack(pool), throwsA(errMatcher(err)));
            } else {
              expect(alist(att1).format(alist(att2)).pack(pool), equals(res));
            }
          });
        }
  
        testFormat('drop format if exists', '*0*1', '*0*3', '*3');
        testFormat('format empty attributes', '', '*0', '*0');
        testFormat('keep removes if exists', '*0*1', '^0*3', '^0*3');
        testFormat('drop removes if not exists', '*0', '^1*3', '*3');
        testFormat('replace same key with new value', '*0*1', '*3*2', '^0*3*2');
      });
  
      group('invert', () {
        testInvert(name, att, except, res, [err]) {
          test(name, () {
            if(err != null) {
              expect(() => alist(att).invert(alist(except)).pack(pool), throwsA(errMatcher(err)));
            } else {
              expect(alist(att).invert(alist(except)).pack(pool), equals(res));
            }
          });
        }
        testInvert('simple', '^1^3*0', null, '^0*3*1');
        testInvert('with exceptions', '^1^3*0', '*3*0', '*3*1*0');
      });
    });
  });

}