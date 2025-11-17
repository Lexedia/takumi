import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');
  FfiGenerator(
    headers: Headers(
      entryPoints: [packageRoot.resolve('takumi-shim/bindings.h')],
    ),
    output: Output(dartFile: packageRoot.resolve('lib/src/ffi/takumi.g.dart')),
    functions: Functions(
      include: (decl) => decl.originalName.startsWith('takumi_') || decl.originalName == 'Renderer',
    ),
  ).generate();
}
