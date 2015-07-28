library otdartlib.test.ottypes;

import 'package:test/test.dart';
import 'dart:convert';
import 'dart:math';
import '../lib/ottypes.dart';
import '../lib/atext_changeset.dart';
import 'lib/fuzzer.dart';

part 'ottypes/impl/atext_impl.dart';
part 'ottypes/impl/json0_impl.dart';
part 'ottypes/impl/text0_impl.dart';

part 'ottypes/atext-test.dart';
part 'ottypes/json0-test.dart';
part 'ottypes/text0-test.dart';

void main() {
  json0_test();
  text0_test();
  atext_test();
}