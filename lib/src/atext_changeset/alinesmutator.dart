part of otdartlib.atext_changeset;


/*
 * This mutator works with lines of AStrings. It supports multiline ops and can 
 * efficiently patch multiline structure in place.
 */
class ALinesMutator {
  final List _lines;
  final List _pool;
  int _l = 0;
  AStringMutator _curLine;
  
  ALinesMutator(this._lines, this._pool);


  int _skipLines(int L) {
    if(_l + L > _lines.length) {
      throw new Exception('line position became greater than lines count');
    }

    var n = 0;
    if(_curLine != null) {
      n += this._curLine.remaining;
      _nextLine();
      L--;
    }
    // unlike _takeLines(), we do not parse each next line, just take the length
    for(var x = _l + L; _l < x; _l++) {
      n += AString.packedLength(_lines[_l]);
    }
    return n;
  }

  ComponentList _takeLines(int L) {
    if(_l + L > _lines.length) {
      throw new Exception('line position became greater than lines count');
    }
  
    var ops = new ComponentList();
    while(L-- > 0) {
      ops.addAll(_getCurLine().takeRemaining());
      _nextLine();
    }
    return ops;
  }
  
  AStringMutator _getCurLine() {
    if(_curLine == null) {
      var line = _l >= _lines.length ? new AString() : new AString.unpack(_lines[_l]);
      _curLine = new AStringMutator(line, _pool);
    }
    return _curLine;
  }

  void _closeCurLine() {
    if(_curLine != null) {
      // fix for case with inserting into empty document - we must store first line that doesn't
      // exists in collection yet
      var packed = _curLine.finish().pack();
      if(_l < _lines.length) {
        _lines[_l] = packed;
      } else if(_l == _lines.length) {
        _lines.add(packed);
      } else {
        throw new Exception('trying to insert after the end of lines array');
      }
      _curLine = null;
    }
  }
  
  void _nextLine() {
    _closeCurLine();
    _l++;
  }
  
  void skip(int N, int L) {
    if(L > 0) {
      var n = _skipLines(L);
      if(n != N) {
        throw new Exception('N does not match actual chars in multiline op');
      }
    } else {
      // assertion is done in AStringMutator
      _getCurLine().skip(N);
    }
  }

  ComponentList take(int N, int L) {
    if(L > 0) {
      var ops = _takeLines(L);
      int n = ops.fold(0, (prev, op) => prev + op.chars);
      if(n != N) {
        throw new Exception('N does not match actual chars in multiline op');
      }
      return ops;
    } else {
      return _getCurLine().take(N);
    }
  }
  
  /**
   * Remove N chars and L lines from the alines list and return an array of components.
   * Caller can analyze these components to compare actual removed data with what was intended to remove.
   */
  ComponentList remove(int N, int L) {
    var removed = new ComponentList();
    
    void removeLines(int start, int end, [skipFirstTake = false]) {
      removed.addAll(
          _lines
            .getRange(start + (skipFirstTake ? 1 : 0), end)
            .expand((l) => new ComponentList.unpack(new AString.unpack(l), _pool))
            );
      _lines.removeRange(start, end);      
    };

    if(L > 0) {
      var curLine = _getCurLine();
  
      if(curLine.position == 0) {
        bool skip = curLine.isMutated;
        if(skip) {
          removed.addAll(curLine.takeRemaining());
        }
        // we haven't yet iterated over current line, just remove entire range
        removeLines(_l, _l + L, skip);
        _curLine = null;
      } else {
        // first, take the rest of the current line, including newline
        // (that will result in joining with the next line after remove)
        removed.addAll(curLine.remove(curLine.remaining));        
        // now continue from second line and remove more, collecting removed data
        removeLines(_l + 1, _l + L);
   
        // now join next line with the rest of the current line
        if((_l + 1) < _lines.length) {
          var line = _lines.removeAt(_l + 1); 
          new ComponentList.unpack(new AString.unpack(line), _pool)
            .reversed
            .forEach(curLine.inject);
        }
      }
      // do a basic check that requested number of chars match actually removed
      var n = removed.fold(0, (prev, op) => prev + op.chars);
      if(n != N) {
        throw new Exception('N does not match actual chars in multiline op: $n != $N');
      }
    } else {
      // check is done in AStringMutator
      removed = _getCurLine().remove(N);
    }
    return removed;
  }

  /**
   * Insert a single (multiline) component into current position
   */
  void insert(OpComponent opc) {
    var curLine = _getCurLine();
    var removeLines = 0;
    AString extraLine = null;
    var newLines = [];
  
    if(opc.lines > 0) {
      var slicer = opc.slicer;

      var linesToAdd = opc.lines;
      if(curLine.position != 0 || curLine.isMutated) {
        // append to the current line and move tail to the new line
        extraLine = curLine.remove(curLine.remaining).toAString(_pool);
        // current line was iterated, means we'll need to split it, and join with the next line
        // producing extra line to replace
        removeLines = 1;

        curLine.insert(slicer.nextLine());
        newLines.add(curLine.finish().pack());
      }

      while(slicer.isNotEmpty) {
        var c = new ComponentList()..add(slicer.nextLine());
        newLines.add(c.pack(_pool));
      }
      if(extraLine != null && extraLine.isNotEmpty) {
        newLines.add(extraLine.pack());
      }
  
      // now replace old lines with new insertions
      _lines.replaceRange(_l,  (_l + removeLines).clamp(0, _lines.length), newLines);
      // move position and reset line iterator
      _l += linesToAdd;
      _curLine = null;
    } else {
      _getCurLine().insert(opc);
    }
  }
  
  void applyFormat(OpComponent opc) {
    if(opc.lines > 0) {
      var slicer = opc.slicer;
      // format line by line
      while(slicer.isNotEmpty) {
        var line = _getCurLine();
        var len = line.remaining;
        var fop = slicer.next(len, 1);

        line.applyFormat(fop);
        _nextLine();
      }
      if(slicer.current.lines != 0) {
        throw new Exception('chars in format operation does not match actual chars in the document');
      }
    } else {
      _getCurLine().applyFormat(opc);
    }
  }
  
  // TODO: used somewhere?
  int getLength() {
    int len = 0;
    for(var i = 0, l = _lines.length; i < l; i++) {
      if(i == _l && _curLine != null) {
        len += _curLine.length;
      } else {
        len += AString.packedLength(_lines[i]);
      }
    }
    return len;
  }
  
  Position get position => new Position(_curLine != null ? _curLine.position : 0, _l); 

  /**
   * Return number of remaining lines in the document, including current line
   */
  int get remaining => _lines.length - _l;
  
  int get lineRemaining => _getCurLine().remaining;

  List finish() {
    // make sure mutated line is finished
    _closeCurLine();
    // reset everything
    _l = 0;
    // cleanup after mutation 
    if(_lines.isNotEmpty && AString.packedLength(_lines.last) == 0) {
      // we can get empty line at the end by removing chars on unfinished lines (w/o trailing \n)
      // technically empty line and no lines at all is the same thing, but comparing documents before change
      // and document after reverted change can fail. To make docs consistent, just drop trailing empty lines.
      _lines.removeLast();
    }
    return _lines;
  }
}
