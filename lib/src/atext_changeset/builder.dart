part of otdartlib.atext_changeset;


/**
 * Creates a Changeset builder for the document.
 * @param {AttributedDocument} doc
 * @param? {String} optAuthor - optional author of all changes
 */
class Builder {
  ADocument _doc;
  int _len;
  String _author;
  DocumentComposer _mut;
  ComponentList _ops = new ComponentList();
  AttributeList _authorAtts;

  Builder(this._doc, {String author}) {
    this._author = author;
    _mut = _doc.mutate();
    _len = _doc.getLength();

    if(author != null) {
      _authorAtts = new AttributeList.fromMap(format: {Changeset.AUTHOR_ATTRIB: _author});
    } else {
      _authorAtts = new AttributeList();
    }
  }

  void keep(int chars, int lines) {
    var op = new OpComponent.keep(chars, lines);
    _ops.add(op);
    // mutator does the check that N and L match actual skipped chars
    _mut.apply(op);
  }

  void format(int chars, int lines, AttributeList attribs) => _format(chars, lines, attribs);

  void removeAllFormat(int chars, int lines) => _format(chars, lines, new AttributeList(), true);
  
  void _format(int chars, int lines, AttributeList attribs, [bool removeAll = false]) {
    // someone could send us author by mistake, we strictly prohibit that and replace with our author
    attribs = attribs.merge(_authorAtts);

    _mut.takeChars(chars, lines).forEach((c) {
      c = new OpComponent.format(c.chars, c.lines, c.attribs);
      if(removeAll) {
        c = c.invertAttributes()
              .composeAttributes(attribs);
      } else {
        c = c.formatAttributes(attribs);
      }
      _ops.add(c);
    });
  }
  
  void insert(String text, [AttributeList attribs]) {
    attribs = attribs?.merge(_authorAtts) ?? _authorAtts;

    var lastNewline = text.lastIndexOf('\n');
    if(lastNewline < 0) {
      // single line text
      _ops.add(new OpComponent.insert(text.length, 0, attribs, text));
    } else {
      var l = lastNewline + 1;
      // multiline text, insert everything before last newline as multiline op
      _ops.add(new OpComponent.insert(l, '\n'.allMatches(text).length, attribs, text.substring(0, l)));
      if(l < text.length) {
        // insert remainder as single-line op
        _ops.add(new OpComponent.insert(text.length - l, 0, attribs, text.substring(l)));
      }
    }
  }
  
  void remove(int chars, int lines) => _ops.addAll(_mut.takeChars(chars, lines).inverted);

  Changeset finish() => new Changeset(_ops, _len, author: _author);
}