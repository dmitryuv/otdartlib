part of otdartlib.atext_changeset;

abstract class Clonable {
  dynamic clone();
}

class _util {
  static int parseInt36(String str) => int.parse(str, radix: 36);
  static String toString36(int num) => num.toRadixString(36);
 
  static zip (ComponentList list1, ComponentList list2, bool needSplitFunc(OpComponent op1, OpComponent op2), void func(OpComponent op1, OpComponent op2, OpComponent opOut)) {
    var iter1 = list1.iterator..moveNext();
    var iter2 = list2.iterator..moveNext();
    var res = new ComponentList();
    var op1 = new OpComponent(null);
    var op1part = new OpComponent(null);
    var op2 = new OpComponent(null);
    var op2part = new OpComponent(null);
    var opOut = new OpComponent(null);
  
    while(op1.isNotEmpty || op1part.isNotEmpty || iter1.current != null || op2.isNotEmpty || op2part.isNotEmpty || iter2.current != null) {
      _zipNext(op1, op1part, iter1);
      _zipNext(op2, op2part, iter2);
  
      if(op1.isNotEmpty && op2.isNotEmpty) {
        // pre-splitting into equal slices greatly reduces
        // number of code branches and makes code easier to read
        bool split = needSplitFunc(op1, op2);
  
        if(split && op1.chars > op2.chars) {
          op1.copyTo(op1part)
            .trimLeft(op2.chars, op2.lines);
          op1.trimRight(op2.chars, op2.lines);
        } else if(split && op1.chars < op2.chars) {
          op2.copyTo(op2part)
            .trimLeft(op1.chars, op1.lines);
          op2.trimRight(op1.chars, op1.lines);
        }
      }
  
      if(op1.isNotEmpty || op2.isNotEmpty) {
        func(op1, op2, opOut);
      }
  
      if(opOut.isNotEmpty) {
        res.add(opOut.clone());
        opOut.skip();
      }
    }
  
    return res;
  }
  
  static void _zipNext(OpComponent op, OpComponent part, BackBufferIterator<OpComponent> iter) {
    if(op.isEmpty) {
      if(part.isNotEmpty) {
        part.copyTo(op);
        part.skip();
      } else if(iter.current != null) {
        iter.current.copyTo(op);
        iter.moveNext();
      }
    }
  }
}
