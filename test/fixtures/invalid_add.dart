import 'package:json_decoder_test/json_decoder_test.dart';
import 'package:test/test.dart';

void main() {
  for (final scenario in [
    (name: 'existing key', path: <Object>['id']),
    (name: 'existing null', path: <Object>['nullable']),
    (name: 'missing parent', path: <Object>['missing', 'extra']),
    (name: 'null parent', path: <Object>['nullable', 'extra']),
    (name: 'scalar parent', path: <Object>['id', 'extra']),
    (name: 'replace array element', path: <Object>['items', 0]),
    (name: 'append array element', path: <Object>['items', 1]),
    (name: 'missing array parent', path: <Object>['items', 2, 'extra']),
    (name: 'array with object key', path: <Object>['items', 'extra']),
    (name: 'object with index', path: <Object>[0]),
  ]) {
    group(scenario.name, () {
      var calls = 0;
      testJsonDecoder(
        'decoder',
        fixture: {
          'id': 1,
          'nullable': null,
          'items': [{}]
        },
        decode: (_) {
          calls++;
          if (calls > 1)
            throw StateError('Decoder must not see an invalid target');
          return 1;
        },
        baseline: equals(1),
        cases: [
          DecoderCase.rejects(
              JsonMutation.add(scenario.path, 'extra'), isA<StateError>()),
        ],
      );
      tearDownAll(() => expect(calls, 1));
    });
  }
}
