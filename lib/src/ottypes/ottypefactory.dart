part of otdartlib.ottypes;

class OTTypeFactory<T, E> extends OTType<T, E> {
  static final _types = <String, OTTypeFactory>{
    'atext': new OT_atext(),
    'json0': new OT_json0(),
    'text0': new OT_text0()
  };
  
  OTTypeFactory();
  
  factory OTTypeFactory.from(String name) {
    if(!_types.containsKey(name)) {
      throw new Exception('Unknown type name: $name');
    }
    return _types[name] as OTTypeFactory<T, E>;
  }  

  @override
  T apply(T doc, E op) {
    throw new Exception('not implemented');
  }

  @override
  compose(E op1, E op2) {
    throw new Exception('not implemented');
  }

  @override
  create([initial]) {
    throw new Exception('not implemented');
  }

  @override
  invert(E op) {
    throw new Exception('not implemented');
  }

  @override
  String get name => throw new Exception('not implemented');

  @override
  transform(E op, E otherOp, String side) {
    throw new Exception('not implemented');
  }

  @override
  String get uri => throw new Exception('not implemented');
}