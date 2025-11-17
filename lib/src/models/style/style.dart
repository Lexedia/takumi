import 'package:takumi/src/models/style/aspect_ratio.dart';
import 'package:takumi/src/models/style/box_sizing.dart';
import 'package:takumi/src/models/style/colour.dart';
import 'package:takumi/src/models/style/css_value.dart';
import 'package:takumi/src/models/style/display.dart';
import 'package:takumi/src/models/style/flex_direction.dart';
import 'package:takumi/src/models/style/height.dart';
import 'package:takumi/src/models/style/opacity.dart';
import 'package:takumi/src/models/style/padding.dart';
import 'package:takumi/src/models/style/width.dart';

/// A style representing various CSS-like properties.
final class Style {
  /// The box sizing of this style.
  final CssValue<BoxSizing>? boxSizing;

  /// The opacity of this style.
  final CssValue<Opacity>? opacity;

  /// The display property of this style.
  final CssValue<Display>? display;

  /// The width of this style.
  final CssValue<Width>? width;

  /// The height of this style.
  final CssValue<Height>? height;

  /// The max width of this style.
  final CssValue<Width>? maxWidth;

  /// The max height of this style.
  final CssValue<Height>? maxHeight;

  /// The min width of this style.
  final CssValue<Width>? minWidth;

  /// The min height of this style.
  final CssValue<Height>? minHeight;

  /// The aspect ratio of this style.
  final CssValue<AspectRatio>? aspectRatio;

  /// The flex direction of this style.
  final CssValue<FlexDirection>? flexDirection;

  /// The colour of this style.
  final CssValue<Colour>? color;

  /// The padding of this style.
  final CssValue<Padding>? padding;

  /// The background colour of this style.
  final CssValue<Colour>? backgroundColor;

  /// The background image of this style.
  final CssValue<String>? backgroundImage;

  /// The font size of this style.
  final CssValue<double>? fontSize;

  /// The font weight of this style.
  final CssValue<String>? fontWeight;

  /// The line clamp of this style.
  final CssValue<int>? lineClamp;

  /// Creates a new [Style] with the given properties.
  Style({
    this.boxSizing,
    this.opacity,
    this.display,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.minWidth,
    this.minHeight,
    this.aspectRatio,
    this.flexDirection,
    this.color,
    this.padding,
    this.backgroundColor,
    this.backgroundImage,
    this.fontSize,
    this.fontWeight,
    this.lineClamp,
  });

  final Map<String, Object> cssMap = {};

  void addCssProperty<T>(String name, CssValue<T>? value) {
    if (value != null) {
      cssMap[name] = value.toCss();
    }
  }

  Map<String, Object> toCssMap() {
    addCssProperty('boxSizing', boxSizing);
    addCssProperty('opacity', opacity);
    addCssProperty('display', display);
    addCssProperty('width', width);
    addCssProperty('height', height);
    addCssProperty('maxWidth', maxWidth);
    addCssProperty('maxHeight', maxHeight);
    addCssProperty('minWidth', minWidth);
    addCssProperty('minHeight', minHeight);
    addCssProperty('aspect-ratio', aspectRatio);
    addCssProperty('flexDirection', flexDirection);
    addCssProperty('color', color);
    addCssProperty('padding', padding);
    addCssProperty('backgroundColor', backgroundColor);
    addCssProperty('backgroundImage', backgroundImage);
    addCssProperty('fontSize', fontSize);
    addCssProperty('fontWeight', fontWeight);
    addCssProperty('lineClamp', lineClamp);

    return cssMap;
  }
}
