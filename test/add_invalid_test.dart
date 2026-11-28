@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('invalid additions fail before the decoder and its error matcher',
      () async {
    final events = await _runFailingFixture('test/fixtures/invalid_add.dart');
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

  test('invalid sequences fail at the step before the decoder runs', () async {
    final events =
        await _runFailingFixture('test/fixtures/invalid_sequence.dart');
    final errors = events.where((event) => event['type'] == 'error').toList();
    expect(errors, hasLength(5));
    for (final error in errors) {
      expect(
          error['error'], contains('Invalid JSON mutation sequence at step'));
      expect(error['error'], contains('Invalid JSON fixture path:'));
    }
    final messages = errors.map((event) => event['error'] as String);
    expect(messages,
        contains(contains('step 1: Invalid JSON fixture path: \$.missing')));
    expect(messages,
        contains(contains('step 3: Invalid JSON fixture path: \$.missing')));
    expect(messages,
        contains(contains('step 2: Invalid JSON fixture path: \$.items[0]')));
    expect(
        events.where((event) =>
            event['type'] == 'testDone' && event['result'] != 'success'),
        hasLength(5));
    final names = events
        .where((event) => event['type'] == 'testStart')
        .map((event) => (event['test'] as Map)['name']);
    expect(
        names, contains(contains('sequence (remove \$.id; set \$.id to 2)')));
  });
}

Future<List<Map<String, dynamic>>> _runFailingFixture(String path) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'test',
    path,
    '--reporter=json',
  ]);
  expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
  return const LineSplitter()
      .convert(result.stdout as String)
      .where((line) => line.startsWith('{'))
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .toList();
}
