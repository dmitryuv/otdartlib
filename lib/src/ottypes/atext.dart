/*
 * ShareJS ottype API spec support
 */
part of otdartlib.ottypes;

class OT_atext extends OTTypeFactory<ADocument, Changeset> {
  static final _name = 'atext';
  static final _uri = 'https://github.com/dmitryuv/atext-changeset';
  
  ADocument create([initial]) {
    if(initial != null && initial is! String) {
      throw new Exception('Initial data must be a string');
    }

    if(initial != null) {
      return new ADocument.fromText(initial as String);
    } else {
      return new ADocument();
    }
  }
  
  @override
  String get name => _name;
  
  @override
  String get uri => _uri;
  
  @override
  ADocument apply(ADocument doc, Changeset op) {
    return op.applyTo(doc);
  }

  @override
  Changeset compose(Changeset op1, Changeset op2) {
    return op1.compose(op2);
  }

  @override
  Changeset invert(Changeset op) {
    return op.invert();
  }

  @override
  Changeset transform(Changeset op, Changeset otherOp, String side) {
    return op.transform(otherOp, side);
  }

  Position transformPosition(Position p, Changeset otherOp, String side) {
    return p.transform(otherOp, side);
  }
}
