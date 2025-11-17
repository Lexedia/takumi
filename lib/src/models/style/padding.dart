import 'package:takumi/src/models/style/length_unit.dart';
import 'package:takumi/src/models/style/value.dart';

final class Padding extends LengthUnit implements Value<String> {
  @override
  final String value;

  const Padding(this.value, [super.unit]);
}
