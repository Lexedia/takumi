import 'length_unit.dart';
import 'value.dart';

final class Padding extends LengthUnit implements Value<String> {
  @override
  final String value;

  const Padding(this.value, [super.unit]);
}
