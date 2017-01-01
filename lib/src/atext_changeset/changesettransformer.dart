part of otdartlib.atext_changeset;

class ChangesetTransformer extends _MutatorBase implements OperationComposer<Changeset> {
  Changeset _cs;
  String _side;
  int _newLen;

  ChangesetTransformer(this._cs, this._side, this._newLen)
    : super(_cs.iterator, OpComponent.INSERT);

  @override
  _insert(OpComponentSlicer slicer) {
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
      _add(new OpComponent.keep(op.chars, op.lines));
      slicer.next(op.chars, op.lines);
    } else {
      _add(_take(current.chars, current.lines));
    }
  }

  @override
  _remove(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);

    if(op.isInsert) {
      // keep original inserts, they can't be affected
      _add(op);
    } else {
      var removal = slicer.next(op.chars, op.lines);
      if(op.isRemove && !removal.equalsButOpcode(op)) {
        throw new Exception('removed in transformation does not match original "${op.charBank.hashCode}" != "${removal.charBank.hashCode}"');
      }
    }
  }

  @override
  _format(OpComponentSlicer slicer) {
    var op = _take(slicer.current.chars, slicer.current.lines);

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