import 'package:json_decoder_test/json_decoder_test.dart';
import 'package:test/test.dart';

void main() {
  for (final asynchronous in [false, true]) {
    final payload = <String, dynamic>{'value': 'invalid'};
    int decode(Map<String, dynamic> json) {
      final value = json.remove('value');
      if (value is! int) throw const FormatException('Expected integer');
      return value;
    }

    testJsonDecoderFixtures<int>(
      'Rejected fixtures (async: $asynchronous)',
      decode: asynchronous ? (json) async => decode(json) : decode,
      fixtures: [
        DecoderFixture.rejects(
          'invalid value',
          json: payload,
          error: isA<FormatException>(),
        ),
        DecoderFixture.rejects(
          'same payload remains isolated',
          json: payload,
          error: isA<FormatException>(),
        ),
        DecoderFixture('valid value',
            json: {'value': 42}, expected: equals(42)),
      ],
    );
    payload['value'] = 42;
  }

  final known = {'sourceType': 2};

  testJsonDecoderFixtures(
    'Named fixtures',
    decode: (json) async {
      final sourceType = json.remove('sourceType') as int?;
      return sourceType == null || sourceType == 2 ? sourceType : -1;
    },
    fixtures: [
      DecoderFixture(
        'known source',
        json: known,
        expected: equals(2),
        cases: [
          DecoderCase.decodes(JsonMutation.replace(['sourceType'], 999), -1),
          DecoderCase.decodes(JsonMutation.replace(['sourceType'], null), null),
        ],
      ),
      DecoderFixture(
        'unrecognized source',
        json: {'sourceType': 999},
        expected: equals(-1),
      ),
      DecoderFixture(
        'explicit null',
        json: {'sourceType': null},
        expected: isNull,
      ),
    ],
  );
  known['sourceType'] = 1;

  testJsonDecoder(
    'Required nested field',
    fixture: {
      'order': {'id': 42},
    },
    decode: (json) {
      final order = json['order'] as Map<String, dynamic>;
      if (!order.containsKey('id')) throw const FormatException('Missing id');
      return order['id'] as int;
    },
    baseline: equals(42),
    cases: DecoderCase.rejectsMissingOrNull(
      ['order', 'id'],
      isA<FormatException>(),
      nullError: isA<TypeError>(),
    ),
  );

  testJsonDecoder(
    'Asynchronous decoder',
    fixture: {'value': 1},
    decode: (json) async {
      final value = json['value'];
      if (value is! int) throw const FormatException('Expected an integer');
      return value;
    },
    baseline: equals(1),
    cases: [
      DecoderCase.decodes(JsonMutation.replace(['value'], 2), 2),
      DecoderCase.rejects(
        JsonMutation.replace(['value'], null),
        isA<FormatException>(),
      ),
    ],
  );

  testJsonDecoder(
    'Nested fixture isolation',
    fixture: {
      'orders': [
        {'status': 'paid', 'quantity': 1},
        {'status': 'pending'},
      ],
    },
    decode: (json) {
      final orders = json['orders'] as List<dynamic>;
      final firstOrder = orders.first as Map<String, dynamic>;
      final result = '${orders.length}:${firstOrder.remove('status')}';
      orders.clear();
      return result;
    },
    baseline: equals('2:paid'),
    cases: [
      DecoderCase.decodes(
        JsonMutation.replace(['orders', 0, 'status'], 'paused'),
        '2:paused',
      ),
      DecoderCase.decodes(JsonMutation.remove(['orders', 0]), '1:pending'),
      DecoderCase.decodes(
        JsonMutation.remove(['orders', 0, 'quantity']),
        '2:paid',
      ),
    ],
  );

  test('rejects empty and invalid mutation paths', () {
    expect(() => JsonMutation.remove([]), throwsArgumentError);
    expect(() => JsonMutation.remove(['orders', -1]), throwsArgumentError);
    expect(() => JsonMutation.remove([true]), throwsArgumentError);
  });
}
