import 'value.dart';

/// Defines the direction of flex items within a flex container.
/// This enum determines how flex items are laid out along the main axis.
enum FlexDirection implements Value<String> {
  /// Flex items are laid out in a row, from left to right.
  row('row'),

  /// Flex items are laid out in a row, from right to left.
  rowReverse('row-reverse'),

  /// Flex items are laid out in a column, from top to bottom.
  column('column'),

  /// Flex items are laid out in a column, from bottom to top.
  columnReverse('column-reverse');

  @override
  final String value;

  const FlexDirection(this.value);
}
