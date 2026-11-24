@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('invalid additions fail before the decoder and its error matcher',
      () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'test',
      'test/fixtures/invalid_add.dart',
      '--reporter=json',
    ]);
    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    final events = const LineSplitter()
        .convert(result.stdout as String)
        .where((line) => line.startsWith('{'))
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
    final errors = events.where((event) => event['type'] == 'error').toList();
    expect(errors, hasLength(10));
    for (final error in errors) {
      expect(error['error'], contains('Invalid JSON fixture path:'));
    }
    expect(
        events.where((event) =>
            event['type'] == 'testDone' && event['result'] != 'success'),
        hasLength(10));
  });
}
