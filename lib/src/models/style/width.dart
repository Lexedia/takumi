import 'length_unit.dart';
import 'value.dart';

final class Width extends LengthUnit implements Value<double> {
  @override
  final double value;

  const Width(this.value, [super.unit]) : assert(value >= 0.0);
}
