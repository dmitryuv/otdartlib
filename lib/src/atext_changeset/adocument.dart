part of otdartlib.atext_changeset;

class ADocument extends DelegatingList<Map> implements Clonable {
  final List pool;
  
  ADocument() : this._([]);
  
  ADocument.unpack(Map json) : this._(json['lines'], json['pool']);
  
  factory ADocument.fromText(String text, {String author}) {
    var doc = new ADocument();
    if(text != null && text.isNotEmpty) {
      Changeset.create(doc, author: author)
        ..insert(text)
        ..finish()
        .applyTo(doc);
    }
    return doc;
  }
  
  ADocument._(List lines, [List pool]) : 
    super(lines), 
    this.pool = pool == null ? [] : pool;
  
  ALinesMutator mutate() => new ALinesMutator(this, pool);

  int getLength() => fold(0, (prev, line) => prev + AString.packedLength(line));

  /**
   * Creates a full copy of the document.
   */
  @override
  ADocument clone() {
    var copy = JSON.decode(JSON.encode(this.pack()));
    return new ADocument.unpack(copy);
  }

  /*
   * Performs pool compact procedure when we repack all lines into
   * new empty pool purging unused attributes
   *
   * @returns {ADocument} - new compacted document object
   */
  ADocument compact() {
    var doc = new ADocument();
    
    doc.addAll(map((l) => 
        new ComponentList.unpack(new AString.unpack(l), pool).pack(doc.pool)));

    return doc;
  }

/*
 * Pack the document into format that can be stored or transferred by network.
 *
 * @returns {Object}
 */
  Map pack([bool compactPool = false]) {
    var doc = this;
    if(compactPool) {
      doc = doc.compact();
    }

    var lines = new List.from(doc);    
    var pool = lines.isEmpty ? [] : new List.from(doc.pool);
    
    return { 'lines': lines, 'pool': pool };
  }
}