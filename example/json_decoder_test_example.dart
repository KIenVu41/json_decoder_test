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
      DecoderCase.rejects(JsonMutation.remove(['id']), isA<TypeError>()),
      DecoderCase.rejects(JsonMutation.replace(['id'], null), isA<TypeError>()),
      DecoderCase.rejects(JsonMutation.replace(['id'], '42'), isA<TypeError>()),
      DecoderCase.decodes(
        JsonMutation.replace(['status'], 'paused'),
        userWithUnknownStatus,
      ),
    ],
  );
}
