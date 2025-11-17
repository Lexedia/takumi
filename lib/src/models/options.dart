/// @docImport "package:takumi/takumi.dart";
library;

import 'dart:convert';

sealed class BaseRenderOptions {
  /// The width of the image.
  /// If not provided, the width will be automatically calculated based on the context.
  final int? width;

  /// The height of the image.
  /// If not provided, the height will be automatically calculated based on the context.
  final int? height;

  /// Whether debug borders should be drawn.
  final bool? shouldDrawDebugBorder;

  /// The device pixel ratio.
  final double devicePixelRatio;

  /// The font size to use when rendering text.
  final double fontSize;

  const BaseRenderOptions({
    this.devicePixelRatio = 1.0,
    this.fontSize = 16.0,
    this.shouldDrawDebugBorder,
    this.width,
    this.height,
  });

  Map<String, Object?> toMap() => {
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (shouldDrawDebugBorder != null) 'draw_debug_border': shouldDrawDebugBorder,
    'device_pixel_ratio': devicePixelRatio,
    'font_size': fontSize,
  };
}

/// Options to change the  behaviour of [Renderer.render] or [Renderer.renderSync].
final class RenderOptions extends BaseRenderOptions {
  /// The quality of the output if [format] is [OutputFormat.jpeg].
  final int? quality;

  /// The output format of the image.
  final OutputFormat? format;

  const RenderOptions({
    super.devicePixelRatio,
    super.fontSize,
    super.shouldDrawDebugBorder,
    this.format,
    super.height,
    this.quality,
    super.width,
  });

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    if (quality != null) 'quality': quality,
    if (format != null) 'format': format!.name,
  };

  String toJson() => json.encode(toMap());
}

/// Options to change the behaviour of animated renders.
final class RenderAnimationOptions extends BaseRenderOptions {
  /// The output format of the animation.
  final AnimationOutputFormat? format;

  const RenderAnimationOptions({
    super.devicePixelRatio,
    super.fontSize,
    super.shouldDrawDebugBorder,
    this.format,
    super.height,
    super.width,
  });

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    if (format != null) 'format': format!.name,
  };

  String toJson() => json.encode(toMap());
}

/// The output format of the image.
enum OutputFormat { avif, png, jpeg, raw, webp }

/// The output format of the animation.
enum AnimationOutputFormat { webp, apng }
