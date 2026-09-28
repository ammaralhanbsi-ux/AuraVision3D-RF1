import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    final builder = CBuilder.library(
      name: 'aura_rf_engine',
      assetId: 'aura_rf_ffi.dart',
      language: Language.cpp,
      std: 'c++17',
      cppLinkStdLib: input.config.code.targetOS.name == 'android'
          ? 'c++_shared'
          : null,
      sources: const [
        'src/aura_rf_engine.cpp',
      ],
      includes: const [
        'src',
      ],
    );
    await builder.run(input: input, output: output);
  });
}
