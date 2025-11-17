// css_global_keyword.dart
import 'package:takumi/src/models/style/value.dart';

enum CssGlobalKeyword implements Value<String> {
  inherit('inherit'),
  initial('initial'),
  unset('unset'),
  revert('revert'),
  auto('auto');

  @override
  final String value;
  const CssGlobalKeyword(this.value);
}
