import 'package:json_decoder_test/json_decoder_test.dart';
import 'package:test/test.dart';

enum Status { active, unknown }

final class User {
  User(this.id, this.status);

  factory User.fromJson(Map<String, dynamic> json) => User(
        json['id'] as int,
        json['status'] == 'active' ? Status.active : Status.unknown,
      );

  final int id;
  final Status status;
}

void main() {
  final userWithUnknownStatus = isA<User>().having(
    (user) => user.status,
    'status',
    Status.unknown,
  );

  testJsonDecoder(
    'User.fromJson',
    fixture: {'id': 42, 'status': 'active'},
    decode: User.fromJson,
    cases: [
      DecoderCase.decodes(
        JsonMutation.sequence([
          JsonMutation.replace(['id'], 7),
          JsonMutation.replace(['status'], 'paused'),
        ]),
        isA<User>()
            .having((user) => user.id, 'id', 7)
            .having((user) => user.status, 'status', Status.unknown),
      ),
      DecoderCase.rejects(
        JsonMutation.sequence([
          JsonMutation.add(['server_metadata'], {'revision': 2}),
          JsonMutation.replace(['id'], 'invalid'),
        ]),
        isA<TypeError>(),
      ),
      DecoderCase.decodes(
        JsonMutation.add(['server_metadata'], {'revision': 2}),
        isA<User>().having((user) => user.id, 'id', 42),
      ),
      ...DecoderCase.rejectsMissingOrNull(['id'], isA<TypeError>()),
      DecoderCase.rejects(JsonMutation.replace(['id'], '42'), isA<TypeError>()),
      DecoderCase.decodes(
        JsonMutation.replace(['status'], 'paused'),
        userWithUnknownStatus,
      ),
    ],
  );

  testJsonDecoderFixtures(
    'User.fromJson across API payloads',
    decode: User.fromJson,
    fixtures: [
      DecoderFixture.rejects(
        'missing required id',
        json: {'status': 'active'},
        error: isA<TypeError>(),
      ),
      DecoderFixture(
        'current payload',
        json: {'id': 42, 'status': 'active'},
        expected: isA<User>().having(
          (user) => user.status,
          'status',
          Status.active,
        ),
      ),
      DecoderFixture(
        'unrecognized status',
        json: {'id': 42, 'status': 'paused'},
        expected: userWithUnknownStatus,
      ),
    ],
  );
}
