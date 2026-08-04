import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test(
    'regression: rock b6 is executed when rook and bishop can move to b6 and gap is large',
    () {
      final legalMoves = [
        {'from': 'a6', 'to': 'b6', 'piece': 'r', 'san': 'Rab6'},
        {'from': 'c5', 'to': 'b6', 'piece': 'b', 'san': 'Bcb6'},
      ];

      final result = VoiceCommandParser.parseCommand('rock b6', legalMoves);
      expect(result, isNotNull);
      expect(result!.containsKey('error'), isFalse);
      expect(result['san'], equals('Rab6'));
    },
  );
}
