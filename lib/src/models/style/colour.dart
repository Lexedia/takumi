import 'value.dart';

final class Colour implements Value<String> {
  @override
  final String value;

  const Colour(this.value);

  factory Colour.rbg(int r, int g, int b) {
    return Colour('rgb($r, $g, $b)');
  }

  factory Colour.rgba(int r, int g, int b, double a) {
    return Colour('rgba($r, $g, $b, $a)');
  }

  factory Colour.hex(String hex) {
    return Colour('#${hex.replaceFirst('#', '')}');
  }
}

/// Alias for [Colour].
typedef Color = Colour;
