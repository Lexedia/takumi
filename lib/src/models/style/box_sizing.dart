import 'package:takumi/src/models/style/value.dart';

/// Defines how the width and height of an element are calculated.
///
/// This enum determines whether the width and height properties include padding and border, or just the content area.
enum BoxSizing implements Value<String> {
  /// The width and height properties include only the content area.
  contentBox('content-box'),

  /// The width and height properties include content, padding, and border.
  borderBox('border-box');

  @override
  final String value;

  const BoxSizing(this.value);
}
