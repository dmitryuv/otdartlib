library otdartlib.ottypes;

import 'package:collection/collection.dart';
import 'dart:convert';
import 'dart:math';
import 'atext_changeset.dart';

part 'src/ottypes/bootstrap_transform.dart';
part 'src/ottypes/atext.dart';
part 'src/ottypes/json0.dart';
part 'src/ottypes/text0.dart';
part 'src/ottypes/ottypefactory.dart';

abstract class OTType<T, E> {
  String get name;
  String get uri;

  T create([T initial]);
  T apply(T doc, E op);
  E transform(E op, E otherOp, String side);
  E invert(E op);
  E compose(E op1, E op2);
}