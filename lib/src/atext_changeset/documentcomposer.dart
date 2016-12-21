part of otdartlib.atext_changeset;

class DocumentComposer extends _ChangesetComposerBase implements OperationComposer {
  Iterator<Map> _lines;
  List _pool;
  List<Map> _outLines = <Map>[];

  DocumentComposer(ADocument doc)
    : super(new Iterable<OpComponent>.empty().iterator, '') {
    _lines = doc.iterator;
    _pool = new List.from(doc.pool);
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
  _skip(OpComponentSlicer slicer) {
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
      super._skip(slicer);
    }
  }

  // provide number of lines for additional document validation
  ComponentList takeChars(int chars, [int lines = null]) {
    var list = new ComponentList();
    while(chars > 0 && !eof) {
      var op = _peek();
      if(chars >= op.chars) {
        op = _take(op.chars, op.lines);
      } else {
        op = _take(chars, 0);
      }
      chars -= op.chars;
      list.add(op);
    }
    if(chars > 0) {
      throw new Exception('Failed to iterate all requested ops, ($chars) chars left');
    }
    var l = list.fold(0, (prev, next) => prev + next.lines);
    if(lines != null && lines != l) {
      throw new Exception('Requested lines ($lines) does not match lines in requested range ($l)');
    }
    return list;
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

    return new ADocument._(_outLines, _pool);
  }
}