import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

import 'src/openapitodart_impl.dart';

void main(List<String> args) {
  var parser = ArgParser();
  parser.addOption('input',
      abbr: 'i', mandatory: true, help: 'Input OpenAPI yaml filepath');
  parser.addOption('output',
      abbr: 'o',
      mandatory: true,
      help: 'Output models and repositories dart filepath');
  parser.addOption('server', abbr: 's', mandatory: true, help: 'Server URL');
  final results = parser.parse(args);

  final input = results['input'] as String;
  final yaml = File(input).readAsStringSync();
  final y = loadYaml(yaml);
  final openApi = OpenApi.fromMap(y);
  final r = generateDartCode(openApi, results['server']);
  try {
    File(results['output']).writeAsStringSync(formatter.format(r));
  } catch (e) {
    print(e);
    print(r);
    rethrow;
  }
}
