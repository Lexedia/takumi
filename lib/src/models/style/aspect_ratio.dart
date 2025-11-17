import 'package:takumi/src/models/style/length_unit.dart';
import 'package:takumi/src/models/style/value.dart';

final class AspectRatio extends LengthUnit implements Value<double> {
  @override
  final double value;

  const AspectRatio(this.value, [super.unit]) : assert(value > 0.0);
}
