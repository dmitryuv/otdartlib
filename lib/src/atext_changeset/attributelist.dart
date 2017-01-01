part of otdartlib.atext_changeset;

/*
 * Represents unpacked attributes list. Unlike most of other classes,
 * AttributeList is immutable collection because it gets copied a lot
 * together with OpComponent. 
 */
class AttributeList extends UnmodifiableListView<OpAttribute> {
  static final _attRegex = new RegExp(r'([\*\^])([0-9a-z]+)');
  
  AttributeList() : super(const []);

  /**
   * Create a new attribute list from a list of attributes =], does not create a local copy
   */
  AttributeList.from(List<OpAttribute> list) : super(list);
  
  /**
   * Unpack attribute string in the AttributeList object. Attribute string is a series of opcode and index pairs, where
   * operation tells what we do with attribute (insert *, or remove ^) and index points to the key/value pair in the pool
   */
  factory AttributeList.unpack(String attString, List pool) {
    if(attString == null || attString.isEmpty) {
      return new AttributeList();
    }
   
    var list = _attRegex.allMatches(attString).map((m) {
      var n = _util.parseInt36(m[2]);
      var pair = pool[n];
      return new OpAttribute._internal(m[1], pair[0], pair[1]);
    }).toList(growable: false);

    return new AttributeList.from(list);
  }
  
  /**
   * Create attributes from the map
   */
  factory AttributeList.fromMap({Map format, Map remove}) {
    var len = (format?.length ?? 0) + (remove?.length ?? 0);
    var list = new List<OpAttribute>(len);
    var i = 0;
    remove?.forEach((k, v) => list[i++] = new OpAttribute.remove(k, v));
    format?.forEach((k, v) => list[i++] = new OpAttribute.format(k, v));
    return new AttributeList.from(list);
  }
  
  /**
   * Compares two attribute lists
   *
   * @param {AttributeList} otherAtts
   */
  bool operator== (otherAtts) {
    if(otherAtts is! AttributeList) {
      return false;
    }
    
    if(identical(this, otherAtts)) {
      return true;
    }

    return this.length == otherAtts.length && this.every(otherAtts.contains);
  }

  OpAttribute find(String key) => firstWhere((a) => a.key == key, orElse: () => null);

  bool hasKey(String key) => find(key) != null;

  /**
   * Merge method adds otherAttributes to the current attributes list.
   * If new attribute have the same key and opcode but different value, 
   * it replaces existing attribute.
   */
  AttributeList merge(AttributeList otherAtts) {
    var list = new List<OpAttribute>.from(this);
    // remember original len to not iterate over added ops
    var thisLen = list.length;
    var otherList = otherAtts;

    for(var i = 0; i < otherList.length; i++) {
      var newOp = otherList[i];
      var found = false;
      for(var j = 0; !found && j < thisLen; j++) {
        var op = list[j];
        if(op.opcode == newOp.opcode && op.key == newOp.key && op.value != newOp.value) {
          list[j] = newOp;
          found = true;
        } else if(op.opcode != newOp.opcode && op.key == newOp.key && op.value == newOp.value) {
          throw new Exception('cannot merge mutual ops, use compose or format instead');
        }
      }
      if(!found) {
        list.add(newOp);
      }
    }
    return new AttributeList.from(list);
  }
  
  /**
   * Creates composition of two attribute lists. 
   * isComposition defines if we peform composition, overwise
   * we're applying attributes. The difference is that on composition
   * we allow deletion of non-existing attribute, but on apply we throw error.
   *
   * Composition rules ([att1,op], [att2,op], isComposition) => ([att,op])
   * ([], [bold, *], true/false) => [bold, *]
   * ([], [bold, ^], true) => [bold, ^]
   * ([], [bold, ^], false) => throw
   * ([bold, *], []) => [bold, *]
   * ([bold, ^], []) => [bold, ^]
   * ([bold, *], [bold, *]) => throw
   * ([bold, *], [bold, ^]) => []
   * ([bold, ^], [bold, *]) => []
   */
  AttributeList compose(AttributeList otherAtts, {bool isComposition: false}) {
    // We do not iterate over added members, assuming incoming attribute list
    // is valid. Anyway result will be fully validated in pack()
    var list = new List<OpAttribute>.from(this);
    var thisLen = list.length;
    for(var i = 0; i < otherAtts.length; i++) {
      var otherOp = otherAtts[i];
      var found = false;

      for(var j = 0; !found && j < thisLen; j++) {
        var thisOp = list[j];
        if(thisOp == otherOp) {
          throw new Exception('trying to compose identical OpAttributes: ${otherOp.key}');
        }

        if(thisOp.opcode != otherOp.opcode && thisOp.key == otherOp.key && thisOp.value == otherOp.value) {
          // remove opposite operation
          list.removeAt(j);
          thisLen--;
          found = true;
        }
      }
      if(!found) {
        if(!isComposition && otherOp.isRemove) {
          throw new Exception('trying to remove non-existing attribute: ${otherOp.opcode}${otherOp.key} from ${list.fold('', (p, n) => p + n.opcode + n.key)}');
        }
        list.add(otherOp);
      }
    }
    return new AttributeList.from(list);
  }
  
  /**
   * Transform these attributes as if they were applied after otherAtt.
   * In other words, merges two sets of attributes. If we have
   * same keys applied, then take lexically-earlier value and remove
   * other one.
   * Unlike Compose() function, were we mostly insterested in summing up
   * attributes, in Transform() we must respect user's intention for
   * formatting. For ex. if user A sets attrib to (img,1) and user B sets
   * attrib to (img,2), we must remove old attrib in one case and ignore
   * set in another.
   * Some rules:
   * ([(img,1), *], [(img,2), *]) => ([(img,2), ^], [(img,1),*]) (1<2)
   * ([(img,1), ^], [(img,2), *]) => throws
   */
  AttributeList transform(AttributeList otherAtts) {
    var res = <OpAttribute>[];
    for(var i = 0; i < length; i++) {
      var thisOp = this[i];
      var skip = false;
      for(var j = 0; !skip && j < otherAtts.length; j++) {
        var otherOp = otherAtts[j];

        if(thisOp == otherOp) {
          // someone already applied this operation, skip it
          skip = true;
        } else if(thisOp.key == otherOp.key && thisOp.opcode == otherOp.opcode && thisOp.isFormat) {
          // we have format operation for the same attribute key but different value
          if(thisOp.value.compareTo(otherOp.value) < 0) {
            // we need to keep out value, for this, remove other one
            res..add(new OpAttribute.remove(otherOp.key, otherOp.value))
               ..add(thisOp);
          }
          skip = true;
        } else if((thisOp.key == otherOp.key && thisOp.value == otherOp.value && thisOp.opcode != otherOp.opcode)
                  || (thisOp.key == otherOp.key && thisOp.value != otherOp.value && thisOp.isRemove)) {
          // some sanity checks:
          // 1) can't do opposite operation on N
          // 2) can't remove key with different value
          throw new Exception('invalid operation for transform');
        }
      }
      if(!skip) {
        res.add(thisOp);
      }
    }
    return new AttributeList.from(res);
  }
  
  /**
   * Apply format to attributes. The result will be an attribute operation
   * that can be applied to original attributes to perform desired formatting:
   * - formatting can be applied only on attrib strings and not attrib operations (only insertions '*')
   * - insertions over the same key+value pairs will be dropped
   * - insertions over the same keys will create replacement
   * - removals of non-existing Ns will be dropped
   */
  AttributeList format(AttributeList formatAtts) {
    var res = <OpAttribute>[];
    for(var i = 0; i < formatAtts.length; i++) {
      var formatOp = formatAtts[i];
      var skip = false;
      for(var j = 0; !skip && j < length; j++) {
        var thisOp = this[j];

        if(formatOp.key == thisOp.key && formatOp.value == thisOp.value) {
          // for key & value match, keep removals and ignore insertions
          if(formatOp.isRemove) {
            res.add(formatOp);
          }
          skip = true;
        } else if(formatOp.key == thisOp.key && formatOp.value != thisOp.value && formatOp.isFormat) {
          // have same insert operation on the same key but different values
          // need to remove old value and only then push new one
          res..add(new OpAttribute.remove(thisOp.key, thisOp.value))
             ..add(formatOp);
          skip = true;
        }
      }
      if(!skip && formatOp.isFormat) {
        // drop removals of non-existing key+value pair and keep only formats
        res.add(formatOp);
      }
    }
    return new AttributeList.from(res);
  }
  
  /**
   * Inverts all attribute operations. Converts attribute insertion '*' to attribute deletion '^' and vice versa
   *
   * @param {AttributeList} exceptAtts - do not touch some attributes. TODO: not used anymore?
   * @returns {AttributeList} newly created AttributeList with inverted result
   */
  AttributeList invert([AttributeList exceptAtts]) {
    var res = map((a) {
      if(exceptAtts?.contains(a) ?? false) {
        return a;
      } else {
        return a.invert();
      }
    });

    return new AttributeList.from(res.toList(growable: false));
  }

  /**
   * Packs attributes into new or existing pool
   */
  String pack([List optPool]) {
    var pool = optPool ?? [];
    var nMap = {};
    var kMap = {};

    var s = new StringBuffer();
    new List<OpAttribute>.from(this, growable: false)
      ..sort((a, b) => a.opcode == b.opcode ? a.key.compareTo(b.key) : b.opcode.compareTo(a.opcode))
      ..map((op) => new _Pair(op, _addToPool(pool, op)))
      .forEach((item) {
        // just in case, run a simple sanity check to make sure
        // we don't have same attrib number twice
        if(nMap.containsKey(item.n)){
          throw new Exception('multiple operations on the same attrib key: ${item.op.key}');
        }
        nMap[item.n] = true;
  
        // another sanity check to make sure we don't have 2 authors
        // or 2 images with different values
        int cnt = kMap[item.op.key] ?? 0;
        
        cnt = kMap[item.op.key] = cnt + (item.op.isFormat ? 1 : -1);
        if(cnt < -1 || cnt > 1) {
          throw new Exception('multiple insertions or deletions of attribute with key: ${item.op.key}');
        }
  
        s..write(item.op.opcode)
         ..write(_util.toString36(item.n));
      });
    return s.toString();
  }
  
  static int _addToPool(List pool, op) {
    for(var i = 0, l = pool.length; i < l; i++) {
      var pair = pool[i];
      if(pair[0] == op.key && pair[1] == op.value) {
        return i;
      }
    }
    pool.add([op.key, op.value]);
    return pool.length - 1;
  }
}



class _Pair {
  OpAttribute op;
  int n;
  
  _Pair(this.op, this.n);
}
