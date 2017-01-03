part of otdartlib.atext_changeset;



class OpAttribute {
  static const REMOVE = '^';
  static const FORMAT = '*';
  
  final String opcode;
  final String key;
  final dynamic value;
  
  const OpAttribute._internal(this.opcode, this.key, this.value);
  const OpAttribute.format(this.key, this.value) : this.opcode = FORMAT;
  const OpAttribute.remove(this.key, this.value) : this.opcode = REMOVE;
  
  OpAttribute invert() => opcode == FORMAT ? new OpAttribute.remove(key, value) : new OpAttribute.format(key, value); 
  
  int get hashCode => hash3(opcode, key, value);

  bool get isFormat => opcode == FORMAT;
  bool get isRemove => opcode == REMOVE;
  
  bool operator==(other) => other is OpAttribute && opcode == other.opcode && key == other.key && value == other.value;

  String toString() => '$opcode#$key#$value';
}