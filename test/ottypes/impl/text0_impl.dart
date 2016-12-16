part of otdartlib.test.ottypes;

class FuzzerText0Impl extends FuzzerImpl<String> {
  var _text0 = new OT_text0();
  
  @override
  List generateRandomOp(String docStr) {
    var pct = 0.9;

    var op = [];

    while(randomReal() < pct) {
      pct /= 2;
      
      if(randomReal() > 0.5) {
        // Append an insert
        var pos = (randomReal() * (docStr.length + 1)).floor();
        var str = randomWord() + ' ';
        _text0.append(op, {'i':str, 'p':pos});
        docStr = docStr.substring(0, pos) + str + docStr.substring(pos);
      } else {
        // Append a delete
        var pos = (randomReal() * docStr.length).floor();
        var length = min((randomReal() * 4).floor(), docStr.length - pos);
        _text0.append(op, {'d':docStr.substring(pos, pos + length), 'p':pos});
        docStr = docStr.substring(0, pos) + docStr.substring(pos + length);
      }
    }
    
    return [op, docStr];
  }

  @override
  serialize(doc) {
    return doc;
  }
  
  @override
  dynamic clone(obj) => JSON.decode(JSON.encode(obj));
}