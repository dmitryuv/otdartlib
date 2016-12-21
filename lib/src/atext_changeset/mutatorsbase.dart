part of otdartlib.atext_changeset;

abstract class OperationComposer<T> {
  apply(OpComponent op);

  T finish();
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

    return res.isEmpty && !eof ? _take(chars, lines) : res;
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

  _apply(OpComponentSlicer slicer) {
    var op = slicer.current;

    while (!_eof && slicer.isNotEmpty) {
      if (op.isInsert) {
        _insert(slicer);
      } else if (op.isRemove) {
        _remove(slicer);
      } else if (op.isSkip) {
        _skip(slicer);
      } else {
        _format(slicer);
      }
    }
  }

  _insert(OpComponentSlicer slicer);
  _remove(OpComponentSlicer slicer);
  _format(OpComponentSlicer slicer);
  // default implementation is the same case as FORMAT op
  _skip(OpComponentSlicer slicer) =>_format(slicer);

  apply(OpComponent op) => _apply(op.slicer);
}

class _ChangesetComposerBase extends _MutatorBase {
  _ChangesetComposerBase(Iterator<OpComponent> opsIterator, String skipOpcode)
    : super(opsIterator, skipOpcode);

  @override
  _insert(OpComponentSlicer slicer) {
    _add(slicer.current);
    slicer.reset();
  }

  @override
  _remove(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);

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
  _format(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);

    if(!op.isRemove) {
      // KEEPs and INSERTs can be reformatted
      var formatter = slicer.next(op.chars, op.lines);
      _add(op.composeAttributes(formatter.attribs));
    } else {
      // REMOVEs should be kept as-is, they do not count as SKIPs
      _add(op);
    }
  }

  // for composition, operation can have leftovers in case target oplist finished, that should be inserted
  @override
  apply(OpComponent op) {
    var slicer = op.slicer;
    _apply(slicer);
    if(slicer.isNotEmpty) {
      _insert(slicer);
    }
  }
}
