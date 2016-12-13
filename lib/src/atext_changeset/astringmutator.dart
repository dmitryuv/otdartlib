part of otdartlib.atext_changeset;

/**
 * Attributed string mutator. Can iterate or mutate supplied string.
 * String should be a single line. No multi-line mutations are allowed, except
 * appending a newline character at the end.
 */
class AStringMutator {
  final AString _astr;
  final List _pool;
  BackBufferIterator<OpComponent> _iter;
  ComponentList _iteratedOps = new ComponentList();
  OpComponent _current = null;
  bool _mutated = false;
  bool _iterFoundNewline = false;
  bool _hasNewline;
  int _len;
  int _n = 0;

  AStringMutator(this._astr, this._pool) {
    _iter = new ComponentList.unpack(_astr, _pool).iterator;
    _len = _astr.text.length;
    _hasNewline = _astr.text.endsWith('\n');
  }

  int get position => _n;

  int get remaining => _len - _n;
  
  int get length => _len;
  
  bool get isMutated => _mutated;

  ComponentList _take(int N) {
    var ops = new ComponentList();
    while(N > 0) {
      if(_current == null || _current.isEmpty) {
        if(!_iter.moveNext()) {
          throw new Exception('unexpected end of astring');
        }
        _current = _iter.current;

        if(!_current.isInsert || (_current.lines == 1 && _iterFoundNewline) || _current.lines > 1) {
          throw new Exception('cannot iterate over non-astring (should contain only inserts and single newline)');
        }
        if(_current.lines == 1) {
          _iterFoundNewline = true;
        }
      }

      if(_current.chars <= N) {
        // take all and continue
        ops.add(_current);
        N -= _current.chars;
        _current = null;
      } else {
        // take part
        ops.add(_current.sliceLeft(N, 0));
        _current = _current.sliceRight(N, 0);
        N = 0;
      }
    }

    return ops;
  }

  _validateInsert(OpComponent opc) {
    if(!opc.isInsert) {
      throw new Exception('bad opcode for insertion: ${opc.opcode}');
    }
    if(opc.lines > 0) {
      if(opc.lines != 1 || this.remaining > 0) {
        throw new Exception('single newline is accepted only at the end of the string');
      }
      if(_hasNewline) {
        throw new Exception('astring already have newline');
      }
   
      _hasNewline = true;
    }
  }
  
  void skip(int N) {
    take(N); // drop the result
  }

  /**
   * Take N chars from a string and return components list
   */
  ComponentList take(int N) {
    var ops = _take(N);
    _n += N;
    // save a copy to internal collection in case of string mutation
    _iteratedOps.addAll(ops);
    return ops;
  }

  /**
   * Remove N chars from a string and return removed components list
   */
  ComponentList remove(int N) {
    _mutated = true;
    _len -= N;
    // take but do not advance
    var removed = _take(N);
    if(removed.isNotEmpty && removed.last.lines > 0) {
      // if we've just removed newline, clear the flag
      _hasNewline = false;
      // also reset flag for iterator
      _iterFoundNewline = false;
    }
    return removed;
  }

  /**
   * Insert a single component into current string position
   */
  void insert(OpComponent opc) {
    _validateInsert(opc);
    _mutated = true;
    _iteratedOps.add(opc);
    _len += opc.chars;
    _n += opc.chars;
  }

  /**
   * Does what insert does, but does not updates current iterator position
   */
  void inject(OpComponent opc) {
    _validateInsert(opc);
    _iter.pushBack(opc);
    _mutated = true;
    _len += opc.chars;
  }
  

  // TODO: naming is probably confusing either here, or 
  // in AttributeList.format(). Same name but different meaning
  void applyFormat(OpComponent opc) {
    var valid = opc.lines == 0 || (opc.lines == 1 && opc.chars == remaining);
    if(!opc.isKeep || !valid) {
      throw new Exception('bad format component');
    }
  
    // here we must apply format to all components
    _iteratedOps.addAll(
      _take(opc.chars).map((c) => c.composeAttributes(opc.attribs))
      );
    _n += opc.chars;
    _mutated = true;
  }

  
  ComponentList takeRemaining() => take(remaining);

  AString finish() {
    if(_mutated) {
      // append the rest
      takeRemaining();
      // repack all ops
      return _iteratedOps.toAString(_pool);
    }
    return this._astr;
  }
}