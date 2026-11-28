import 'package:json_decoder_test/json_decoder_test.dart';
import 'package:test/test.dart';

void main() {
  final fixture = <String, dynamic>{
    'id': 1,
    'items': [{}]
  };
  for (final scenario in [
    (
      name: 'replace removed key',
      steps: [
        JsonMutation.remove(['id']),
        JsonMutation.replace(['id'], 2),
      ]
    ),
    (
      name: 'add duplicate key',
      steps: [
        JsonMutation.add(['extra'], 1),
        JsonMutation.add(['extra'], 2),
      ]
    ),
    (
      name: 'use removed array index',
      steps: [
        JsonMutation.remove(['items', 0]),
        JsonMutation.replace(['items', 0], {}),
      ]
    ),
    (
      name: 'invalid first step',
      steps: [
        JsonMutation.replace(['missing'], 2),
        JsonMutation.add(['extra'], true),
      ]
    ),
    (
      name: 'invalid nested step',
      steps: [
        JsonMutation.add(['metadata'], {}),
        JsonMutation.sequence([
          JsonMutation.add(['metadata', 'revision'], 1),
          JsonMutation.replace(['missing'], 2),
        ]),
      ]
    ),
  ]) {
    group(scenario.name, () {
      var calls = 0;
      testJsonDecoder(
        'decoder',
        fixture: fixture,
        decode: (json) {
          calls++;
          if (json.containsKey('canary')) {
            expect(json, {...fixture, 'canary': true});
          } else if (calls > 1) {
            throw StateError('Decoder must not see an invalid sequence');
          }
          return 1;
        },
        baseline: equals(1),
        cases: [
          DecoderCase.rejects(
              JsonMutation.sequence(scenario.steps), isA<StateError>()),
          DecoderCase.decodes(JsonMutation.add(['canary'], true), 1),
        ],
      );
      tearDownAll(() => expect(calls, 2));
    });
  }
}
