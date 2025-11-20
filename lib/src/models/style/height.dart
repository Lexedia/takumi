import 'length_unit.dart';
import 'value.dart';

final class Height extends LengthUnit implements Value<double> {
  @override
  final double value;

  const Height(this.value, [super.unit]) : assert(value >= 0.0);
}
