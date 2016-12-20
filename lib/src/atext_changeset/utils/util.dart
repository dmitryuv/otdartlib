part of otdartlib.atext_changeset;

abstract class Clonable {
  dynamic clone();
}

class _util {
  static int parseInt36(String str) => int.parse(str, radix: 36);
  static String toString36(int num) => num.toRadixString(36);
}


class ChangesetComposer extends _ChangesetComposerBase {
  Changeset _cs;

  ChangesetComposer(this._cs) : super(_cs.iterator, OpComponent.REMOVE);

  Changeset finish() {
    _finalizeIterator();

    return new Changeset(_out, _cs._oldLen, author: _cs._author, newLen: _cs._oldLen + _out.deltaLen);
  }
}

class ChangesetTransformer extends _MutatorBase {
  Changeset _cs;
  String _side;
  int _newLen;

  ChangesetTransformer(this._cs, this._side, this._newLen)
    : super(_cs.iterator, OpComponent.INSERT);

  @override
  insert(OpComponentSlicer slicer) {
    var current = _peek();
    var op = slicer.current;
    bool left = true;

    if(current.isInsert && op.isNotEmpty) {
      bool ln = current.charBank[0] == '\n';
      bool rn = op.charBank[0] == '\n';
      // if one of the inserts starts with a newlines, it goes last to not break lines, if both - use tie break
      left = ((ln || rn) && (ln != rn)) ? ln : (_side == 'left');
    }
    if(left) {
      // other op goes first
      _add(new OpComponent.createKeep(op.chars, op.lines));
      slicer.next(op.chars, op.lines);
    } else {
      _add(_take(current.chars, current.lines));
    }
  }

  @override
  remove(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);

    if(op.isInsert) {
      // keep original inserts, they can't be affected
      _add(op);
    } else {
      slicer.next(op.chars, op.lines);
    }
  }

  @override
  format(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);
    if(op.isEmpty) return;

    if(!op.isInsert) {
      // KEEPs and REMOVEs can be reformatted
      var formatter = slicer.next(op.chars, op.lines);
      if(op.isKeep) {
        _add(op.transformAttributes(formatter.attribs));
      } else {
        _add(op.composeAttributes(formatter.attribs));
      }
    } else {
      // INSERTs should be kept as-is, they do not count as SKIPs
      _add(op);
    }
  }

  Changeset finish() {
    _finalizeIterator();

    return new Changeset(_out, _newLen, author: _cs._author, newLen: _newLen + _out.deltaLen);
  }
}

class DocumentComposer extends _ChangesetComposerBase {
  ADocument _doc;
  Iterator<Map> _lines;
  List _pool;
  List<Map> _outLines = <Map>[];

  DocumentComposer(this._doc)
    : super(new Iterable<OpComponent>.empty().iterator, '') {
    _lines = _doc.iterator;
    _pool = _doc.pool;
  }

  // logic is less compllicated if enitre method is redone instead of trying to reuse super.peek()
  @override
  OpComponent _peek() {
    while(_slicedOp.isEmpty) {
      if(!_iter.moveNext()) {
        if(!_lines.moveNext()) {
          _eof = true;
          return new OpComponent.empty();
        }
        _iter = new ComponentList.unpack(new AString.unpack(_lines.current), _pool).iterator;
      } else {
        _slicedOp = _iter.current.slicer;
      }
    }

    return _slicedOp.current;
  }

  @override
  _add(OpComponent op) {
    if(!op.isInsert) {
      throw new Exception('only inserts can be added to the document');
    }

    if(op.lines > 0) {
      var _slicer = op.slicer;
      while(_slicer.isNotEmpty) {
        _out.add(_slicer.nextLine());
        _outLines.add(_out.toAString(_pool).pack());
        _out.clear();
      }
    } else {
      _out.add(op);
    }
  }

  // this is an optimized version of overwise simple "take and put" alghorithm that
  // avoids parsing lines we do not touch by changeset
  @override
  skip(OpComponentSlicer slicer) {
    int lines = slicer.current.lines;
    if(lines > 0) {
      int chars = slicer.current.chars;
      // since we can have line merge cases, it's easier to just keep iterating
      // until we'll find end of the line
      while(!eof && lines == slicer.current.lines) {
        var op = _take(chars, lines);
        _add(op);
        chars -= op.chars;
        lines -= op.lines;
      }

      // skip rest of the lines directly without parsing
      while(lines > 0 && _lines.moveNext()) {
        _outLines.add(_lines.current);
        chars -= AString.packedLength(_lines.current);
        lines--;
      }

      // sanity check, line buffer should be empty at this point
      if(_out.isNotEmpty) {
        throw new Exception('finished line iterator but haven\'t found newline');
      }
      // lines should reach zero and number of removed chars should match
      if(chars != 0 || lines != 0) {
        throw new Exception('Number of chars left after skip does not equal to zero ($chars) '
          'or document unexpectedly ended with ($lines) more to skip');
      }
      // optimized version took everything at once
      slicer.reset();
    } else {
      super.skip(slicer);
    }
  }

  finish() {
    _finalizeIterator();
    // if line buffer is not empty and not a finished line, peek into next line to merge
    if(_out.isNotEmpty && _out.last.lines == 0 && _peek().isNotEmpty) {
      // peek'ing parses the line and starts new iterator, just walk through it
      _finalizeIterator();
    }

    bool unfinished = false;
    if(_out.isNotEmpty) {
      _outLines.add(_out.toAString(_pool).pack());
      unfinished = _out.last.lines == 0;
    }

    while(_lines.moveNext()) {
      if(unfinished) {
        throw new Exception('Failed to merge lines when finalizing the document');
      }
      _outLines.add(_lines.current);
    }
    _doc.replaceRange(0, _doc.length, _outLines);
  }
}

abstract class _MutatorBase {
  Iterator<OpComponent> _iter;
  OpComponentSlicer _slicedOp = new OpComponent.empty().slicer;
  bool _eof = false;
  String _nonSplitOpcode;
  ComponentList _out = new ComponentList();

  _MutatorBase(this._iter, this._nonSplitOpcode);

  bool get eof => _eof;

  OpComponent _peek() {
    if(_slicedOp.isEmpty) {
      if (!_iter.moveNext()) {
        _eof = true;
        _slicedOp.reset();
        return new OpComponent.empty();
      }
      _slicedOp = _iter.current.slicer;
    }

    return _slicedOp.current;
  }

  OpComponent _take(int chars, int lines) {
    var op = _peek();
    OpComponent res;

    if(op.chars <= chars || op.opcode == _nonSplitOpcode) {
      // take whole
      res = op;
      _slicedOp.reset();
    } else {
      // take part
      res = _slicedOp.next(chars, lines);
    }

    return res;
  }

  _add(OpComponent op) => _out.add(op);

  _finalizeIterator() {
    if(_slicedOp.isNotEmpty) {
      _add(_slicedOp.current);
      _slicedOp.reset();
    }
    while(_iter.moveNext()) {
      _add(_iter.current);
    }
  }

  apply(OpComponentSlicer slicer) {
    var op = slicer.current;

    while (!_eof && slicer.isNotEmpty) {
      if (op.isInsert) {
        insert(slicer);
      } else if (op.isRemove) {
        remove(slicer);
      } else if (op.isSkip) {
        skip(slicer);
      } else {
        format(slicer);
      }
    }
  }

  insert(OpComponentSlicer slicer);
  remove(OpComponentSlicer slicer);
  format(OpComponentSlicer slicer);
  // default implementation is the same case as FORMAT op
  skip(OpComponentSlicer slicer) => format(slicer);
}

class _ChangesetComposerBase extends _MutatorBase {
  _ChangesetComposerBase(Iterator<OpComponent> opsIterator, String skipOpcode)
    : super(opsIterator, skipOpcode);

  @override
  insert(OpComponentSlicer slicer) {
    _add(slicer.next(slicer.current.chars, slicer.current.lines));
  }

  @override
  remove(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);
    if(op.isEmpty) return;

    if(op.isRemove) {
      // keep original removes, they can't be affected
      _add(op);
    } else {
      var removal = slicer.next(op.chars, op.lines);
      if (op.isKeep) {
        // KEEPs should be removed, FORMATs should be undo'ed and removed, INSERTS are dropped
        _add(op.isFormat ? removal.composeAttributes(op.attribs.invert()) : removal);
      } else if(!op.equalsButOpcode(removal)) {
        // op is INSERT, and we removed somethign wrong from it
        throw new Exception('removed in composition does not match original "${op.charBank.hashCode}" != "${removal.charBank.hashCode}"');
      }
    }
  }

  @override
  format(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);
    if(op.isEmpty) return;

    if(!op.isRemove) {
      // KEEPs and INSERTs can be reformatted
      var formatter = slicer.next(op.chars, op.lines);
      _add(op.composeAttributes(formatter.attribs));
    } else {
      // REMOVEs should be kept as-is, they do not count as SKIPs
      _add(op);
    }
  }
}
