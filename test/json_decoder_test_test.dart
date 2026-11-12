import 'package:json_decoder_test/json_decoder_test.dart';
import 'package:test/test.dart';

void main() {
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
