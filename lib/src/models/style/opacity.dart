import 'package:takumi/src/models/style/value.dart';

class Opacity implements Value<double> {
  @override
  final double value;

  const Opacity(this.value) : assert(value >= 0.0 && value <= 1.0);
}
