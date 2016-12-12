part of otdartlib.atext_changeset;


/**
 * Base operation component class, incapsulates most common functions
 * over component data. Describes operation on the text block.
 */
class OpComponent {
  static const INSERT = '+';
  static const REMOVE = '-';
  static const KEEP = '=';
  
  final String opcode;
  final int chars;
  final int lines;
  final AttributeList attribs;
  final String charBank;


  // TODO: rename for consistency with OpAttribute -> insert
  OpComponent.createInsert(this.chars, this.lines, this.attribs, this.charBank) : opcode = INSERT {
    _validate();
  }
  OpComponent.createRemove(this.chars, this.lines, this.attribs, this.charBank) : opcode = REMOVE {
    _validate();
  }
  OpComponent.createKeep(this.chars, this.lines) : opcode = KEEP, charBank = '', attribs = new AttributeList() {
    _validate();
  }
  OpComponent.createFormat(this.chars, this.lines, this.attribs) : opcode = KEEP, charBank = '' {
    _validate();
  }
  OpComponent(this.opcode, this.chars, this.lines, this.attribs, this.charBank) {
    _validate();
  }

  OpComponent.empty() : opcode = '', chars = 0, lines = 0, attribs = new AttributeList(), charBank = '';
  
  void _validate() {
    if(opcode == null) throw new ArgumentError('opcode should be not null');
    if(attribs == null) throw new ArgumentError('attribs should not be null');

    if(isInsert || isRemove) {
      if(lines > 0 && !charBank.endsWith('\n')) {
        throw new Exception('for multiline components charbank should end up with newline');
      }
      if(chars != charBank.length) {
        throw new Exception('charBank length should match chars in operation: expected $chars got [${charBank.length}]');
      }
    }
  }

  bool get isEmpty => opcode == '' || opcode == null || chars == 0; 
  bool get isNotEmpty => !isEmpty;
  bool get isInsert => opcode == INSERT;
  bool get isRemove => opcode == REMOVE;
  bool get isKeep => opcode == KEEP;

  OpComponentSlicer get slicer => new OpComponentSlicer(this);
  
  OpComponent invert() {
    if(isInsert) {
      return new OpComponent.createRemove(chars, lines, attribs, charBank);
    } else if (isRemove) {
      return new OpComponent.createInsert(chars, lines, attribs, charBank);
    } else {
      return new OpComponent.createFormat(chars, lines, attribs.invert());
    }
  }

  /**
   * Returns slice with N chars and L lines from the start of this component
   */
  OpComponent sliceLeft(int N, int L) {
    if(chars < N || lines < L) {
      throw new Exception('op is too short for sliceLeft: $chars < $N or $lines < $L');
    }

    return new OpComponent(opcode, N, L, attribs, isKeep ? charBank : charBank.substring(0, N));
  }
  
  /**
   * Keeps N chars and L lines and return slice with the remainder of this component
   */
  OpComponent sliceRight(int N, int L) {
    if(chars < N || lines < L) {
      throw new Exception('op is too short for sliceRight: $chars < $N or $lines < $L');
    }

    return new OpComponent(opcode, chars - N, lines - L, attribs, isKeep ? charBank : charBank.substring(N));
  }

  OpComponent composeAttributes(AttributeList otherAtt) {
    return new OpComponent(opcode, chars, lines, attribs.compose(otherAtt, isComposition: isKeep), charBank);
  }

  OpComponent transformAttributes(AttributeList otherAtt) {
    return new OpComponent(opcode, chars, lines, attribs.transform(otherAtt), charBank);
  }

  OpComponent formatAttributes(AttributeList formatAtt) {
    return new OpComponent(opcode, chars, lines, attribs.format(formatAtt), charBank);
  }

  OpComponent invertAttributes([AttributeList exceptAtt]) {
    return new OpComponent(opcode, chars, lines, attribs.invert(exceptAtt), charBank);
  }
  
  /**
   * Append another component to this one
   */
  OpComponent append(OpComponent otherCmp) {
    if(otherCmp.chars > 0) {
      // allow appending to empty component
      if(isEmpty) {
        return otherCmp;
      } else if(opcode != otherCmp.opcode || attribs != otherCmp.attribs) {
        throw new Exception('cannot append op with different attribs or opcodes');
      }
      return new OpComponent(opcode, chars + otherCmp.chars, lines + otherCmp.lines, attribs, charBank + otherCmp.charBank);
    } else {
      return this;
    }
  }
  
  bool operator==(other) => equalsButOpcode(other) && opcode == other.opcode; 
  
  bool equalsButOpcode(other) => other is OpComponent 
      && chars == other.chars 
      && lines == other.lines 
      && attribs == other.attribs
      // if one of the ops is KEEP, don't check charBank
      && ((isKeep || other.isKeep) || (charBank == other.charBank));

  /**
   * For multiline components, return new component with single line and trimLeft current
   */
//  OpComponent takeLine() {
//    var lineComp = clone();
//    if(lines > 0) {
//      var i = charBank.indexOf('\n');
//      if(i >= 0) {
//        lineComp.trimRight(i + 1, 1);
//        trimLeft(i + 1, 1);
//        skipIfEmpty();
//      } else {
//        skip();
//      }
//    } else {
//      skip();
//    }
//    return lineComp;
//  }
//
  int get deltaLen => isInsert ? chars : (isRemove ? -chars : 0);
  
  /**
   * Return attributes string for the component
   */
  AString pack(List pool) {
    if(opcode == null || opcode == '') {
      return new AString();
    }
    
    return new AString(
      atts: attribs.pack(pool) + (lines > 0 ? ('|' + _util.toString36(lines)) : '') + opcode + _util.toString36(chars),
      text: charBank,
      dLen: deltaLen
    );
  }
}

class OpComponentSlicer {
  OpComponent _op;

  OpComponentSlicer(this._op);

  bool get isEmpty => _op.isEmpty;
  bool get isNotEmpty => _op.isNotEmpty;
  OpComponent get current => _op;

  OpComponent next(int chars, int lines) {
    var res = _op.sliceLeft(chars, lines);
    _op = _op.sliceRight(chars, lines);
    return res;
  }

  OpComponent nextLine() {
    if(_op.lines > 0) {
      var i = _op.charBank.indexOf('\n');
      if(i < 0) {
        throw new Exception('op.lines > 0 but charBank does not contain newlines');
      }
      return next(i + 1, 1);
    }
    return next(_op.chars, 0);
  }
}