import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test(
    'regression: rook noise (ruk) is resolved and executed if a rook move exists',
    () {
      final legalMoves = [
        {'from': 'a6', 'to': 'b6', 'piece': 'r', 'san': 'Rab6'},
      ];

      final result = VoiceCommandParser.parseCommand('ruk b6', legalMoves);
      expect(result, isNotNull);
      expect(result!.containsKey('error'), isFalse);
      expect(result['san'], equals('Rab6'));
    },
  );

  test(
    'regression: mismatch piece triggers did you mean clarification if spoken piece cannot reach target but another can',
    () {
      final legalMoves = [
        {'from': 'a6', 'to': 'b6', 'piece': 'r', 'san': 'Rab6'},
      ];

      final result = VoiceCommandParser.parseCommand('bishop b6', legalMoves);
      expect(result, isNotNull);
      expect(result!.containsKey('error'), isTrue);
      expect(
        result['error'],
        contains(
          "I heard 'bishop' but that can't reach b6. Did you mean rook to b6?",
        ),
      );
    },
  );
}
