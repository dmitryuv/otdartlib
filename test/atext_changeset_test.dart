library otdartlib.test.atext_changeset;

import 'package:test/test.dart';
import 'dart:convert';
import '../lib/atext_changeset.dart';

part 'atext_changeset/attributelist-test.dart';
part 'atext_changeset/opcomponent-test.dart';
part 'atext_changeset/componentlist-test.dart';
part 'atext_changeset/builder-test.dart';
part 'atext_changeset/changeset-test.dart';
part 'atext_changeset/position-test.dart';

void main() {
  attributeList_test();
  position_test();
  opComponent_test();
  componentList_test();
  builder_test();
  changeset_test();
}