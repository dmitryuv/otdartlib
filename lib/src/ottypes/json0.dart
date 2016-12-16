// This file is a direct port of ShareJS json0 library https://github.com/ottypes/json0
// with slight changes:
// - added 'oin' operator that stands for "object insert if not exists"
// - added check for equality of removed object with what's passed in operator
// - reworked subtypes API

part of otdartlib.ottypes;
/*
 This is the implementation of the JSON OT type.

 Spec is here: https://github.com/josephg/ShareJS/wiki/JSON-Operations

 Note: This is being made obsolete. It will soon be replaced by the JSON2 type.
*/


/**
 * JSON OT Type
 * @type {*}
 */
class OT_json0 extends OTTypeFactory<dynamic, List> with _BootstrapTransform<Map> {
  static final _name = 'json0';
  static final _uri = 'http://sharejs.org/types/JSONv0';

  final Function _deepEq = const DeepCollectionEquality().equals;
//  final Function _deepEq = (a, b) => true;

  @override
  dynamic create([dynamic initial]) {
    if(initial != null && initial is! Map) {
      throw new Exception('Initial data must be a map');
    }

    // Null instead of undefined if you don't pass an argument.
    return initial == null ? null : new Map.from(initial);
  }

  @override
  String get name => _name;

  @override
  String get uri => _uri;
  
 
  Map _invertComponent(Map mc) {
    var c = new _JsonOpComponent(mc);
    var c_ = new _JsonOpComponent({'p': c.path});
  
    // handle subtype ops
    if (c.hasSubtype) {
      c_.subtype = c.subtype;
      c_.subop = new OTTypeFactory.from(c.subtype).invert(c.subop);
    }
  
    if (c.hasOI) c_.od = c.oi;
    if (c.hasOD) c_.oi = c.od;
    if (c.hasLI) c_.ld = c.li;
    if (c.hasLD) c_.li = c.ld;
    if (c.hasNA) c_.na = -c.na;
    if (c.hasOIN) c_.od = c.oin;
  
    if (c.hasLM) {
      c_.lm = c.path.last;
      c_.path = c.path.take(c.path.length - 1).toList()..add(c.lm);
    }
  
    return c_.opc;
  }

  @override
  List invert(List op) => op.reversed.map((o) => _invertComponent(o)).toList();
  
  @override
  checkValidOp(List op) {
    if(!op.every((Map o) => o.containsKey('p') && o['p'] is List)) {
      throw new Exception('Missing path');
    }
  }
 
  _checkList(elem) {
    if(elem is! List) {
      throw new Exception('Referenced element not a list');
    }
  }
  
  _checkObj(elem) {
    if(elem is! Map) {
      throw new Exception("Referenced element not an object (it was ${elem.runtimeType.toString()})");
    }
  }
  
  // TODO: think of more optimal way
  dynamic _cloneObj(dynamic obj) => JSON.decode(JSON.encode(obj));
  
  @override
  dynamic apply(dynamic snapshot, List op) {
    checkValidOp(op);

    op = _cloneObj(op);
    var container = {
      'data': snapshot
    };

    op.forEach((c_) {
      var c = new _JsonOpComponent(c_);

      var key = 'data';
      dynamic elem = container;

      c.path.forEach((p) {
        elem = elem[key];
        key = p;
        if(elem == null) {
          throw new Exception('Path invalid');
        }
      });

      // handle subtype ops
      if (c.hasSubtype) {
        elem[key] = new OTTypeFactory.from(c.subtype).apply(elem[key], c.subop);

      // Number add
      } else if (c.hasNA) {
        if (elem[key] is! num) {
          throw new Exception('Referenced element not a number');
        }

        elem[key] += c.na;
      }

      // List replace
      else if (c.hasLI && c.hasLD) {
        _checkList(elem);
        if(!_deepEq(elem[key], c.ld)) {
          throw new Exception('Removed item does not match remove operation');
        }
        elem[key] = c.li;
      }

      // List insert
      else if (c.hasLI) {
        _checkList(elem);
        (elem as List).insert(key as int, c.li);
      }

      // List delete
      else if (c.hasLD) {
        _checkList(elem);
        if(!_deepEq(elem[key], c.ld)) {
          throw new Exception('Removed item does not match remove operation');
        }
        (elem as List).removeAt(key as int);
      }

      // List move
      else if (c.hasLM) {
        _checkList(elem);
        if (c.lm != key) {
          var list = elem as List;
          // Remove it...
          var e = list.removeAt(key as int);
          // And insert it back.
          list.insert(c.lm, e);
        }
      }

      // Object insert / replace
      else if (c.hasOI) {
        _checkObj(elem);
        
        if(c.hasOD && !_deepEq(elem[key], c.od)) {
          throw new Exception('Removed item does not match remove operation');
        } else if (!c.hasOD && elem.containsKey(key)) {
          throw new Exception('Attempt to reinsert over existing object');
        }
        elem[key] = c.oi;
      }

      // Object delete
      else if (c.hasOD) {
        _checkObj(elem);

        if(!_deepEq(elem[key], c.od)) {
          throw new Exception('Removed item does not match remove operation');
        }
        elem.remove(key);
      }

      // Init value
      else if (c.hasOIN) {
        _checkObj(elem);
        // set value if not exists in the object
        if(!elem.containsKey(key)) {
          elem[key] = c.oin;
        }
      }

      else {
        throw new Exception('invalid / missing instruction in op');
      }
    });

    return container['data'];
  }
  
  // Helper to break an operation up into a bunch of small ops.
  shatter(op) {
    // TODO: do i need it?
    return new List.from(op);
  }
  
  // Helper for incrementally applying an operation to a snapshot. Calls yield
  // after each op component has been applied.
  incrementalApply(snapshot, List op, yieldFn(op, doc)) {
    return op.fold(snapshot, (prev, o) {
        o = [o];
        var res = apply(prev, o);
        yieldFn(o, prev);
        return res;
      });
  }
  
  // Checks if two paths, p1 and p2 match.
  pathMatches(List p1, List p2, [bool ignoreLast = false]) {
    if (p1.length != p2.length)
      return false;
  
    for (var i = 0; i < p1.length; i++) {
      if (p1[i] != p2[i] && (!ignoreLast || i != p1.length - 1))
        return false;
    }
  
    return true;
  }
  
  @override
  append(List dest, Map mc) {
    var c = new _JsonOpComponent(_cloneObj(mc));
  
    if (dest.length == 0) {
      dest.add(c.opc);
      return;
    }
  
    var last = new _JsonOpComponent(dest.last);
  
    if (pathMatches(c.path, last.path)) {
      // handle subtype ops
      if (c.hasSubtype && last.hasSubtype && c.subtype == last.subtype) {
        last.subop = new OTTypeFactory.from(c.subtype).compose(last.subop, c.subop);
      } else if (last.hasNA && c.hasNA) {
        dest[dest.length - 1] = {'p': last.path, 'na': last.na + c.na};
      } else if (last.hasLI && !c.hasLI && c.hasLD && c.ld == last.li) {
        // insert immediately followed by delete becomes a noop.
        // TODO this doesnt make sense because they'll never be equal because we clone C
        if (last.hasLD) {
          // leave the delete part of the replace
          last.opc.remove('li');
        } else {
          dest.removeLast();
        }
      } else if (last.hasOD && !last.hasOI && !last.hasOIN && (c.hasOI || c.hasOIN) && !c.hasOD) {
        last.oi = c.hasOI ? c.oi : c.oin;
      } else if ((last.hasOI || last.hasOIN) && c.hasOD) {
        // The last path component inserted something that the new component deletes (or replaces).
        // Just merge them.
        if (c.hasOI) {
          last.opc.remove('oin'); // just in case we had it, overwrite with object insert
          last.oi = c.oi;
        } else if (last.hasOD) {
          last.opc.remove('oi');
          last.opc.remove('oin');
        } else {
          // An insert directly followed by a delete turns into a no-op and can be removed.
          dest.removeLast();
        }
      } else if ((last.hasOI || last.hasOIN) && c.hasOIN) {
        // last component has optional insert over previous insert - ignore it
      } else if (c.hasLM && c.path.last == c.lm) {
        // don't do anything
      } else {
        dest.add(c.opc);
      }
    } else {  
      dest.add(c.opc);
    }
  }
  
  @override
  List compose(List op1, List op2) {
    checkValidOp(op1);
    checkValidOp(op2);

    var newOp = _cloneObj(op1);
    op2.forEach((op) => append(newOp, op));

    return newOp;
  }
  
  List normalize(op) {
    var newOp = [];
    
    if(op is! List) {
      op = [op];
    }
    
    op.forEach((c) {
      if(!c.containsKey('p')) {
        c['p'] = [];
        append(newOp, c);
      }
    });
      
    return newOp;
  }

  
  // Returns the common length of the paths of ops a and b
  int commonLengthForOps(Map ma, Map mb) {
    var a = new _JsonOpComponent(ma);
    var b = new _JsonOpComponent(mb);
    int alen = a.path.length;
    int blen = b.path.length;
    if (a.hasNA || a.hasSubtype)
      alen++;
  
    if (b.hasNA || b.hasSubtype)
      blen++;
  
    if (alen == 0) return -1;
    if (blen == 0) return null;
  
    alen--;
    blen--;
  
    for (var i = 0; i < alen; i++) {
      var p = a.path[i];
      if (i >= blen || p != b.path[i])
        return null;
    }
  
    return alen;
  }
  
  // Returns true if an op can affect the given path
  canOpAffectPath(Map op, List path) {
    return commonLengthForOps({'p':path}, op) != null;
  }
  
  _pathsEq(int i, _JsonOpComponent op1, _JsonOpComponent op2) => 
      (i < 0) || (i < op1.path.length && i < op2.path.length && op1.path[i] == op2.path[i]);
  
  // transform c so it applies to a document with otherC applied.
  @override
  transformComponent(List dest, Map mc, Map motherC, String type) {
    var c = new _JsonOpComponent(_cloneObj(mc));
    var otherC = new _JsonOpComponent(motherC);
    
    var common = commonLengthForOps(otherC.opc, c.opc);
    var common2 = commonLengthForOps(c.opc, otherC.opc);
    var cplength = c.path.length;
    var otherCplength = otherC.path.length;
  
    if (c.hasNA || c.hasSubtype)
      cplength++;
  
    if (otherC.hasNA || otherC.hasSubtype)
      otherCplength++;
  
    // if c is deleting something, and that thing is changed by otherC, we need to
    // update c to reflect that change for invertibility.
    if (common2 != null && otherCplength > cplength && _pathsEq(common2, c, otherC)) {
      if (c.hasLD) {
        var oc = new _JsonOpComponent(_cloneObj(otherC.opc));
        oc.path = new List.from(oc.path.skip(cplength));
        c.ld = apply(_cloneObj(c.ld), [oc.opc]);
      } else if (c.hasOD) {
        var oc = new _JsonOpComponent(_cloneObj(otherC.opc));
        oc.path = new List.from(oc.path.skip(cplength));
        c.od = apply(_cloneObj(c.od), [oc.opc]);
      }
    }
  
    if (common != null) {
      bool commonOperand = cplength == otherCplength;
  
      // handle subtype ops
      if (otherC.hasSubtype && c.hasSubtype && c.subtype == otherC.subtype) {
        var res = new OTTypeFactory.from(c.subtype).transform(c.subop, otherC.subop, type);

        if (res.length > 0) {
          c.subop = res;
          append(dest, c.opc);
        }

        return dest;
      }
      // transform based on otherC
      else if (otherC.hasNA) {
        // this case is handled below
      } else if (otherC.hasLI && otherC.hasLD) {
        if (_pathsEq(common, otherC, c)) {
          // noop
  
          if (!commonOperand) {
            return dest;
          } else if (c.hasLD) {
            // we're trying to delete the same element, -> noop
            if (c.hasLI && type == 'left') {
              // we're both replacing one element with another. only one can survive
              c.ld = _cloneObj(otherC.li);
            } else {
              return dest;
            }
          }
        }
      } else if (otherC.hasLI) {
        if (c.hasLI && !c.hasLD && commonOperand && _pathsEq(common, c, otherC)) {
          // in li vs. li, left wins.
          if (type == 'right')
            c.path[common]++;
        } else if (otherC.path[common] <= c.path[common]) {
          c.path[common]++;
        }
  
        if (c.hasLM) {
          if (commonOperand) {
            // otherC edits the same list we edit
            if (otherC.path[common] <= c.lm)
              c.lm++;
            // changing c.from is handled above.
          }
        }
      } else if (otherC.hasLD) {
        if (c.hasLM) {
          if (commonOperand) {
            if (_pathsEq(common, otherC, c)) {
              // they deleted the thing we're trying to move
              return dest;
            }
            // otherC edits the same list we edit
            var p = otherC.path[common];
            var from = c.path[common];
            var to = c.lm;
            if (p < to || (p == to && from < to)) {
              c.lm--;
            }
          }
        }
  
        if (otherC.path[common] < c.path[common]) {
          c.path[common]--;
        } else if (_pathsEq(common, otherC, c)) {
          if (otherCplength < cplength) {
            // we're below the deleted element, so -> noop
            return dest;
          } else if (c.hasLD) {
            if (c.hasLI) {
              // we're replacing, they're deleting. we become an insert.
              c.opc.remove('ld');
            } else {
              // we're trying to delete the same element, -> noop
              return dest;
            }
          }
        }
  
      } else if (otherC.hasLM) {
        if (c.hasLM && cplength == otherCplength) {
          // lm vs lm, here we go!
          var from = c.path[common];
          var to = c.lm;
          var otherFrom = otherC.path[common];
          var otherTo = otherC.lm;
          if (otherFrom != otherTo) {
            // if otherFrom == otherTo, we don't need to change our op.
  
            // where did my thing go?
            if (from == otherFrom) {
              // they moved it! tie break.
              if (type == 'left') {
                c.path[common] = otherTo;
                if (from == to) // ugh
                  c.lm = otherTo;
              } else {
                return dest;
              }
            } else {
              // they moved around it
              if (from > otherFrom) c.path[common]--;
              if (from > otherTo) c.path[common]++;
              else if (from == otherTo) {
                if (otherFrom > otherTo) {
                  c.path[common]++;
                  if (from == to) // ugh, again
                    c.lm++;
                }
              }
  
              // step 2: where am i going to put it?
              if (to > otherFrom) {
                c.lm--;
              } else if (to == otherFrom) {
                if (to > from)
                  c.lm--;
              }
              if (to > otherTo) {
                c.lm++;
              } else if (to == otherTo) {
                // if we're both moving in the same direction, tie break
                if ((otherTo > otherFrom && to > from) ||
                    (otherTo < otherFrom && to < from)) {
                  if (type == 'right') c.lm++;
                } else {
                  if (to > from) c.lm++;
                  else if (to == otherFrom) c.lm--;
                }
              }
            }
          }
        } else if (c.hasLI && !c.hasLD && commonOperand) {
          // li
          var from = otherC.path[common];
          var to = otherC.lm;
          var p = c.path[common];
          if (p > from) c.path[common]--;
          if (p > to) c.path[common]++;
        } else {
          // ld, ld+li, si, sd, na, oi, od, oi+od, any li on an element beneath
          // the lm
          //
          // i.e. things care about where their item is after the move.
          var from = otherC.path[common];
          var to = otherC.lm;
          var p = c.path[common];
          if (p == from) {
            c.path[common] = to;
          } else {
            if (p > from) c.path[common]--;
            if (p > to) c.path[common]++;
            else if (p == to && from > to) c.path[common]++;
          }
        }
      }
      else if (otherC.hasOI && otherC.hasOD) {
        if (_pathsEq(common, c, otherC)) {
          if ((c.hasOI || c.hasOIN) && commonOperand) {
            // we inserted where someone else replaced
            if (type == 'right') {
              // left wins
              return dest;
            } else {
              // we win, make our op replace what they inserted
              c.od = otherC.oi;
            }
          } else {
            // -> noop if the other component is deleting the same object (or any parent)
            return dest;
          }
        }
      } else if (otherC.hasOI) {
        if ((c.hasOI || c.hasOIN) && _pathsEq(common, c, otherC)) {
          // left wins if we try to insert at the same place
          if (type == 'left') {
            if (c.hasOI) {
              append(dest, {'p': c.path, 'od': otherC.oi});
            } else {
              // #fix for seed 65606
//              if(c.hasOIN) {
//                append(dest, {'p': c.path, 'oi': c.oin});
//              }
              // #
              return dest;
            }
          } else {
            if(c.hasOIN) {
              // we need to rebuild operation into object insert
              // # remove for fix below
              append(dest, {'p': c.path, 'od': c.oin});
              c.oi = otherC.oi;
              c.opc.remove('oin');
              // # fix for seed 65606
//              append(dest, {'p': c.path, 'oi': otherC.oi});
//              return dest;
              // #
            } else {
              return dest;
            }
          }
        }
      } else if (otherC.hasOD) {
        if (_pathsEq(common, c, otherC)) {
          if (!commonOperand)
            return dest;
          if (c.hasOI) {
            c.opc.remove('od');
          } else {
            return dest;
          }
        }
      } else if (otherC.hasOIN) {
        if ((c.hasOI || c.hasOIN) && _pathsEq(common, c, otherC)) {
          // left wins if we try to insert at the same place
          if (type == 'left') {
            if (c.hasOI) {
              append(dest, {'p': c.path, 'od': otherC.oin});
            } else {
              return dest;
            }
          } else {
            if(c.hasOI || c.hasOIN) {
              return dest;
            }
          }
        }
      }
    }
  
    append(dest, c.opc);
    return dest;
  }
}

class _JsonOpComponent {
  Map opc;

  _JsonOpComponent([Map obj]) {
    opc = obj;
    if(opc == null) {
      opc = {'p': []};
    }
  }
  
  bool get hasNA => opc.containsKey('na');
  bool get hasLI => opc.containsKey('li');
  bool get hasLD => opc.containsKey('ld');
  bool get hasLM => opc.containsKey('lm');
  bool get hasOI => opc.containsKey('oi');
  bool get hasOD => opc.containsKey('od');
  bool get hasOIN => opc.containsKey('oin');
  bool get hasSubtype => opc.containsKey('t');
  bool get hasPath => opc.containsKey('p');
  
  List get path => opc['p'];
       set path(List value) => opc['p'] = value;
  
  num get na => opc['na'];
      set na(num value) => opc['na'] = value;
     
  get li => opc['li'];
  set li(value) => opc['li'] = value;
  
  get ld => opc['ld'];
  set ld(value) => opc['ld'] = value;
  
  get lm => opc['lm'];
  set lm(value) => opc['lm'] = value;

  get oi => opc['oi'];
  set oi(value) => opc['oi'] = value;

  get od => opc['od'];
  set od(value) => opc['od'] = value;

  get oin => opc['oin'];
  set oin(value) => opc['oin'] = value;
  
  get subtype => opc['t'];
  set subtype(value) => opc['t'] = value;
  
  get subop => opc['o'];
  set subop(value) => opc['o'] = value;
}