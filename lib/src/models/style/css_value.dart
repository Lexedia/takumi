import 'length_unit.dart';
import 'value.dart';

import 'css_global_keyword.dart';

/// A small union type representing the TypeScript `CssValue<T>`.
/// It can hold either a concrete value `T` or a global keyword.
sealed class CssValue<T> {
  const CssValue();

  R when<R>({
    required R Function(T value) value,
    required R Function(CssGlobalKeyword keyword) keyword,
  });

  /// Convenience: turn into a CSS string. If `T` implements `Value`
  /// we will use its `.value` to string, otherwise we call `toString()` on T.
  Object toCss() {
    return when(
      value: (v) {
        if (v is LengthUnit && v.unit != null && v is Value) {
          var val = v as dynamic;
          return '${val.value is num ? val.value % 1 == 0 ? val.value.toInt() : val.value : val.value}${v.unit!.value}';
        }
        if (v is Value) return (v as Value).value.toString();
        // if double has decimals, keep them, otherwise convert to int string
        if (v is num) {
          if (v % 1 == 0) {
            return v.toInt();
          }
          return v;
        }
        return v.toString();
      },
      keyword: (k) => k.value,
    );
  }

  const factory CssValue.of(T value) = CssValueValue<T>;
  const factory CssValue.keyword(CssGlobalKeyword k) = CssValueKeyword<T>;
}

final class CssValueValue<T> extends CssValue<T> {
  final T value;
  const CssValueValue(this.value);

  @override
  R when<R>({
    required R Function(T value) value,
    required R Function(CssGlobalKeyword keyword) keyword,
  }) =>
      value(this.value);
}

final class CssValueKeyword<T> extends CssValue<T> {
  final CssGlobalKeyword keyword;
  const CssValueKeyword(this.keyword);

  @override
  R when<R>({
    required R Function(T value) value,
    required R Function(CssGlobalKeyword keyword) keyword,
  }) =>
      keyword(this.keyword);
}