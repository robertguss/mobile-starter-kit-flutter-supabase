// @dart=3.6
// ignore_for_file: directives_ordering
// build_runner >=2.4.16
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:build_runner/src/build_plan/builder_factories.dart' as _i1;
import 'package:flutter_gen_runner/flutter_gen_runner.dart' as _i2;
import 'package:mockito/src/builder.dart' as _i3;
import 'package:riverpod_generator/builder.dart' as _i4;
import 'package:source_gen/builder.dart' as _i5;
import 'dart:io' as _i6;
import 'package:build_runner/src/bootstrap/processes.dart' as _i7;

final _builderFactories = _i1.BuilderFactories(
  {
    'flutter_gen_runner:flutter_gen_runner': [_i2.build],
    'mockito:mockBuilder': [_i3.buildMocks],
    'riverpod_generator:riverpod_generator': [_i4.riverpodBuilder],
    'source_gen:combining_builder': [_i5.combiningBuilder],
  },
  postProcessBuilderFactories: {'source_gen:part_cleanup': _i5.partCleanup},
);
void main(List<String> args) async {
  _i6.exitCode = await _i7.ChildProcess.run(
    args,
    _builderFactories,
  )!;
}
