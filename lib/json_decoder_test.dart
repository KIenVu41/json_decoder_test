/// Test a Dart decoder against intentional changes to a JSON object.
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';

/// One change to an existing field or array element in a JSON fixture.
///
/// Paths use string keys for objects and zero-based integer indices for arrays.
/// Each case starts with a fresh copy of the original fixture.
final class JsonMutation {
  /// Removes an existing object field or array element.
  JsonMutation.remove(Iterable<Object> path)
    : this._(path, remove: true, encodedValue: null);

  /// Replaces an existing value, including with null or an unknown enum value.
  JsonMutation.replace(Iterable<Object> path, Object? value)
    : this._(path, remove: false, encodedValue: jsonEncode(value));

  JsonMutation._(
    Iterable<Object> path, {
    required bool remove,
    required String? encodedValue,
  }) : path = List.unmodifiable(path),
       _remove = remove,
       _encodedValue = encodedValue {
    if (this.path.isEmpty ||
        this.path.any(
          (segment) => segment is! String && (segment is! int || segment < 0),
        )) {
      throw ArgumentError.value(this.path, 'path', 'Expected keys or indices');
    }
  }

  /// The immutable sequence of keys and indices leading to the target.
  final List<Object> path;
  final bool _remove;
  final String? _encodedValue;

  String get _location {
    final result = StringBuffer(r'$');
    for (final segment in path) {
      if (segment is String &&
          RegExp(r'^[a-zA-Z_][a-zA-Z_0-9]*$').hasMatch(segment)) {
        result.write('.$segment');
      } else {
        result.write('[${jsonEncode(segment)}]');
      }
    }
    return result.toString();
  }

  String get _description =>
      _remove ? 'remove $_location' : 'set $_location to $_encodedValue';

  void _apply(Map<String, dynamic> fixture) {
    Object? parent = fixture;
    for (final segment in path.take(path.length - 1)) {
      parent = switch (parent) {
        Map<String, dynamic> object when segment is String => object[segment],
        List<dynamic> array when segment is int && segment < array.length =>
          array[segment],
        _ => throw StateError('Invalid JSON fixture path: $_location'),
      };
    }

    final segment = path.last;
    switch (parent) {
      case Map<String, dynamic> object
          when segment is String && object.containsKey(segment):
        if (_remove) {
          object.remove(segment);
        } else {
          object[segment] = jsonDecode(_encodedValue!);
        }
      case List<dynamic> array when segment is int && segment < array.length:
        if (_remove) {
          array.removeAt(segment);
        } else {
          array[segment] = jsonDecode(_encodedValue!);
        }
      default:
        throw StateError('Invalid JSON fixture path: $_location');
    }
  }
}

/// Expected decoder behavior for one mutation.
final class DecoderCase {
  /// Expects decoding to succeed and the result to match [expected].
  ///
  /// [expected] follows the same rules as the second argument to [expect].
  const DecoderCase.decodes(this.mutation, Object? expected)
    : _expected = expected,
      _throws = false;

  /// Expects the decoder to throw or complete with an error matching [error].
  const DecoderCase.rejects(this.mutation, Matcher error)
    : _expected = error,
      _throws = true;

  /// The change to apply before invoking the decoder.
  final JsonMutation mutation;
  final Object? _expected;
  final bool _throws;
}

/// Registers a baseline test and one isolated test per case.
///
/// [decode] can return a value or a future.
/// The baseline must decode successfully. [baseline] optionally checks its
/// result. Call this function from `main()` or within a test group.
void testJsonDecoder<T>(
  String description, {
  required Map<String, dynamic> fixture,
  required FutureOr<T> Function(Map<String, dynamic>) decode,
  required Iterable<DecoderCase> cases,
  Matcher? baseline,
}) {
  final encodedFixture = jsonEncode(fixture);
  Map<String, dynamic> freshFixture() =>
      jsonDecode(encodedFixture) as Map<String, dynamic>;

  group(description, () {
    test('decodes the original fixture', () async {
      final result = await decode(freshFixture());
      if (baseline != null) expect(result, baseline);
    });

    for (final scenario in cases) {
      final mutation = scenario.mutation;
      final behavior = scenario._throws ? 'rejects' : 'decodes';
      test('$behavior when we ${mutation._description}', () async {
        final input = freshFixture();
        mutation._apply(input);
        if (scenario._throws) {
          await expectLater(() => decode(input), throwsA(scenario._expected));
        } else {
          expect(await decode(input), scenario._expected);
        }
      });
    }
  });
}
