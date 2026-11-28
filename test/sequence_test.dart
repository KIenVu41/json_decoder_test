import 'package:json_decoder_test/json_decoder_test.dart';
import 'package:test/test.dart';

void main() {
  for (final asynchronous in [false, true]) {
    final value = <String, dynamic>{
      'revision': 1,
      'flags': [true]
    };
    final steps = [
      JsonMutation.replace(['type'], 'company'),
      JsonMutation.add(['company_name'], 'Acme'),
      JsonMutation.add(['metadata'], value),
    ];
    final sequence = JsonMutation.sequence(steps);
    group('Dependent fields (async: $asynchronous)', () {
      var calls = 0;
      String decode(Map<String, dynamic> json) {
        calls++;
        if (json['type'] == 'person') {
          json.clear();
          return 'person';
        }
        final company = json['company_name'];
        if (company is! String)
          throw const FormatException('Missing company name');
        final metadata = json['metadata'] as Map<String, dynamic>;
        final flags = metadata['flags'] as List<dynamic>;
        final result =
            '${json['type']}:$company:${json['name']}:${metadata['revision']}:${flags.length}';
        flags.clear();
        metadata.clear();
        json.clear();
        return result;
      }

      testJsonDecoderFixtures(
        'Customer.fromJson',
        decode: asynchronous ? (json) async => decode(json) : decode,
        fixtures: [
          DecoderFixture(
            'person to company',
            json: {'type': 'person', 'name': 'Ada'},
            expected: equals('person'),
            cases: [
              DecoderCase.decodes(sequence, 'company:Acme:Ada:1:1'),
              DecoderCase.decodes(sequence, 'company:Acme:Ada:1:1'),
              DecoderCase.rejects(
                JsonMutation.sequence([
                  JsonMutation.replace(['type'], 'company'),
                  JsonMutation.remove(['name']),
                ]),
                isA<FormatException>(),
              ),
            ],
          ),
        ],
      );
      tearDownAll(() => expect(calls, 4));
    });
    steps.clear();
    steps.add(JsonMutation.remove(['not_in_the_fixture']));
    value['revision'] = 99;
    (value['flags'] as List).add(false);
  }

  final fixture = <String, dynamic>{
    'items': [
      {'id': 'a'},
      {'id': 'b'},
      {'id': 'c'}
    ],
    'obsolete': 1,
  };
  testJsonDecoder(
    'Sequences resolve paths against preceding steps',
    fixture: fixture,
    decode: (json) => json,
    baseline: equals(fixture),
    cases: [
      DecoderCase.decodes(
        JsonMutation.sequence([
          JsonMutation.remove(['items', 0]),
          JsonMutation.replace(['items', 0, 'id'], 'B'),
          JsonMutation.remove(['obsolete']),
        ]),
        {
          'items': [
            {'id': 'B'},
            {'id': 'c'}
          ]
        },
      ),
      DecoderCase.decodes(
        JsonMutation.sequence([
          JsonMutation.add(['metadata'], {}),
          JsonMutation.add(['metadata', 'revision'], 1),
          JsonMutation.replace(['metadata', 'revision'], 2),
        ]),
        {
          ...fixture,
          'metadata': {'revision': 2}
        },
      ),
      DecoderCase.decodes(
        JsonMutation.sequence([
          JsonMutation.add(['metadata'], null),
          JsonMutation.replace(['metadata'], {'active': true}),
          JsonMutation.add(['metadata', 'note'], null),
        ]),
        {
          ...fixture,
          'metadata': {'active': true, 'note': null}
        },
      ),
      DecoderCase.decodes(
        JsonMutation.sequence([
          JsonMutation.remove(['obsolete']),
          JsonMutation.sequence([
            JsonMutation.add(['extra'], 1),
            JsonMutation.replace(['extra'], 2),
          ]),
        ]),
        {'items': fixture['items'], 'extra': 2},
      ),
    ],
  );

  test('sequences require steps and expose an immutable root path', () {
    expect(() => JsonMutation.sequence([]), throwsArgumentError);
    final sequence = JsonMutation.sequence([
      JsonMutation.add(['extra'], null)
    ]);
    expect(sequence.path, isEmpty);
    expect(() => sequence.path.add('extra'), throwsUnsupportedError);
    expect(() => JsonMutation.remove(sequence.path), throwsArgumentError);
    expect(
        () => JsonMutation.replace(sequence.path, null), throwsArgumentError);
    expect(() => JsonMutation.add(sequence.path, null), throwsArgumentError);
  });
}
