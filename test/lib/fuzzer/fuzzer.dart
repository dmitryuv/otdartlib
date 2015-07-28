// the code is port of https://github.com/ottypes/fuzzer
part of otdartlib.fuzzer;

class Fuzzer {
  FuzzerImpl _impl;
  
  Fuzzer(this._impl);
  
  //# Cross-transform function. Transform server by client and client by server. Returns
  //# [server, client].
  List _transformX(type, left, right) => 
    [type.transform(left, right, 'left'), type.transform(right, left, 'right')];

  //# Transform a list of server ops by a list of client ops.
  //# Returns [serverOps', clientOps'].
  //# This is O(serverOps.length * clientOps.length)
  List _transformLists(type, serverOps, clientOps) {
    //#p "Transforming #{i serverOps} with #{i clientOps}"
    serverOps = serverOps.map((s) {
      clientOps = clientOps.map((c) {
        //#p "X #{i s} by #{i c}"
        var res = _transformX(type, s, c);
        s = res[0];
        return res[1];
      }).toList();
      return s;
    }).toList();
    
    return [serverOps, clientOps];
  }

  //# Compose a whole list of ops together
  _composeList(type, ops) => ops.reduce(type.compose);

  //# Hax. Apparently this is still the fastest way to deep clone an object,
  //# assuming we have support for JSON.
  //#
  //# This is needed because calling apply() now destroys the original object.
  dynamic _clone(o) => _impl.clone(o);
  
  //# Returns client result
  _testRandomOp(_OTWrapper type, genRandomOp, [initialDoc]) {
    if(initialDoc == null) initialDoc = type.create(); 
  
    _Doc makeDoc() => new _Doc(initialDoc);

    var opSets = [makeDoc(), makeDoc(), makeDoc()];
    
    var client = opSets[0];
    var client2 = opSets[1];
    var server = opSets[2];
    
    for(var i = 0; i < 10; i++) {
      var doc = opSets[_RandomUtils.randomInt(3)];
      var res = genRandomOp(doc.result);
      doc.result = res[1];
      doc.ops.add(res[0]);
    }
  
    //p "Doc #{i initialDoc} + #{i ops} = #{i result}" for {ops, result} in [client, client2, server]
  
    void checkSnapshotsEq(a, b) {
      expect(_impl.serialize(a), equals(_impl.serialize(b)));
    }
  
    //# First, test type.apply.
    for(var set in opSets) {
      var s = set.ops.fold(_clone(initialDoc), type.apply);
  
      checkSnapshotsEq(s, set.result);
    }
  
    testInvert(_Doc doc, [ops]) {
     if(ops == null) ops = doc.ops; 

      var snapshot = ops
        .reversed
        .map(type.invert)
        .fold(_clone(doc.result), type.apply);

      checkSnapshotsEq(snapshot, initialDoc);
    }

    if(true) {
      //# Invert all the ops and apply them to result. Should end up with initialDoc.
      opSets.forEach(testInvert);
    }
  
    //# If all the ops are composed together, then applied, we should get the same result.
    if(true) {
      compose(_Doc doc) {
        if(doc.ops.length > 0) {
          doc.composed = _composeList(type, doc.ops);
          //# .... And this should match the expected document.
          checkSnapshotsEq(doc.result, type.apply(_clone(initialDoc), doc.composed));
        }
      }
  
      opSets.forEach(compose);
  
      opSets.forEach((set) {
        if(set.composed != null) {
          testInvert(set, [set.composed]);
        }
      });
    
      //# Check the diamond property holds
      if(client.composed != null && server.composed != null) {
        var res = _transformX(type, server.composed, client.composed);
        var server_ = res[0];
        var client_ = res[1];
  
        var s_c = type.apply(_clone(server.result), client_);
        var c_s = type.apply(_clone(client.result), server_);
  
        //# Interestingly, these will not be the same as s_c and c_s above.
        //# Eg, when:
        //#  server.ops = [ [ { d: 'x' } ], [ { i: 'c' } ] ]
        //#  client.ops = [ 1, { i: 'b' } ]
        checkSnapshotsEq(s_c, c_s);
      }
    }

  
    //# Now we'll check the n^2 transform method.
    if(client.ops.length > 0 && server.ops.length > 0) {
      //p "s #{i server.result} c #{i client.result} XF #{i server.ops} x #{i client.ops}"
      var res = _transformLists(type, server.ops, client.ops);
      var s_ = res[0];
      var c_ = res[1];

      //p "XF result #{i s_} x #{i c_}"
      //#    p "applying #{i c_} to #{i server.result}"
      var s_c = c_.fold(_clone(server.result), type.apply);
      var c_s = s_.fold(_clone(client.result), type.apply);
  
      checkSnapshotsEq(s_c, c_s);
  
      //# ... And we'll do a round-trip using invert().
      var c_inv = c_.reversed.map(type.invert);
      var server_result_ = c_inv.fold(_clone(s_c), type.apply);
      checkSnapshotsEq(server.result, server_result_);
      var orig_ = server.ops.reversed.map(type.invert).fold(server_result_, type.apply);
      checkSnapshotsEq(orig_, initialDoc);
    }
    
    return client.result;
  }

  //# Run some iterations of the random op tester. Requires a random op generator for the type.
  runTest(type, [int iterations = 2000]) {
    type = new _OTWrapper(type);
  
    print("   Running ${iterations} randomized tests for type ${type.name}...");
    print("     (seed: ${_RandomUtils.seed})");
  
    var doc = type.create();
  
    print('randomizer');
    var start = new DateTime.now().millisecondsSinceEpoch;
    
    int iterationsPerPct = iterations ~/ 100;
    for(var n = 0; n <= iterations; n++) {
      if(n % (iterationsPerPct * 2) == 0) {
        var progress = n % (iterationsPerPct * 10) == 0 ? '${n ~/ iterationsPerPct}' : '.';
        stdout.write('$progress');
      }
      doc = _testRandomOp(type, _impl.generateRandomOp, doc);
    }
    print('');
  
    var end = new DateTime.now().millisecondsSinceEpoch;
    print('randomizer, took ${((end-start) / 1000).toStringAsFixed(3)}ms');
  
    type.printStats();
  }
}
  
class _OTWrapper extends OTType {
  int _apply = 0;
  int _compose = 0;
  int _invert = 0;
  int _transform = 0;
  
  var _type;
  
  _OTWrapper(this._type);
   
  @override
  String get name => _type.name;
  
  @override
  String get uri => _type.uri;
  
  @override
  create([initial]) => _type.create(initial);
  
  @override
  apply(doc, op) {
    _apply++;
    return _type.apply(doc, op);
  }

  @override
  compose(op1, op2) {
    _compose++;
    return _type.compose(op1, op2);
  }

  @override
  invert(op) {
    _invert++;
    return _type.invert(op);
  }

  @override
  transform(op, otherOp, String side) {
    _transform++;
    return _type.transform(op, otherOp, side);
  }
  
  printStats() {
    print('Performed:');
    print('\ttransforms: $_transform');
    print('\tcomposes: $_compose');
    print('\tapplys: $_apply');
    print('\tinverts: $_invert');
  }
}


class _Doc {
  List ops = [];
  var result;
  List composed;
  
  _Doc(this.result);
}

