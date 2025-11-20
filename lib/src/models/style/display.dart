import 'value.dart';

/// The display property of a style.
enum Display implements Value<String> {
  /// The element is not displayed.
  none('none'),

  /// The element is a flex container.
  flex('flex'),

  /// The element is a grid container.
  grid('grid'),

  /// The element is displayed as an inline element.
  inline('inline'),

  /// The element is displayed as a block element.
  block('block');

  @override
  final String value;

  const Display(this.value);
}
