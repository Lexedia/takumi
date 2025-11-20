import 'value.dart';

/// Represents a value that can be a specific length, percentage, or automatic.
///
/// This corresponds to CSS values that can be specified as pixels, percentages,
/// or the 'auto' keyword for automatic sizing.
enum Unit implements Value<String> {
  /// Em value relative to the font size

  em('em'),

  /// Rem value relative to the root font size
  rem('rem'),

  /// Percentage value relative to parent container (0-100)
  percent('%'),

  /// Vw value relative to the viewport width (0-100)
  vw('vw'),

  /// Vh value relative to the viewport height (0-100)
  vh('vh'),

  /// Centimetre value
  cm('cm'),

  /// Millimetre value
  mm('mm'),

  /// Inch value
  inUnit('in'),

  /// Quarter value
  q('Q'),

  /// Point value
  pt('Pt'),

  /// Pica value
  pc('Pc'),

  /// Pixel value
  px('px');

  @override
  final String value;

  const Unit(this.value);
}

class LengthUnit {
  final Unit? unit;

  const LengthUnit([this.unit]);
}
