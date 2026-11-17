# json_decoder_test

Run your real `fromJson` decoder against deliberate changes to a known-good
JSON fixture. Each case reports the field path and change in its test name.

Requires Dart 3.6.2 or later in the 3.x series. Flutter 3.27.4 includes Dart
3.6.2.

## Installation

Add the package as a dev dependency with `dart pub add --dev json_decoder_test`
or `flutter pub add --dev json_decoder_test`. To try an unpublished checkout,
use a path dependency pointing to the checkout.

Declare `test` as a dev dependency in Dart projects that import it directly.
In Flutter projects, declare `flutter_test` as a dev dependency from the Flutter SDK.

## Usage

Import `package:json_decoder_test/json_decoder_test.dart` and either
`package:test/test.dart` (Dart) or
`package:flutter_test/flutter_test.dart` (Flutter). Register cases in
`main()` or inside a test group.

```dart
testJsonDecoder(
  'User.fromJson',
  fixture: {'id': 42, 'status': 'active'},
  decode: User.fromJson,
  cases: [
    ...DecoderCase.rejectsMissingOrNull(['id'], isA<TypeError>()),
    DecoderCase.rejects(JsonMutation.replace(['id'], '42'), isA<TypeError>()),
    DecoderCase.decodes(
      JsonMutation.replace(['status'], 'paused'),
      isA<User>().having((user) => user.status, 'status', Status.unknown),
    ),
  ],
);
```

Pass string keys and zero-based array indices to address nested values, for
example `['orders', 0, 'status']`. Targets must exist in the original fixture.
An invalid target fails the case before the decoder runs. Fixtures and
replacement values must be JSON-encodable.
Each case gets its own copy, so mutations and decoder writes do not leak
between tests. The original fixture also gets a baseline test. The decoder
can return a value or a future. Supply an exception matcher for a rejection,
or an expected value or matcher for a successful decode.

### Test required fields and enum fallbacks

For a required field, test missing keys, explicit `null`, and values of the
wrong type as separate cases. `DecoderCase.rejectsMissingOrNull` creates the
first two cases. Pass `nullError:` when the decoder reports explicit null
with a different exception. For an optional enum, use a known value in the
baseline and test an unrecognized value and explicit `null` separately. For
example, a mission source decoder might map an unrecognized source code to
`SourceType.unknown` and preserve `null` when the API sends no source type.
Use a matcher that checks the decoded field to verify both outcomes.

### Run the same decoder against named fixtures

```dart
testJsonDecoderFixtures(
  'User.fromJson across API payloads',
  decode: User.fromJson,
  fixtures: [
    DecoderFixture(
      'current payload',
      json: {'id': 42, 'status': 'active'},
      expected: isA<User>().having((user) => user.status, 'status', Status.active),
    ),
    DecoderFixture(
      'unrecognized status',
      json: {'id': 42, 'status': 'paused'},
      expected: isA<User>().having((user) => user.status, 'status', Status.unknown),
    ),
  ],
);
```

Each original payload must decode successfully. The optional `expected`
matcher checks its decoded result, and `cases` adds mutations specific to that
fixture. Test names include the decoder description and fixture name.

The [complete example](example/json_decoder_test_example.dart) includes the
`User` model, imports, and test entry point. From this checkout, run it with
`dart test example/json_decoder_test_example.dart`.
