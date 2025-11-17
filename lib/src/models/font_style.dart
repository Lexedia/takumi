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
