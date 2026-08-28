import 'package:app_academia/features/ai_coach/domain/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseChatReply', () {
    test('extracts the reply string', () {
      expect(
        parseChatReply({'reply': 'Beba mais água hoje.'}),
        'Beba mais água hoje.',
      );
    });

    test('throws FormatException when reply is missing', () {
      expect(() => parseChatReply({}), throwsFormatException);
    });

    test('throws FormatException when reply is empty', () {
      expect(() => parseChatReply({'reply': '   '}), throwsFormatException);
    });

    test('throws FormatException when reply is not a string', () {
      expect(() => parseChatReply({'reply': 42}), throwsFormatException);
    });
  });
}
