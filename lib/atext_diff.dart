library otdartlib.atext_diff;

import 'package:otdartlib/atext_changeset.dart';
import 'dart:convert';

typedef List<OpAttribute> DiffCustomMapper(String changesetAuthor, OpComponent op);

class ADocumentDiff {
  static const String REMOVED_BY = 'removed-by';
  static const String ADDED_BY = 'added-by';
  static const String MODIFIED_BY = 'modified-by';
  static const String NEWLINE_BY = 'newline-by';
  static const String META_AUTHOR = 'meta_author';

  ADocument _doc;
  List<Changeset> _changes;
  DiffCustomMapper _customMapper;

  ADocumentDiff(this._doc, this._changes, {DiffCustomMapper customMapper})
    : _customMapper = customMapper;

  static ADocument _removeAuthorship(ADocument doc) {
    var docLength = doc.getLength();
    var ops = doc.mutate().takeChars(docLength).map((opc) {
      var author = opc.attribs.find(Changeset.AUTHOR_ATTRIB);
      if(author != null) {
        var removeAtt = new AttributeList.fromMap(remove: {Changeset.AUTHOR_ATTRIB: author.value});
        return new OpComponent.format(opc.chars, opc.lines, opc.attribs.format(removeAtt));
      } else {
        return new OpComponent.keep(opc.chars, opc.lines);
      }
    });
    return new Changeset(ops, docLength).applyTo(doc);
  }

  static Changeset _remapChangeset(Changeset cs, OpComponent mapFn(OpComponent op)) {
    return new Changeset(cs.map(mapFn), cs.oldLength, author: cs.author);
  }

  Iterable<Changeset> _injectMeta(Iterable<Changeset> list) {
    return list.map((cs) =>
      _remapChangeset(cs, (op) {
        var meta = _customMapper == null ? <OpAttribute>[] : _customMapper(cs.author, op);
        if(!op.isSkip) {
          meta.add(new OpAttribute.format(META_AUTHOR, cs.author));
        }
        return new OpComponent(op.opcode, op.chars, op.lines, new _MetaAttributeList(op.attribs, meta), op.charBank);
      }));
  }

  static OpComponent _createDiffAttributes(OpComponent op) {
    var meta = op.attribs is _MetaAttributeList
      ? (op.attribs as _MetaAttributeList).meta.toList()
      : <OpAttribute>[];

    var metaAuthor = meta.firstWhere((a) => a.key == META_AUTHOR, orElse: () => null);

    if(metaAuthor != null) {
      // cleanup meta author from the list
      meta.removeWhere((a) => a.key == META_AUTHOR);

      if (op.isRemove) {
        meta.add(new OpAttribute.format(REMOVED_BY, metaAuthor.value));
      } else if (op.isInsert) {
        meta.add(new OpAttribute.format(op.lines > 0 ? NEWLINE_BY : ADDED_BY, metaAuthor.value));
      } else if (op.isFormat) {
        meta.add(new OpAttribute.format(MODIFIED_BY, metaAuthor.value));
      }
    }


    if(op.isRemove) {
      // if it's removal, we KEEP original text and only add META
      op = new OpComponent.format(op.chars, op.lines, new AttributeList.from(meta));
    } else {
      // combine attributes with META and remove all references to AUTHOR attribute since we don't need it
      var newAtts = new List<OpAttribute>.from(op.attribs)
        ..addAll(meta)
        ..removeWhere((a) => a.key == Changeset.AUTHOR_ATTRIB);

      op = new OpComponent(op.opcode, op.chars, op.lines, new AttributeList.from(newAtts), op.charBank);
    }

    return op;
  }

  ADocument createDiff() {
    var diffCs = _injectMeta(_changes)
      .reduce((prev, next) => prev.compose(next));

    diffCs = _remapChangeset(diffCs, _createDiffAttributes);

    return diffCs.applyTo(_removeAuthorship(_doc));
  }

}

class _MetaAttributeList extends AttributeList {
  AttributeList _meta;

  _MetaAttributeList(List<OpAttribute> list, [List<OpAttribute> meta]) : super.from(list) {
    _meta = new AttributeList.from(meta ?? []);
  }

  AttributeList get meta => _meta;

  @override
  AttributeList compose(AttributeList otherAtts, {bool isComposition: false}) {
    var otherMeta = (otherAtts is _MetaAttributeList) ? otherAtts.meta : new AttributeList();

    return new _MetaAttributeList(super.compose(otherAtts, isComposition: isComposition), _meta.merge(otherMeta));
  }

  @override
  String toString() {
    return '${super.toString()}##${_meta.toString()}';
  }
}


/********* TEST AREA *********/
/********* TEST AREA *********/
/********* TEST AREA *********/

clone(obj) {
  return JSON.decode(JSON.encode(obj));
}

runTest(List<String> edits, [DiffCustomMapper mapper]) {
  var sampleLines = [{'a': '*0+5', 's': 'Hello'}];
  var samplePool = [['author', 'x'], ['author','y'], ['table','true'], ['0:0', 'x'], ['1:0', 'y']];

  getDoc([lines]) {
    return new ADocument.unpack(clone({ 'lines': lines ?? sampleLines, 'pool': samplePool}));
  }

  List<Changeset> getChanges(List<String> changes) {
    return changes.map((String s) {
      var author = s.contains('\*0') ? 'X' : (s.contains('\*1') ? 'Y' : null);
      return new Changeset.unpack({'op': 'X:' + s, 'p': samplePool, 'u': author });
    }).toList();
  }

  var diff = new ADocumentDiff(getDoc(), getChanges(edits), customMapper: mapper);
  var res = diff.createDiff().compact();
  print('doc: $res\npool: ${res.pool}');
}


void main() {
  var edits = [ '5>1=5*1+1\$ ', '6<1=4*0-1\$o',
                '5>1=5*1+1\$w', '6<1=3*0-1\$l',
                '5>1=5*1+1\$o', '6<1=2*0-1\$l',
                '5>1=5*1+1\$r', '6<1=1*0-1\$e',
                '5>1=5*1+1\$l', '6<1*0-1\$H',
                '5>1=5*1+1\$d'];

//  runTest(edits);

  edits = [ '5>1=5*0+1\$ ', '6>1=6*0+1\$w', '7>1=7*0+1\$o', '8>1=8*0+1\$r',
            '9<1=8*0-1\$r', '8<1=7*0-1\$o', '7<1=6*0-1\$w',
            '6>1=6*1+1\$t', '7>1=7*1+1\$h', '8>1=8*1+1\$e', '9>1=9*1+1\$r', 'a>1=a*1+1\$e'
          ];

//  runTest(edits);

//  edits = [ '5>1=4*0*2+1\$|', '6>0=4^0*1*3=1', '6>0=4^1*0*4=1', '6>1=4*0*2*3*4-1*1+2\$|xy' ];
  edits = [ '5>1*0+1\$X', '6>0=4^0*1*3=1', '6>0=4^1*0*4=1', '6>1=4*0*2*3*4-1*1+2\$lxy' ];

  runTest(edits, (author, op) {
    var atts = op.attribs.where((a) => a.key.contains(':'))
      .map((a) => new OpAttribute.format('${a.key}_${ADocumentDiff.MODIFIED_BY}', author))
      .toList();
    return atts;
  });
}
