## 0.5.0

- Add `JsonMutation.add` to test missing object keys such as new server fields.
- Support existing nested objects and objects inside arrays without overwriting
  fields, creating parents or inserting array elements.
- Snapshot added values and isolate them between cases, including async decoders.
- Reject invalid add targets before invoking the decoder.
- Keep existing mutation APIs, SDK constraints and dependencies unchanged.

## 0.4.0

- Add `DecoderFixture.rejects` for named payloads expected to throw a
  matching error, including asynchronous decoders.

## 0.3.0

- Add `testJsonDecoderFixtures` and `DecoderFixture` to run a decoder against
  named payloads with individual baseline matchers and mutation cases.

## 0.2.0

- Add `DecoderCase.rejectsMissingOrNull` to register separate cases for a
  missing field and explicit null, with an optional matcher for the null case.

## 0.1.1

- Use `test_api` and `matcher` directly so Flutter consumers can use
  `flutter_test` alongside code generators that require an older analyzer.

## 0.1.0

- Register decoder tests from one JSON fixture and explicit field mutations.
- Check decoded values and expected exceptions with package:test matchers.
- Support synchronous and asynchronous decoders.
