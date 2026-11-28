/// Test a Dart decoder against intentional changes to a JSON object.
library;

import 'dart:async';
import 'dart:convert';

import 'package:matcher/expect.dart';
import 'package:test_api/scaffolding.dart';

/// A change, or ordered sequence of changes, to a JSON fixture.
///
/// Paths use string keys for objects and zero-based integer indices for arrays.
/// Each case starts with a fresh copy of the original fixture.
/// Remove, replace and add paths must be nonempty. Their targets are checked
/// against the current fixture when each operation runs. Remove and replace
/// require an existing value; add requires a missing key with an existing parent.
/// Invalid targets fail the test before the decoder runs.
final class JsonMutation {
  /// Removes an existing object field or array element.
  JsonMutation.remove(Iterable<Object> path)
      : this._(path, remove: true, encodedValue: null);

  /// Replaces an existing value, including with null or an unknown enum value.
  ///
  /// [value] must be JSON-encodable.
  JsonMutation.replace(Iterable<Object> path, Object? value)
      : this._(path, remove: false, encodedValue: jsonEncode(value));

  /// Adds a missing object key without overwriting an existing value.
  ///
  /// Parent objects and arrays in [path] must already exist. The final segment
  /// must be an object key; inserting array elements is not supported.
  /// [value] is JSON-encoded immediately and copied independently for each case.
  JsonMutation.add(Iterable<Object> path, Object? value)
      : this._(path, remove: false, add: true, encodedValue: jsonEncode(value));

  /// Applies a nonempty snapshot of [mutations] in order to one fixture copy.
  ///
  /// Each step sees the result of preceding steps. Nested sequences contribute
  /// their steps in order. An invalid target fails before the decoder runs,
  /// with a one-based step number. [path] is empty to represent the fixture root.
  JsonMutation.sequence(Iterable<JsonMutation> mutations)
      : path = const [],
        _remove = false,
        _add = false,
        _encodedValue = null,
        _sequence = List.unmodifiable(
          mutations.expand((mutation) => mutation._sequence ?? [mutation]),
        ) {
    if (_sequence!.isEmpty) {
      throw ArgumentError('A mutation sequence must not be empty.');
    }
  }

  JsonMutation._(
    Iterable<Object> path, {
    required bool remove,
    bool add = false,
    required String? encodedValue,
  })  : path = List.unmodifiable(path),
        _remove = remove,
        _add = add,
        _encodedValue = encodedValue,
        _sequence = null {
    if (this.path.isEmpty ||
        this.path.any(
              (segment) =>
                  segment is! String && (segment is! int || segment < 0),
            )) {
      throw ArgumentError.value(this.path, 'path', 'Expected keys or indices');
    }
  }

  /// The immutable keys and indices leading to a single-operation target.
  ///
  /// Empty for [JsonMutation.sequence], which applies at the fixture root.
  final List<Object> path;
  final bool _remove;
  final bool _add;
  final String? _encodedValue;
  final List<JsonMutation>? _sequence;

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

  String get _description {
    final steps = _sequence;
    if (steps != null) {
      return 'sequence (${steps.map((step) => step._description).join('; ')})';
    }
    return _remove
        ? 'remove $_location'
        : '${_add ? 'add' : 'set'} $_location to $_encodedValue';
  }

  void _apply(Map<String, dynamic> fixture) {
    final steps = _sequence;
    if (steps != null) {
      for (var index = 0; index < steps.length; index++) {
        try {
          steps[index]._apply(fixture);
        } on StateError catch (error) {
          throw StateError(
            'Invalid JSON mutation sequence at step ${index + 1}: ${error.message}',
          );
        }
      }
      return;
    }
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
          when _add && segment is String && !object.containsKey(segment):
        object[segment] = jsonDecode(_encodedValue!);
      case Map<String, dynamic> object
          when !_add && segment is String && object.containsKey(segment):
        if (_remove) {
          object.remove(segment);
        } else {
          object[segment] = jsonDecode(_encodedValue!);
        }
      case List<dynamic> array
          when !_add && segment is int && segment < array.length:
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

  /// Creates separate cases for a missing field and an explicit null value.
  ///
  /// [path] must identify an existing field in the original fixture.
  /// Both cases use [error] unless [nullError] supplies a different matcher
  /// for explicit null.
  static List<DecoderCase> rejectsMissingOrNull(
    Iterable<Object> path,
    Matcher error, {
    Matcher? nullError,
  }) {
    final missing = JsonMutation.remove(path);
    return [
      DecoderCase.rejects(missing, error),
      DecoderCase.rejects(
        JsonMutation.replace(missing.path, null),
        nullError ?? error,
      ),
    ];
  }

  /// The change to apply before invoking the decoder.
  final JsonMutation mutation;
  final Object? _expected;
  final bool _throws;
}

/// A named JSON input with an expected decoding outcome.
final class DecoderFixture {
  /// Creates a fixture whose original JSON must decode successfully.
  const DecoderFixture(
    this.name, {
    required this.json,
    this.expected,
    this.cases = const [],
  }) : _error = null;

  /// Creates one test expecting [json] to throw or complete with [error].
  ///
  /// The JSON is snapshotted when tests are registered. This fixture has no
  /// mutation cases because its original payload is expected to be rejected.
  const DecoderFixture.rejects(
    this.name, {
    required this.json,
    required Matcher error,
  })  : expected = null,
        cases = const [],
        _error = error;

  /// The name included in the test group.
  final String name;

  /// The JSON-encodable input, snapshotted when tests are registered.
  final Map<String, dynamic> json;

  /// The optional matcher for the decoded original JSON.
  final Matcher? expected;

  /// Additional cases applied independently to copies of this fixture.
  final Iterable<DecoderCase> cases;
  final Matcher? _error;
}

/// Registers a group for each named fixture using the same [decode] function.
///
/// Successful fixtures get a baseline test and one test per mutation.
/// Rejected fixtures get one test checking their error matcher. Test names
/// include [description] and the fixture name. Call from `main()` or a group.
void testJsonDecoderFixtures<T>(
  String description, {
  required FutureOr<T> Function(Map<String, dynamic>) decode,
  required Iterable<DecoderFixture> fixtures,
}) {
  group(description, () {
    for (final fixture in fixtures) {
      final error = fixture._error;
      if (error != null) {
        final encoded = jsonEncode(fixture.json);
        group(fixture.name, () {
          test('rejects the original fixture', () async {
            final input = jsonDecode(encoded) as Map<String, dynamic>;
            await expectLater(() => decode(input), throwsA(error));
          });
        });
        continue;
      }
      testJsonDecoder<T>(
        fixture.name,
        fixture: fixture.json,
        decode: decode,
        cases: fixture.cases,
        baseline: fixture.expected,
      );
    }
  });
}

/// Registers a baseline test and one isolated test per case.
///
/// [fixture] must be JSON-encodable. It is snapshotted when tests are
/// registered and decoded into a fresh copy for each test.
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
