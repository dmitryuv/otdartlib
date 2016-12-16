// This file is a direct port of ShareJS json0 library https://github.com/ottypes/json0
part of otdartlib.ottypes;

// DEPRECATED!
//
// This type works, but is not exported, and will be removed in a future version of this library.


// A simple text implementation
//
// Operations are lists of components.
// Each component either inserts or deletes at a specified position in the document.
//
// Components are either:
//  {i:'str', p:100}: Insert 'str' at position 100 in the document
//  {d:'str', p:100}: Delete 'str' at position 100 in the document
//
// Components in an operation are executed sequentially, so the position of components
// assumes previous components have already executed.
//
// Eg: This op:
//   [{i:'abc', p:0}]
// is equivalent to this op:
//   [{i:'a', p:0}, {i:'b', p:1}, {i:'c', p:2}]

// NOTE: The global scope here is shared with other sharejs files when built with closure.
// Be careful what ends up in your namespace.

class OT_text0 extends OTTypeFactory<String, List> with _BootstrapTransform<Map> {
  static final _name = 'text0';
  static final _uri = 'http://sharejs.org/types/textv0';
  
  @override
  create([String initial]) {
    if(initial != null && initial is! String) {
      throw new Exception('Initial data must be a string');
    } else if (initial == null) {
      initial = '';
    }
    return initial;
  }
  
  @override
  String get name => _name;

  @override
  String get uri => _uri;


  /** Insert s2 into s1 at pos. */
  String _strInject(String s1, int pos, String s2) => s1.substring(0, pos) + s2 + s1.substring(pos);

  /** Check that an operation component is valid. Throws if its invalid. */
  _checkValidComponent(Map c) {
    if (c['p'] is! num) {
      throw new Exception('component missing position field');
    }
    
    if ((c.containsKey('i') && c['i'] is! String) || (c.containsKey('d') && c['d'] is! String)) {
      throw new Exception('component needs an i or d field');
    }
    
    if (c['p'] < 0) {
      throw new Exception('position cannot be negative');
    }
  }

  /** Check that an operation is valid */
  @override
  checkValidOp(List op) {
    op.forEach(_checkValidComponent); 
  }

  /** Apply op to snapshot */
  @override
  String apply(String snapshot, List op) {
    checkValidOp(op);
    op.forEach((c) {
      c = new _TextOpComponent(c);
      if(c.hasInsert) {
        snapshot = _strInject(snapshot, c.pos, c.insert);
      } else {
        var deleted = snapshot.substring(c.pos, c.pos + c.delete.length);
        if (c.delete != deleted) {
          throw new Exception("Delete component ${c.delete} does not match deleted text $deleted");
        }
        
        snapshot = snapshot.substring(0, c.pos) + snapshot.substring(c.pos + c.delete.length);
      }
    });
    return snapshot;
  }

  /**
   * Append a component to the end of newOp. Exported for use by the random op
   * generator and the JSON0 type.
   */
  @override
  append(List newOp, Map mc) {
    var c = new _TextOpComponent(mc);
    if ((c.hasInsert && c.insert.isEmpty) || (c.hasDelete && c.delete.isEmpty)) 
      return;
  
    if (newOp.isEmpty) {
      newOp.add(c.opc);
    } else {
      var last = new _TextOpComponent(newOp.last);

      if (last.hasInsert && c.hasInsert && last.pos <= c.pos && c.pos <= last.pos + last.insert.length) {
        // Compose the insert into the previous insert
        newOp[newOp.length - 1] = {'i':_strInject(last.insert, c.pos - last.pos, c.insert), 'p':last.pos};
      } else if (last.hasDelete && c.hasDelete && c.pos <= last.pos && last.pos <= c.pos + c.delete.length) {
        // Compose the deletes together
        newOp[newOp.length - 1] = {'d':_strInject(c.delete, last.pos - c.pos, last.delete), 'p':c.pos};
      } else {
        newOp.add(c.opc);
      }
    }
  }
  
  /** Compose op1 and op2 together */
  @override
  List compose(List op1, List op2) {
    checkValidOp(op1);
    checkValidOp(op2);
    var newOp = new List.from(op1);
    
    op2.forEach((op) => append(newOp, op));

    return newOp;
  }

  /** Clean up an op */
  List normalize(op) {
    var newOp = [];
    
    // Normalize should allow ops which are a single (unwrapped) component:
    // {i:'asdf', p:23}
    if(op is! List) {
      op = [op];
    }
    
    op.forEach((c) {
      if(!c.containsKey('p')) {
        c['p'] = 0;
      }
      append(newOp, c);
    });
    
    return newOp;
  }

  // This helper method transforms a position by an op component.
  //
  // If c is an insert, insertAfter specifies whether the transform
  // is pushed after the insert (true) or before it (false).
  //
  // insertAfter is optional for deletes.
  int transformPosition(int pos, Map mc, [bool insertAfter = false]) {
    var c = new _TextOpComponent(mc);
    // This will get collapsed into a giant ternary by uglify.
    if (c.hasInsert) {
      if (c.pos < pos || (c.pos == pos && insertAfter)) {
        return pos + c.insert.length;
      } else {
        return pos;
      }
    } else {
      // I think this could also be written as: Math.min(c.p, Math.min(c.p -
      // otherC.p, otherC.d.length)) but I think its harder to read that way, and
      // it compiles using ternary operators anyway so its no slower written like
      // this.
      if (pos <= c.pos) {
        return pos;
      } else if (pos <= c.pos + c.delete.length) {
        return c.pos;
      } else {
        return pos - c.delete.length;
      }
    } 
  }

  // Helper method to transform a cursor position as a result of an op.
  //
  // Like transformPosition above, if c is an insert, insertAfter specifies
  // whether the cursor position is pushed after an insert (true) or before it
  // (false).
  int transformCursor(int position, List op, [String side = 'left']) {
    var insertAfter = side == 'right';
    return op.fold(position, (prev, c) => transformPosition(prev, c, insertAfter));
  }

  // Transform an op component by another op component. Asymmetric.
  // The result will be appended to destination.
  //
  // exported for use in JSON type
  @override
  transformComponent(List dest, Map mc, Map motherC, String side) {    
    _checkValidComponent(mc);
    _checkValidComponent(motherC);
    
    var c = new _TextOpComponent(mc);
    var otherC = new _TextOpComponent(motherC);

    if (c.hasInsert) {
      // Insert.
      append(dest, {'i':c.insert, 'p':transformPosition(c.pos, otherC.opc, side == 'right')});
    } else {
      // Delete
      if (otherC.hasInsert) {
        // Delete vs insert
        var s = c.delete;
        if (c.pos < otherC.pos) {
          append(dest, {'d':s.substring(0, (otherC.pos - c.pos).clamp(0, s.length)), 'p':c.pos});
          s = s.substring((otherC.pos - c.pos).clamp(0, s.length));
        }
        if (s.isNotEmpty) {
          append(dest, {'d': s, 'p': c.pos + otherC.insert.length});
        }
     } else {
        // Delete vs delete
        if (c.pos >= otherC.pos + otherC.delete.length) {
          append(dest, {'d': c.delete, 'p': c.pos - otherC.delete.length});
        } else if (c.pos + c.delete.length <= otherC.pos) {
          append(dest, c.opc);
        } else {
          // They overlap somewhere.
          var newC = new _TextOpComponent({'d': '', 'p': c.pos});
     
          if (c.pos < otherC.pos) {
            newC.delete = c.delete.substring(0, otherC.pos - c.pos);
          }
     
          if (c.pos + c.delete.length > otherC.pos + otherC.delete.length) {
            newC.delete += c.delete.substring(otherC.pos + otherC.delete.length - c.pos);
          }
     
          // This is entirely optional - I'm just checking the deleted text in
          // the two ops matches
          var intersectStart = max(c.pos, otherC.pos);
          var intersectEnd = min(c.pos + c.delete.length, otherC.pos + otherC.delete.length);
          var cIntersect = c.delete.substring(intersectStart - c.pos, intersectEnd - c.pos);
          var otherIntersect = otherC.delete.substring(intersectStart - otherC.pos, intersectEnd - otherC.pos);
          if (cIntersect != otherIntersect) {
            throw new Exception('Delete ops delete different text in the same region of the document');
          }
     
          if (newC.delete.isNotEmpty) {
            newC.pos = transformPosition(newC.pos, otherC.opc);
            append(dest, newC.opc);
          }
        }
      }
    }
    
    return dest;
  }

  Map _invertComponent(Map c) {
    return c.containsKey('i') ? {'d':c['i'], 'p':c['p']} : {'i':c['d'], 'p':c['p']};
  }

  // No need to use append for invert, because the components won't be able to
  // cancel one another.
  @override
  List invert(List op) => op.reversed.map((o) => _invertComponent(o)).toList();
}

class _TextOpComponent {
  Map opc;

  _TextOpComponent(Map obj) : opc = obj;
  
  bool get hasInsert => opc.containsKey('i');
  bool get hasDelete => opc.containsKey('d');

  int get pos => opc['p'];
      set pos(int value) => opc['p'] = value;
  
  String get insert => opc['i'];
         set insert(String value) => opc['i'] = value;
  String get delete => opc['d'];
         set delete(String value) => opc['d'] = value;
}