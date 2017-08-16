part of otdartlib.atext_changeset;

class ComponentList extends DirtyList<OpComponent>{
  static final _opsRegex = new RegExp(r'((?:[\*\^][0-9a-z]+)*)(?:\|([0-9a-z]+))?([-+=])([0-9a-z]+)');

  ComponentList();
  
  ComponentList.from(Iterable<OpComponent> other, {bool isDirty: true, bool growable: true}) : super.from(other, growable: growable) {
    _dirty = isDirty;
  }

  /**
   * Unpacks changeset object into components
   */
  factory ComponentList.unpack(AString astr, List pool) {
    return new ComponentList().._unpack(astr, pool);
  }
  
  _unpack(AString astr, List pool) {
    var n = 0;

    var ops = _opsRegex.allMatches(astr.atts).map((m) {
      // for efficiency, since we already have matched and splitted into parts
      // component, we do not have OpComponent.unpack() method, instead
      // build it directly via constructor
      var chars = _util.parseInt36(m[4]);
      var opcode = m[3];
      var lines = m[2] == null ? 0 : _util.parseInt36(m[2]);
      var attribs = new AttributeList.unpack(m[1], pool);
      var charBank;
      if(opcode != OpComponent.KEEP) {
        charBank = astr.text.substring(n, n + chars);
        n += chars;
      } else {
        charBank = '';
      }
 
      return new OpComponent(opcode, chars, lines, attribs, charBank);
    });
    addAll(ops);  // let's assume that single addAll is faster than multiple add()'s
    _dirty = false; // just unpacked, no need to be dirty
  }

  Iterable<OpComponent> get inverted => map((op) => op.invert());

  int get deltaLen => this.fold(0, (prev, next) => prev + next.deltaLen);
  
  /**
   * Reorders components to keep removals before insertions. Makes sense
   * in tie operations to keep result consistent across clients.
   */
  void sort([int compare(OpComponent a, OpComponent b)]) {
    if(!_dirty) {
      return;
    }
    if(compare != null) {
      super.sort(compare);
      return;
    }
  
    var res = <OpComponent>[];
    var inserts = <OpComponent>[];
    var removes = <OpComponent>[];
    var keeps = <OpComponent>[];
  
    var lastOpcode = '';
    forEach((op) {
      if(op.isEmpty) {
        return;
      }

      if(op.isKeep && lastOpcode != OpComponent.KEEP) {
        res..addAll(removes)
          ..addAll(inserts);
        removes.clear();
        inserts.clear();
      } else if(!op.isKeep && lastOpcode == OpComponent.KEEP) {
        res.addAll(keeps);
        keeps.clear();
      }
      
      if(op.isInsert) inserts.add(op);
      else if(op.isKeep) keeps.add(op);
      else if(op.isRemove) removes.add(op);

      lastOpcode = op.opcode;
    });

    clear();
    addAll(res);
    addAll(removes);
    addAll(inserts);
    addAll(keeps);

    _dirty = false;
  }

  /**
   * Packs components list into compact form that can be sent over the wire
   * or stored in the database. Performs smart packing, specifically:
   * - reorders components to keep removals before insertions
   * - merges mergeable components into one
   * - drops final "pure" keeps (that don't do formatting)
   * @param? optCompact - true if we need to omit dLen and pool from result object
   *            (for packing AStrings into document)
   * @returns {Object(a, s, dLen, pool)} to use by Changeset class
   */
  AString toAString([List pool]) {
    pool ??= [];

    StringBuffer resAtts = new StringBuffer();
    StringBuffer resText = new StringBuffer();
    int dLen = 0;
    var last = new OpComponent.empty();
    var inner = new OpComponent.empty();

    push(AString packed) {
      resAtts.write(packed.atts);
      resText.write(packed.text);
      dLen += packed.dLen;
    }

    flush([finalize = false]) {
      if(last.isNotEmpty) {
        if(finalize && last.isSkip) {
          // final skip, drop
        } else {
          push(last.pack(pool));
          last = new OpComponent.empty();
          if(inner.isNotEmpty) {
            push(inner.pack(pool));
            inner = new OpComponent.empty();
          }
        }
      }
    }

    append(OpComponent op) {
      if(last.opcode == op.opcode && last.attribs == op.attribs) {
        if(op.lines > 0) {
          // last and inner are all mergable into multi-line op
          last = last.append(inner).append(op);
          inner = new OpComponent.empty();
        } else if (last.lines == 0) {
          // last and op are both in-line
          last = last.append(op);
        } else {
          inner = inner.append(op);
        }
      } else {
        flush();
        last = op;
      }
    }

    sort();
    forEach(append);
    flush(true);

    return new AString(atts: resAtts.toString(), text: resText.toString(), dLen: dLen, pool: pool);
  }
  
  Map pack([List pool]) => toAString(pool).pack();
}
