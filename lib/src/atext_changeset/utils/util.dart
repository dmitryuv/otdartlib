part of otdartlib.atext_changeset;

abstract class Clonable {
  dynamic clone();
}

class _util {
  static int parseInt36(String str) => int.parse(str, radix: 36);
  static String toString36(int num) => num.toRadixString(36);
}


abstract class _ChangesetMutatorBase {
  Changeset _cs;
  BackBufferIterator<OpComponent> _iter;
  ComponentList _res = new ComponentList();
  OpComponentSlicer _slicedOp;
  bool _eof = false;
  String _nonSplitOpcode;

  _ChangesetMutatorBase(this._cs, this._nonSplitOpcode) {
    _iter = _cs.iterator;
  }

  bool get eof => _eof;

  OpComponent _peek() {
    if(_slicedOp == null || _slicedOp.isEmpty) {
      while(_slicedOp == null) {
        if(!_iter.moveNext()) {
          _eof = true;
          return new OpComponent.empty();
        }
        _slicedOp = _iter.current.slicer;
      }
    }

    return _slicedOp.current;
  }

  OpComponent _take(int chars, int lines) {
    var op = _peek();
    OpComponent res;

    if(op.chars <= chars || op.opcode == _nonSplitOpcode) {
      // take whole
      res = op;
      _slicedOp = null;
    } else {
      // take part
      res = _slicedOp.next(chars, lines);
    }

    return res;
  }

  _finalize() {
    if(_slicedOp != null) {
      _res.add(_slicedOp.current);
    }
    while(_iter.moveNext()) {
      _res.add(_iter.current);
    }
  }

  format(OpComponentSlicer slicer);
  insert(OpComponentSlicer slicer);
  remove(OpComponentSlicer slicer);
  Changeset finish();
}

class ChangesetMutator extends _ChangesetMutatorBase {

  ChangesetMutator(Changeset cs) : super(cs, OpComponent.REMOVE);

  @override
  format(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);
    if(op.isEmpty) return;

    if(!op.isRemove) {
      // KEEPs and INSERTs can be reformatted
      var formatter = slicer.next(op.chars, op.lines);
      _res.add(op.composeAttributes(formatter.attribs));
    } else {
      // REMOVEs should be kept as-is, they do not count as SKIPs
      _res.add(op);
    }
  }

  @override
  remove(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);
    if(op.isEmpty) return;

    if(op.isRemove) {
      // keep original removes, they can't be affected
      _res.add(op);
    } else {
      var removal = slicer.next(op.chars, op.lines);
      if (op.isKeep) {
        // KEEPs should be removed, FORMATs should be undo'ed and removed, INSERTS are dropped
        _res.add(op.isFormat ? removal.composeAttributes(op.attribs.invert()) : removal);
      } else if(!op.equalsButOpcode(removal)) {
        // op is INSERT, and we removed somethign wrong from it
        throw new Exception('removed in composition does not match original "${op.charBank.hashCode}" != "${removal.charBank.hashCode}"');
      }
    }
  }

  @override
  insert(OpComponentSlicer slicer) {
    _res.add(slicer.next(slicer.current.chars, slicer.current.lines));
  }

  @override
  Changeset finish() {
    _finalize();

    return new Changeset(_res, _cs._oldLen, author: _cs._author, newLen: _cs._oldLen + _res.deltaLen);
  }
}


class ChangesetTransformer extends _ChangesetMutatorBase {
  String _side;

  ChangesetTransformer(Changeset cs, this._side) : super(cs, OpComponent.INSERT);

  @override
  format(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);
    if(op.isEmpty) return;

    if(!op.isInsert) {
      // KEEPs and REMOVEs can be reformatted
      var formatter = slicer.next(op.chars, op.lines);
      if(op.isKeep) {
        _res.add(op.transformAttributes(formatter.attribs));
      } else {
        _res.add(op.composeAttributes(formatter.attribs));
      }
    } else {
      // INSERTs should be kept as-is, they do not count as SKIPs
      _res.add(op);
    }
  }

  @override
  remove(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);
    if(op.isEmpty) return;

    if(op.isInsert) {
      // keep original inserts, they can't be affected
      _res.add(op);
    } else {
      slicer.next(op.chars, op.lines);
    }
  }

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
      _res.add(new OpComponent.createKeep(op.chars, op.lines));
      slicer.next(op.chars, op.lines);
    } else {
      _res.add(_take(current.chars, current.lines));
    }
  }

  @override
  Changeset finish(int newLen) {
    _finalize();

    return new Changeset(_res, newLen, author: _cs._author, newLen: newLen + _res.deltaLen);
  }
}