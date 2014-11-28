part of otdartlib.test.ottypes;

class FuzzerJson0Impl extends FuzzerImpl {
  final bool _testOin;
  
  FuzzerJson0Impl({bool oin: false}) : _testOin = oin;
  
  
  randomKey(obj) {
    if(obj is List) {
      if(obj.isEmpty)
        return null;
      else
        return randomInt(obj.length);
    } else {
      var count = 0;
      var result;
    
      obj.keys.forEach((key) {
        if (randomReal() < 1 / ++count) {
          result = key;
        }
      });
      return result;
    }
  }
  
  // Generate a random new key for a value in obj.
  // obj must be an Object.
  randomNewKey(obj) {
    // There's no do-while loop in coffeescript.
    var key = randomWord();
    while (obj.containsKey(key)) {
      key = randomWord();
    }
    return key;
  }

  // Generate a random object
  randomThing() {
    switch(randomInt(6)) {
      case 0: return null;
      case 1: return '';
      case 2: return randomWord();
      case 3:
        var obj = {};
        for(var i = 0, l = randomInt(5); i < l; i++) {
          obj[randomNewKey(obj)] = randomThing();
        }
        return obj;

      case 4: 
        return new List.generate(randomInt(5), (i) => randomThing());
      case 5: return randomInt(50); 
    }
  }
  
  // Pick a random path to something in the object.
  randomPath(data) {
    var path = [];

    while(randomReal() > 0.85 && (data is Map || data is List)) {
      var key = randomKey(data);
      
      if(key == null) break;

      path.add(key);
      data = data[key];
    }

    return path;
  }

  
  @override 
  List generateRandomOp(data) {
    var pct = 0.95;

    var container = { 'data': clone(data) };
    expect(container['data'], equals(data));
    
    var op = [];

    while(randomReal() < pct) {
      pct *= 0.6;

      // Pick a random object in the document operate on.
      var path = randomPath(container['data']);

      // parent = the container for the operand. parent[key] contains the operand.
      var parent = container;
      var key = 'data';
      path.forEach((p) {
        parent = parent[key];
        key = p;
      });
      var operand = parent[key];

      if(randomReal() < 0.4 && parent != container && parent is List) {
        // List move
        var newIndex = randomInt(parent.length);

        // Remove the element from its current position in the list
        parent.removeAt(key as num);
        // Insert it in the new position.
        parent.insert(newIndex, operand);

        op.add({'p':path, 'lm':newIndex});
      } else if(randomReal() < 0.3 || operand == null) {
        // Replace

        var newValue = randomThing();
        parent[key] = newValue;

        if(parent is List) {
          op.add({'p':path, 'ld':operand, 'li':clone(newValue)});
        } else {
          op.add({'p':path, 'od':operand, 'oi':clone(newValue)});
        }
      } else if(operand is String) {
        // String. This code is adapted from the text op generator.

        if(randomReal() > 0.5 || operand.length == 0) {
          // Insert
          var pos = randomInt(operand.length + 1);
          var str = randomWord() + ' ';

          parent[key] = operand.substring(0, pos) + str + operand.substring(pos);
          op.add({'p': path, 't': 'text0', 'o': [{ 'p' : pos, 'i': str }]});
        } else {
          // Delete
          var pos = randomInt(operand.length);
          var length = min(randomInt(4), operand.length - pos);
          var str = operand.substring(pos, pos + length);

          parent[key] = operand.substring(0, pos) + operand.substring(pos + length);
          op.add({'p': path, 't': 'text0', 'o': [{ 'p' : pos, 'd': str }]});
        }
      } else if(operand is num) {
        // Number
        var inc = randomInt(10) - 3;
        parent[key] += inc;
        op.add({'p':path, 'na':inc});
      } else if(operand is List) {
        // Array. Replace is covered above, so we'll just randomly insert or delete.
        // This code looks remarkably similar to string insert, above.

        if(randomReal() > 0.5 || operand.length == 0) {
          // Insert
          var pos = randomInt(operand.length + 1);
          var obj = randomThing();
          
          path.add(pos);
          operand.insert(pos, obj);
          op.add({'p':path, 'li':clone(obj)});
        } else {
          // Delete
          var pos = randomInt(operand.length);
          var obj = operand[pos];

          path.add(pos);
          operand.removeAt(pos);
          op.add({'p':path, 'ld':clone(obj)});
        }
      } else {
        // Object
        var k = randomKey(operand);

        if(_testOin && k == null && !operand.containsKey(k)) {
          // "oin" is only valid when client knows there is no value for the key and 
          // someone can initiate the same key. If we try to insert over existing value
          // (and operation will be ignored since key exists), invertion will fail
          k = randomNewKey(operand);
          // All clients should start with the same initial value
          var obj = {'alwaysSameInitialValue': k};

          path.add(k);
          operand[k] = obj;
          op.add({'p':path, 'oin':clone(obj)});
        } else if ((randomReal() > 0.7 || k == null) && !_testOin) {
//        if (randomReal() > 0.7 || k == null) { 
          // Insert
          var k = randomNewKey(operand);
          var obj = randomThing();

          path.add(k);
          operand[k] = obj;
          op.add({'p':path, 'oi':clone(obj)});
        } else {
          var obj = operand[k];

          path.add(k);
          operand.remove(k);
          op.add({'p':path, 'od':clone(obj)});
        }
      }
    }
    return [op, container['data']];
  }
  
  @override
  dynamic serialize(doc) {
//    return JSON.encode(doc);
    return doc;
  }
  
  @override
  dynamic clone(obj) => JSON.decode(JSON.encode(obj));
}