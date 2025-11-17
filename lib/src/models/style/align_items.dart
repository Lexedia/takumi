import 'package:takumi/src/models/style/value.dart';

/// Defines how flex items are aligned along the cross axis.
///
/// This enum determines how items are aligned within the flex container
/// along the cross axis (perpendicular to the main axis).
enum AlignItems implements Value<String> {
  /// Flex items are stretched to fill the container.
  stretch('stretch'),

  /// Flex items are aligned to the center of the container.
  center('center'),

  /// Flex items are aligned to the start of the container.
  flexStart('flex-start'),

  /// Flex items are aligned to the end of the container.
  flexEnd('flex-end'),

  /// Flex items are aligned along their baseline.
  baseline('baseline');

  @override
  final String value;

  const AlignItems(this.value);
}
