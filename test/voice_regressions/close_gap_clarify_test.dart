import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test(
    'regression: close gap case triggers clarification instead of auto-executing',
    () {
      final legalMoves = [
        {'from': 'g1', 'to': 'f3', 'piece': 'n', 'san': 'Nf3'},
        {'from': 'd1', 'to': 'f3', 'piece': 'q', 'san': 'Qf3'},
      ];

      final result = VoiceCommandParser.parseCommand('f3', legalMoves);
      expect(result, isNotNull);
      expect(result!.containsKey('error'), isTrue);
      expect(
        result['error'],
        contains('Ambiguous voice command. Candidates: Nf3, Qf3'),
      );
    },
  );
}
