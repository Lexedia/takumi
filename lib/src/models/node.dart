import 'dart:convert';

import 'style/style.dart';

/// A node representing any kind of node.
sealed class Node {
  /// The style this node has.
  final Style? style;

  /// Unsafe, add raw styles.
  /// Keys must use camelCase, and not kebab-case.
  final Map<String, Object?>? rawStyle;

  /// The tailwind classes this node has.
  final String? tw;

  Node({this.style, this.tw, this.rawStyle});

  Map<String, Object?> toMap() => {
    'type': switch (this) {
      ContainerNode() => 'container',
      TextNode() => 'text',
      ImageNode() => 'image',
    },
    'style': rawStyle ?? style?.toCssMap(),
    'tw': tw,
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
