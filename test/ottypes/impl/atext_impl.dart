part of otdartlib.test.ottypes;

class FuzzerATextImpl extends FuzzerImpl<ADocument> {
  String randomAuthor() {
    // increase chance of submitting a change on behalf of the same author
    var a = ['1','2','1','3','2','4','3','5','4'];
    return a[randomInt(a.length)];
  }
  
  AttributeList randomFormat([allowRemove = false]) {
    // return new AttributeList();
    if(randomInt(10) > 7) {
      return new AttributeList();
    } else {
      if(allowRemove && randomInt(10) > 8) {
        return null;
      } else {
        var f = [['bold', 'true'], ['italic', 'true'], ['list', '1'], ['list', '2'], ['underline', 'true'], ['foo', 'bar']];
        var x = f[randomInt(f.length)];
        if(randomInt(allowRemove ? 2 : 1) == 0) {
          return new AttributeList.fromMap(format: {x[0]: x[1]});
        } else {
          return new AttributeList.fromMap(remove: {x[0]: x[1]});
        }
      }
    }
  }
  
  @override
  List generateRandomOp(ADocument doc) {
    var len = doc.getLength();
    var pos = 0;
    var author = randomAuthor();
    var authorAtt = new AttributeList.fromMap(format: {'author': author});
    var cs = Changeset.create(doc, author: author);
    // since I don't have peek() function, i'll need another copy to iterate over by taking parts
    var iter = doc.mutate();
    var mut = doc.mutate();
  
    ComponentList randomTextRange() {
      var n = randomInt(len - pos + 1);
      return iter.takeChars(n);

    }
  
    keep() {
      randomTextRange().forEach((op) { 
        cs.keep(op.chars, op.lines);
        mut.apply(new OpComponent.keep(op.chars, op.lines));
        pos += op.chars;
      });
    };
  
    format() {
      var fmt = randomFormat();
      randomTextRange().forEach((OpComponent op) {
        var targetAtts;
        if(fmt == null) {
          cs.removeAllFormat(op.chars, op.lines);
          targetAtts = op.attribs.invert().compose(authorAtt, isComposition: true);
        } else {
          cs.format(op.chars, op.lines, fmt);
          targetAtts = op.attribs.format(fmt.merge(authorAtt));
        }
        mut.apply(new OpComponent.format(op.chars, op.lines, targetAtts));
        pos += op.chars;
      });
    }
  
    insert() {
      var w = randomWord();
      var newLine = 0;
      var fmt = randomFormat();
      if(randomInt(10) > 6) {
        w += '\n';
        newLine = 1;
      }
      cs.insert(w, fmt);
  
      var cmp = new OpComponent(OpComponent.INSERT, w.length, newLine, fmt.merge(authorAtt), w);
      mut.apply(cmp);
      len += w.length;
      pos += w.length;
    }
  
    remove() {
      randomTextRange().forEach((op) {
        cs.remove(op.chars, op.lines);
        // remove by taking
        mut.takeChars(op.chars, op.lines);
        len -= op.chars;
      });
    }
  
    if(len == 0) {
      insert();
    }
  
    var operations = 5;
    while((len - pos) > 0 && operations > 0) {
      // if document is long, bias it towards deletion
      var chance = (len > 300) ? 5 : 4;
      switch(randomInt(chance)) {
        case 0: 
          keep();
          break;
        case 1:
          insert();
          break;
        case 2:
          format();
          break;
        case 3:
        case 4:
          remove();
          break;
      }
      operations--;
    }

    return [cs.finish(), mut.finish()];
  }
  
  ADocument generateRandomDoc() => new ADocument.fromText(randomWord());
  
  // used in randomizer to compare snapshots
  // cleanup them before comparing
  @override
  Map serialize(ADocument doc) {
    return doc.pack(true);
  }
  
  @override
  dynamic clone(obj) {
    if(obj is Clonable) {
      return obj.clone(); 
    } else {
      return JSON.decode(JSON.encode(obj));
    }
  }
}