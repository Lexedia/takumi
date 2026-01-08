import 'dart:convert';

import 'style/style.dart';

/// {@template node_explanation}
/// A node representing any kind of node in the layout tree.
/// 
/// Priority rules for styles sources (highest to lowest):
/// 1. **[style]** - has the highest priority, values here override any Tailwind classes or [preset] values;
/// 2. **[tw]** - has a medium priority, meaning these classes override [preset] but get overriden by [style];
/// 3. **[preset]** - haw the lowest priority, those are supposed to be used when adding default styles to a node, so that [style] is free to also be used.
/// 
/// **Do** note that [rawStlyes] and [rawPresets] will **override** [style] and [preset] respectively.
/// {@endtemplate}
sealed class Node {
  /// The style this node has.
  final Style? style;

  /// The tailwind classes this node has.
  final String? tw;

  /// The preset this node has.
  final Style? preset;

  /// Unsafe, add raw styles.
  /// Keys must use camelCase, and not kebab-case.
  final Map<String, Object?>? rawStyle;

  /// Unsafe, add raw presets.
  /// Keys must use camelCase, and not kebab-case.
  final Map<String, Object?>? rawPreset;


  /// Creates a new [Node].
  /// 
  /// {@macro node_explanation}
  Node({this.style, this.tw, this.preset, this.rawStyle, this.rawPreset});

  Map<String, Object?> toMap() => {
    'type': switch (this) {
      ContainerNode() => 'container',
      TextNode() => 'text',
      ImageNode() => 'image',
    },
    'style': rawStyle ?? style?.toCssMap(),
    'tw': tw,
    'preset': rawPreset ?? preset?.toCssMap(),
  };

  String toJson() => json.encode(toMap());
}

/// A node representing a collection of child nodes.
final class ContainerNode extends Node {
  /// The children of this container node.
  final List<Node> children;

  ContainerNode({this.children = const [], super.style, super.tw, super.rawStyle});

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    'children': children.map((e) => e.toMap()).toList()
  };
}

/// A node representing a text node.
final class TextNode extends Node {
  /// The text content of this text node.
  final String text;

  TextNode(this.text, {super.style, super.tw, super.rawStyle});

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    'text': text,
  };
}

/// A node representing an image node.
final class ImageNode extends Node {
  /// The source URL of this image node.
  final String src;

  /// The width of this image node.
  final double? width;

  /// The height of this image node.
  final double? height;

  ImageNode(this.src, {this.width, this.height, super.style, super.tw, super.rawStyle});

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    'src': src,
    'width': width,
    'height': height,
  };
}
