part of otdartlib.atext_changeset;

class ADocument extends UnmodifiableListView<Map> implements Clonable {
  final List pool;
  
  ADocument() : this._([]);
  
  ADocument.unpack(Map json) : this._(json['lines'], json['pool']);
  
  factory ADocument.fromText(String text, {String author}) {
    var doc = new ADocument();
    if(text != null && text.isNotEmpty) {
      var builder = Changeset.create(doc, author: author)
                      ..insert(text);
      return builder.finish().applyTo(doc);
    }
    return doc;
  }
  
  ADocument._(List<Map> lines, [List pool]) :
    this.pool = pool ?? [],
    super(lines);
  
  DocumentComposer mutate() => new DocumentComposer(this);

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
    var newPool = [];
    var lines = map((l) => new ComponentList.unpack(new AString.unpack(l), pool)
                                                        .pack(newPool))
                                            .toList(growable: false);

    return new ADocument._(lines, newPool);
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

    return { 'lines': new List.from(doc, growable: false), 'pool': doc.pool };
  }
}