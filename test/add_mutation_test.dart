import 'dart:convert';

import 'package:json_decoder_test/json_decoder_test.dart';
import 'package:test/test.dart';

void main() {
  for (final asynchronous in [false, true]) {
    final value = <String, dynamic>{
      'revision': 2,
      'flags': [true]
    };
    final path = <Object>['metadata'];
    final addition = JsonMutation.add(path, value);
    Map<String, dynamic> decode(Map<String, dynamic> json) {
      final snapshot = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      final metadata = json['metadata'] as Map<String, dynamic>?;
      (metadata?['flags'] as List<dynamic>?)?.clear();
      metadata?.clear();
      json.clear();
      return snapshot;
    }

    testJsonDecoder(
      'Added values are snapshotted and isolated (async: $asynchronous)',
      fixture: {'id': 42},
      decode: asynchronous ? (json) async => decode(json) : decode,
      baseline: equals({'id': 42}),
      cases: [
        for (var repeat = 0; repeat < 2; repeat++)
          DecoderCase.decodes(addition, {
            'id': 42,
            'metadata': {
              'revision': 2,
              'flags': [true]
            },
          }),
      ],
    );
    path[0] = 'changed';
    value['revision'] = 99;
    (value['flags'] as List).add(false);
  }

  testJsonDecoderFixtures(
    'Add to existing nested objects',
    decode: (json) => json,
    fixtures: [
      DecoderFixture(
        'object in an array',
        json: {
          'orders': [
            {'id': 1, 'details': <String, dynamic>{}},
          ],
        },
        cases: [
          DecoderCase.decodes(
            JsonMutation.add(['orders', 0, 'metadata'], {'revision': 2}),
            {
              'orders': [
                {
                  'id': 1,
                  'details': {},
                  'metadata': {'revision': 2}
                },
              ],
            },
          ),
          DecoderCase.decodes(
            JsonMutation.add(['orders', 0, 'details', 'note'], null),
            {
              'orders': [
                {
                  'id': 1,
                  'details': {'note': null}
                },
              ],
            },
          ),
        ],
      ),
      DecoderFixture(
        'empty and escaped keys',
        json: const {},
        cases: [
          DecoderCase.decodes(JsonMutation.add([''], null), {'': null}),
          DecoderCase.decodes(
            JsonMutation.add(['field.with["quotes"]'], [1, true, null]),
            {
              'field.with["quotes"]': [1, true, null]
            },
          ),
        ],
      ),
    ],
  );

  for (final asynchronous in [false, true]) {
    int strictDecode(Map<String, dynamic> json) {
      if (json.keys.any((key) => key != 'id')) {
        throw const FormatException('Unknown field');
      }
      return json['id'] as int;
    }

    testJsonDecoder(
      'Strict decoder rejects added fields (async: $asynchronous)',
      fixture: {'id': 42},
      decode: asynchronous ? (json) async => strictDecode(json) : strictDecode,
      baseline: equals(42),
      cases: [
        DecoderCase.rejects(
          JsonMutation.add(['extra'], true),
          isA<FormatException>(),
        ),
      ],
    );
  }

  test('add validates paths and JSON values at construction', () {
    expect(() => JsonMutation.add([], null), throwsArgumentError);
    expect(() => JsonMutation.add(['orders', -1], null), throwsArgumentError);
    expect(() => JsonMutation.add([true], null), throwsArgumentError);
    expect(() => JsonMutation.add(['extra'], Object()),
        throwsA(isA<JsonUnsupportedObjectError>()));
  });
}
