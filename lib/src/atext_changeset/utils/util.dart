part of otdartlib.atext_changeset;

abstract class Clonable {
  dynamic clone();
}

class _util {
  static int parseInt36(String str) => int.parse(str, radix: 36);
  static String toString36(int num) => num.toRadixString(36);
 
  static zip (ComponentList list1, ComponentList list2, bool needSplitFunc(OpComponent op1, OpComponent op2), List<OpComponent> func(OpComponent op1, OpComponent op2, OpComponent opOut)) {
    var iter1 = list1.iterator..moveNext();
    var iter2 = list2.iterator..moveNext();
    var res = new ComponentList();
    var op1 = new OpComponent.empty();
    var op1part = new OpComponent.empty();
    var op2 = new OpComponent.empty();
    var op2part = new OpComponent.empty();
    var opOut = new OpComponent.empty();
  
    while(op1.isNotEmpty || op1part.isNotEmpty || iter1.current != null || op2.isNotEmpty || op2part.isNotEmpty || iter2.current != null) {
      var z = _zipNext(op1, op1part, iter1);
      op1 = z[0]; op1part = z[1];

      z = _zipNext(op2, op2part, iter2);
      op2 = z[0]; op2part = z[1];
  
      if(op1.isNotEmpty && op2.isNotEmpty) {
        // pre-splitting into equal slices greatly reduces
        // number of code branches and makes code easier to read
        bool split = needSplitFunc(op1, op2);
  
        if(split && op1.chars > op2.chars) {
          op1part = op1.sliceRight(op2.chars, op2.lines);
          op1 = op1.sliceLeft(op2.chars, op2.lines);
        } else if(split && op1.chars < op2.chars) {
          op2part = op2.sliceRight(op1.chars, op1.lines);
          op2 = op2.sliceLeft(op1.chars, op1.lines);
        }
      }
  
      if(op1.isNotEmpty || op2.isNotEmpty) {
        var r = func(op1, op2, opOut);
        op1 = r[0];
        op2 = r[1];
        opOut = r[2];
      }
  
      if(opOut.isNotEmpty) {
        res.add(opOut);
        opOut = new OpComponent.empty();
      }
    }
  
    return res;
  }

//  static zip (ComponentList list1, ComponentList list2, bool needSplitFunc(OpComponent op1, OpComponent op2), void func(OpComponent op1, OpComponent op2, OpComponent opOut)) {
//    BackBufferIterator iter1 = list1.iterator;
//    BackBufferIterator iter2 = list2.iterator;
//    var res = new ComponentList();
//    var op1 = new OpComponent(null);
//    var op2 = new OpComponent(null);
//    var opOut = new OpComponent(null);
//
//    while(iter1.moveNext() || iter2.moveNext()) {
//      iter1.current?.copyTo(op1);
//      iter2.current?.copyTo(op2);
//
//      if(op1.isNotEmpty && op2.isNotEmpty) {
//        // pre-splitting into equal slices greatly reduces
//        // number of code branches and makes code easier to read
//        bool split = needSplitFunc(op1, op2);
//
//        if(split) {
//          // if op1.chars <= op2.chars, it's true that op1.lines <= op2.lines
//          int c = min(op1.chars, op2.chars);
//          int l = min(op1.lines, op2.lines);
//          iter1.pushBack(op1.sliceRight(new OpComponent(null), c, l).clone());
//          iter2.pushBack(op2.sliceRight(new OpComponent(null), c, l).clone());
//        }
//      }
//
//      if(op1.isNotEmpty || op2.isNotEmpty) {
//        func(op1, op2, opOut);
//
//        if(op1.isNotEmpty) {
//          iter1.pushBack(op1.clone());
//        }
//        if(op2.isNotEmpty) {
//          iter2.pushBack(op2.clone());
//        }
//      }
//
//      if(opOut.isNotEmpty) {
//        res.add(opOut.clone());
//        opOut.skip();
//      }
//    }
//
//    return res;
//  }


  static List<OpComponent> _zipNext(OpComponent op, OpComponent part, BackBufferIterator<OpComponent> iter) {
    if(op.isEmpty) {
      if(part.isNotEmpty) {
        op = part;
        part = new OpComponent.empty();
      } else if(iter.current != null) {
        op = iter.current;
        iter.moveNext();
      }
    }

    return [op, part];
  }
}
