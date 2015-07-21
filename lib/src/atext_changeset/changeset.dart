part of otdartlib.atext_changeset;

/*
 * Construct a new changeset object. Usually changesets are not created directly, but by a Builder.
 *
 * @param {ComponentList} ops - a list of operations
 * @param {Number} oldLen - old len of the document that changeset is applied to
 * @param? {string} optAuthorId - optional author of the changeset
 * @param? {Number} optNewLen - optional length of the document after applied changeset. If not supplied,
 *                              will be calculated from the changeset data.
 */
class Changeset extends ComponentList {
  int _oldLen;
  int _newLen;
  String _author;
  
  static final _headerRegex = new RegExp(r'X:([0-9a-z]+)([><])([0-9a-z]+)|/');
  
  
  Changeset(Iterable<OpComponent> ops, this._oldLen, { String author, int newLen }) : super.from(ops) {
    _author = author;
    _newLen = newLen;
    
    if(_newLen == null) {
      _newLen = _oldLen + fold(0,  (prev, op) => prev + op.deltaLen);
    }
  }

  /**
   * Unpacks operation from storage object format and returns Changeset object.
   */
  Changeset.unpack(Map cs) {
    String op = cs['op'];
    
    var header = _headerRegex.matchAsPrefix(op);
    if(header == null) {
      throw new Exception('wrong changeset');
    }
  
    _oldLen = _util.parseInt36(header[1]);
    var sign = (header[2] == '>') ? 1 : -1;
    var delta = _util.parseInt36(header[3]);
    _newLen = _oldLen + sign * delta;
  
    var splitPos = op.indexOf(r'$');
    var charBank = splitPos < 0 ? '' : op.substring(splitPos + 1);
    var astr = new AString(atts: op.substring(header[0].length, splitPos < 0 ? null : splitPos), text: charBank);
    
    super._unpack(astr, cs['p']);
    _author = cs['u'];
  }
  
  /**
   * Create and return changeset builder
   */
  static Builder create(ADocument doc, { String author }) => new Builder(doc, author: author);

  
  // explanation for side = [left | right]
  // let's say we have thisOp coming to server after otherOp,
  // both creating a "tie" situation.
  // server has [otherOp, thisOp]
  // for server otherOp is already written, so it transforms thisOp
  // by otherOp, taking otherOp as first-win and thisOp as second.
  // In [otherOp, thisOp] list otherOp is on the "left"
  // 
  // Server sends its otherOp back to the client, but client already
  // applied thisOp operation, so his queue looks like
  // [thisOp, otherOp]
  // Client should transorm otherOp, and to get same results as server,
  // this time it should take otherOp as first-win. In the list
  // otherOp is to the "right"
  /**
   * Transform this changeset against other changeset.
   */
  Changeset transform(Changeset otherCS, String side) {
    if(_oldLen != otherCS._oldLen) {
      throw new Exception('changesets from different document versions cannot be transformed');
    }
    if(side != 'left' && side != 'right') {
      throw new Exception('side should be \'left\' or \'right\'');
    }
    
    sort();
    otherCS.sort();
  
    var dLen = 0;
    var newOps = _util.zip(this, otherCS, 
      (OpComponent thisOp, OpComponent otherOp) {
        // INSERTs are handled unsplitted, always
        var hasInsert = thisOp.isInsert || otherOp.isInsert;
        // KEEPs can be reduced by REMOVEs or extended by INSERTs
        var hasKeep = thisOp.isKeep || otherOp.isKeep;
        // REMOVEs can reduce KEEPs other REMOVEs
        var hasRemove = thisOp.isRemove || otherOp.isRemove; 
        // in both situation we can split ops into equal slices
        return (hasKeep || hasRemove) && !hasInsert;
      }, 
      (OpComponent thisOp, OpComponent otherOp, OpComponent opOut) {
        if(thisOp.isNotEmpty && otherOp.isNotEmpty && (thisOp.isInsert || otherOp.isInsert)) {
          bool left;
  
          var thisChar = thisOp.charBank.isNotEmpty ? thisOp.charBank[0] : '';
          var otherChar = otherOp.charBank.isNotEmpty ? otherOp.charBank[0] : '';
  
          if(thisOp.opcode != otherOp.opcode) {
            // the op that does insert goes first
            left = otherOp.isInsert;
          } else if((thisChar == '\n' || otherChar == '\n') && thisChar != otherChar) {
            // insert string that doesn't start with a newline first
            // to not break up lines
            left = otherChar != '\n';
          } else {
            left = side == 'left';
          }
  
          if(left) {
            // other op goes first
            opOut.set(OpComponent.KEEP, otherOp.chars, otherOp.lines);
            otherOp.skip();
          } else {
            thisOp.copyTo(opOut);
            thisOp.skip();
          }
        } else {
          // If otherOp is not removing something (that could mean it already removed thisOp)
          // then keep our operation
          if(thisOp.isNotEmpty && !otherOp.isRemove) {
            thisOp.copyTo(opOut);
            if(thisOp.isRemove && otherOp.isNotEmpty) {
              // if thisOp is removing what was reformatted, we need to calculate new attributes for removal
              opOut.composeAttributes(otherOp.attribs);
            }
            else if(thisOp.isKeep && otherOp.isNotEmpty) {
              // both keeps here, also transform attributes
              opOut.transformAttributes(otherOp.attribs);
            }
          }
          // else, if otherOp is removing, skip thisOp ('-' or '=' at this point)
          thisOp.skip();
          otherOp.skip();
        }
        dLen += opOut.deltaLen;
      });
  
    return new Changeset(newOps, otherCS._newLen, author: _author, newLen: otherCS._newLen + dLen);
  }

  /**
   * Compose this changeset with other changeset, producing cumulative result of both changes.
   */
  Changeset compose(Changeset otherCS) {
    if(_newLen != otherCS._oldLen) {
      throw new Exception('changesets from different document versions are not composable');
    }
  
    sort();
    otherCS.sort();
  
    var newOps = _util.zip(this, otherCS, 
      (OpComponent thisOp, OpComponent otherOp) {
        var noSplit = thisOp.isRemove || otherOp.isInsert;
        // KEEPS can be replaced by REMOVEs
        var hasKeep = thisOp.isKeep || otherOp.isKeep;
        // REMOVEs can affect KEEPs and INSERTs but not other REMOVEs
        var hasRemoveActual = (thisOp.opcode != otherOp.opcode) && (thisOp.isRemove || otherOp.isRemove); 
        // in both cases we can split ops into equal slices
        return (hasKeep || hasRemoveActual) && !noSplit;
      },
      (OpComponent thisOp, OpComponent otherOp, OpComponent opOut) {
        if (thisOp.isRemove || otherOp.isEmpty) {
          // if we've removed something, it cannot be undone by next op
          thisOp.copyTo(opOut);
          thisOp.skip();
        } else if (otherOp.isInsert || thisOp.isEmpty) {
          // if other is inserting something it should be inserted
          otherOp.copyTo(opOut);
          otherOp.skip();
        } else {
          if(otherOp.isRemove) {
            // at this point we're operating on actual chars (KEEP or INSERT) in the target string
            // we don't validate KEEPs since they just add format and not keep final attributes list
            var validRemove = thisOp.isKeep || thisOp.equalsButOpcode(otherOp);
            if(!validRemove) {
              throw new Exception('removed in composition does not match original ${thisOp.charBank} != ${otherOp.charBank}');
            }
  
            // if there was no insert on our side, just keep the other op,
            // overwise we're removing what was inserted and will skip both
            if (thisOp.isKeep) {
              // undo format changes made by thisOp and compose with otherOp
              otherOp.copyTo(opOut)
                .composeAttributes(thisOp.attribs.invert());
            }
          } else if(otherOp.isKeep) {
            // here, thisOp is also KEEP or INSERT, so just copy it over and compose with
            // otherOp
            thisOp.copyTo(opOut)
              .composeAttributes(otherOp.attribs);
          }
  
          thisOp.skip();
          otherOp.skip();
        }
      });
  
    return new Changeset(newOps, _oldLen, author: _author, newLen: otherCS._newLen);
  }
  
  /*
   * Invert current changeset. That is, inverted changeset if applied to the modified document will produce result
   * that is equal to document before the modification: apply(apply(doc, cs), invert(cs)) == doc
   */
  Changeset invert() {
    return new Changeset(super.inverted, _newLen, author: _author, newLen: _oldLen);
  }

  /**
   * Apply changeset to the document, modifying it in-place.
   */
  void applyTo(ADocument doc) {
    var mut = doc.mutate();
    sort();
    forEach((OpComponent op) {
      // if we reuse (don't pack) changeset object, we can end up with
      // empty operations sometimes, do not process them to save time
      if(op.chars > 0) {
        if(op.isInsert) {
          mut.insert(op);
        } else if (op.isRemove) {
          // Since we can have multiline remove ops, remove() can
          // return an array of components instead of single one.
          // But since they all should be mergeable, we can run a quick
          // reduce operation and compare the result
          var removed = mut.remove(op.chars, op.lines)
                          .fold(new OpComponent(), (prev, op) {
                            return prev..append(op);
                          });
    
          if(!removed.equalsButOpcode(op)) {
            throw new Exception('actual does not match removed');
          }
        } else if (op.isKeep) {
          if(op.attribs.isEmpty) {
            mut.skip(op.chars, op.lines);
          } else {
            mut.applyFormat(op);
          }
        }
      }
    });
    mut.finish();
  
    if(_newLen != doc.getLength()) {
      throw new Exception('final document length does not match, expected $_newLen, got ${doc.getLength()}');
    }
  }

  /**
   * Pack changeset into compact format that can be stored or transferred by network. 
   */
  Map pack([List pool]) {
    if(pool == null) {
      pool = [];
    }
    var packed = super.toAString(pool);
    var op = 'X:' + _util.toString36(_oldLen)
      + (packed.dLen >= 0 ? '>' : '<') + _util.toString36(packed.dLen.abs())
      + packed.atts;

    if((_newLen - _oldLen) != packed.dLen) {
      throw new Exception('something wrong with the changeset, internal state broken');
    }
  
    if(packed.text.isNotEmpty) {
      op += r'$' + packed.text;
    }
  
    var cs = { 'op': op, 'p': pool };
    if(this._author != null) {
      cs['u'] = _author;
    }
    return cs;
  }
}