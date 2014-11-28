part of otdartlib.atext_changeset;


/**
 * Base operation component class, incapsulates most common functions
 * over component data. Describes operation on the text block.
 */
class OpComponent implements Clonable {
  static const INSERT = '+';
  static const REMOVE = '-';
  static const KEEP = '=';
  
  String opcode;
  int chars;
  int lines;
  AttributeList attribs;
  String charBank;

  OpComponent([String opcode = '', int N = 0, int L = 0, AttributeList attribs, String charBank = '']) {
    if(opcode != null) {
      set(opcode, N, L, attribs, charBank);
    }
  }
  
  void set(String opcode, [int N = 0, int L = 0, AttributeList attribs, String charBank = '']) {
    if(opcode == null) throw new ArgumentError('opcode should be not null');
    
    this.opcode = opcode;
    this.chars = N;
    this.lines = L;
    this.attribs = attribs == null ? new AttributeList() : attribs;
    
    if(isInsert || isRemove) {
      if(lines > 0 && !charBank.endsWith('\n')) {
        throw new Exception('for multiline components charbank should end up with newline');
      }
      if(chars != charBank.length) {
        throw new Exception('charBank length should match chars in operation: expected $N got [$charBank]');
      }
      this.charBank = charBank;
    } else {
      // make sure charbank for KEEPs is erased
      this.charBank = '';
    }
  }
  
  void clear() => set('');
  
  bool get isEmpty => opcode == '' || opcode == null || chars == 0; 
  bool get isNotEmpty => !isEmpty;
  bool get isInsert => opcode == INSERT;
  bool get isRemove => opcode == REMOVE;
  bool get isKeep => opcode == KEEP;
  
  OpComponent inverted() {
    if(isInsert) {
      return clone(REMOVE);
    } else if (isRemove) {
      return clone(INSERT);
    } else {
      return clone()..attribs = attribs.invert();
    }
  }

  @override
  OpComponent clone([String newOpcode]) => copyTo(new OpComponent(null), newOpcode);

  OpComponent copyTo(OpComponent otherOp, [String newOpcode]) {
    return otherOp..set(newOpcode == null ? opcode : newOpcode, chars, lines, attribs, charBank);
  }

  /**
   * Removes N chars and L lines from the start of this component
   */
  void trimLeft(int N, int L) {
    if(chars < N || lines < L) {
      throw new Exception('op is too short for trimLeft: $chars < $N or $lines < $L');
    }
 
    chars -= N;
    lines -= L;
    if(!isKeep) {
      charBank = charBank.substring(N);
    }
  }
  
  /**
   * Keeps N chars and L lines and trim end of this component
   */
  void trimRight(int N, int L) {
    if(chars < N || lines < L) {
      throw new Exception('op is too short for trimRight: $chars < $N or $lines < $L');
    }
  
    chars = N;
    lines = L;
    if(!isKeep) {
      charBank = charBank.substring(0, N);
    }
  }

  
  void composeAttributes(AttributeList otherAtt) {
    attribs = attribs.compose(otherAtt, isComposition: isKeep);
  }

  void transformAttributes(AttributeList otherAtt) {
    attribs = attribs.transform(otherAtt);
  }

  void formatAttributes(AttributeList formatAtt) {
    attribs = attribs.format(formatAtt);
  }

  void invertAttributes([AttributeList exceptAtt]) {
    attribs = attribs.invert(exceptAtt);
  }
  
  /**
   * Append another component to this one
   */
  void append(OpComponent otherCmp) {
    if(otherCmp.chars > 0) {
      // allow appending to empty component
      if(chars == 0) {
        opcode = otherCmp.opcode;
        attribs = otherCmp.attribs.clone();
      } else if(opcode != otherCmp.opcode || attribs != otherCmp.attribs) {
        throw new Exception('cannot append op with different attribs or opcodes');
      }
    
      chars += otherCmp.chars;
      lines += otherCmp.lines;
      charBank += otherCmp.charBank;
    }
  }
  
  void skipIfEmpty() {
    if(chars == 0) {
      skip();
    }
  }
  
  void skip() {
    opcode = '';
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
  OpComponent takeLine() {
    var lineComp = clone();
    if(lines > 0) {
      var i = charBank.indexOf('\n');
      if(i >= 0) {
        lineComp.trimRight(i + 1, 1);
        trimLeft(i + 1, 1);
        skipIfEmpty();
      } else {
        skip();
      }
    } else {
      skip();
    }
    return lineComp;
  }
  
  int get deltaLen => isInsert ? chars : (isRemove ? -chars : 0);
  
  /**
   * Return attributes string for the component
   */
  AString pack(List pool) {
    if(opcode == null || this.opcode == '') {
      return new AString();
    }
    
    return new AString(
      atts: attribs.pack(pool) + (lines > 0 ? ('|' + _util.toString36(lines)) : '') + opcode + _util.toString36(chars),
      text: charBank,
      dLen: deltaLen
    );
  }
}