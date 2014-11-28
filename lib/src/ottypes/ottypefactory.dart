part of otdartlib.ottypes;

class OTTypeFactory<T, E> extends OTType<T, E> {
  static final _types = {
    'atext': new OT_atext(),
    'json0': new OT_json0(),
    'text0': new OT_text0()
  };
  
  OTTypeFactory();
  
  factory OTTypeFactory.from(String name) {
    if(!_types.containsKey(name)) {
      throw new Exception('Unknown type name: $name');
    }
    return _types[name];
  }  

  @override
  apply(doc, op) { 
    throw new Exception('not implemented');
  }

  @override
  compose(op1, op2) { 
    throw new Exception('not implemented');
  }

  @override
  create([initial]) { 
    throw new Exception('not implemented');
  }

  @override
  invert(op) { 
    throw new Exception('not implemented');
  }

  @override
  String get name => throw new Exception('not implemented');

  @override
  transform(op, otherOp, String side) { 
    throw new Exception('not implemented');
  }

  @override
  String get uri => throw new Exception('not implemented');
}