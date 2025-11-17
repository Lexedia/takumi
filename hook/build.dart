import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  hierarchicalLoggingEnabled = true;
  await build(args, (input, output) async {
    await const RustBuilder(
      assetName: 'src/ffi/takumi.g.dart',
      cratePath: 'takumi-shim',
    ).run(
      input: input,
      output: output,
      logger: Logger.root
        ..level = Level.ALL
        ..onRecord.listen(print),
    );

    Logger.root.shout(output.json);
  });
}
