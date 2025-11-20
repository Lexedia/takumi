enum FontStyle { normal, italic, oblique }

enum FontWeight {
  thin(100.0),
  extraLight(200.0),
  light(300.0),
  semiLight(350.0),
  normal(400.0),
  medium(500.0),
  semiBold(600.0),
  bold(700.0),
  extraBold(800.0),
  black(900.0),
  extraBlack(1000.0);

  final double weight;

  const FontWeight(this.weight);
}

enum FontWidth {
  ultraCondensed(0.50),
  extraCondensed(0.625),
  condensed(0.75),
  semiCondensed(0.875),
  normal(1.0),
  semiExpanded(1.125),
  expanded(1.25),
  extraExpanded(1.5),
  ultraExpanded(2.0);

  final double ratio;
  const FontWidth(this.ratio);

  static FontWidth parse(String s) => switch (s) {
    'ultra-condensed' => .ultraCondensed,
    'extra-condensed' => .extraCondensed,
    'condensed' => .condensed,
    'semi-condensed' => .semiCondensed,
    'normal' => .normal,
    'semi-expanded' => .semiExpanded,
    'expanded' => .expanded,
    'extra-expanded' => .extraExpanded,
    'ultra-expanded' => .ultraExpanded,
    _ => .normal,
  };
}
