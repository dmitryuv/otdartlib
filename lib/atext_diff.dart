library otdartlib.atext_diff;

import 'package:otdartlib/atext_changeset.dart';
import 'dart:convert';

class ADocumentDiff {
  ADocument _doc;
  List<Changeset> _changes;
  int _docChars;

  ADocumentDiff(this._doc, this._changes) {
    _docChars = _doc.getLength();
  }

  ADocument _removeAuthorship(ADocument doc) {
    var ops = doc.mutate().takeChars(_docChars).map((opc) {
      var author = _getAuthor(opc);
      if(author != null) {
        var removeAtt = new AttributeList.fromMap(remove: {'author': author.value});
        return new OpComponent.format(opc.chars, opc.lines, opc.attribs.format(removeAtt));
      } else {
        return new OpComponent.keep(opc.chars, opc.lines);
      }
    });
    var res = new Changeset(ops, _docChars).applyTo(doc);
//    print('doc: $res\npool: ${res.pool}');
    return res;
  }

  OpAttribute _getAuthor(OpComponent op) => op.attribs.find('author');

  ADocument createDiff() {
    // TODO: remap changes to inject change author into removal ops

    var composed = _changes.reduce((prev, next) => prev.compose(next));
    Changeset diffCs = new Changeset(composed.map((op) {
      var opAuthor = _getAuthor(op);
      if(opAuthor == null) {
        return op;
      }

      if(op.isInsert) {
        var attrib = op.lines > 0 ? 'new-line-by' : 'new-addition';
        return op.formatAttributes(new AttributeList.fromMap(format: {attrib: opAuthor.value}));
      } else if(op.isRemove) {
        return new OpComponent.format(op.chars, op.lines, op.attribs.format(new AttributeList.fromMap(format: {'removed-by': 'unknown'})));
      }
    }), _docChars);

    return diffCs.applyTo(_removeAuthorship(_doc));
  }


}



clone(obj) {
  return JSON.decode(JSON.encode(obj));
}

void main() {
  var sampleLines = [{'a': '*0+5', 's': 'Hello'}];
  var samplePool = [['author', 'x'], ['author','y']];

  getDoc([lines]) {
    return new ADocument.unpack(clone({ 'lines': lines ?? sampleLines, 'pool': samplePool}));
  }

  List<Changeset> getChanges(List<String> changes) {
    return changes.map((String s) {
      return new Changeset.unpack({'op': 'X:' + s, 'p': samplePool});
    }).toList();
  }

  var edits = [ '5>1=5*1+1\$ ', '6<1=4*0-1\$o',
                '5>1=5*1+1\$w', '6<1=3*0-1\$l',
                '5>1=5*1+1\$o', '6<1=2*0-1\$l',
                '5>1=5*1+1\$r', '6<1=1*0-1\$e',
                '5>1=5*1+1\$l', '6<1*0-1\$H',
                '5>1=5*1+1\$d'];

  var diff = new ADocumentDiff(getDoc(), getChanges(edits));
  var res = diff.createDiff().compact();
  print('doc: $res\npool: ${res.pool}');
}