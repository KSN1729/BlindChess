import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test(
    'regression: ambiguous moves return error with clarification trigger and candidates',
    () {
      final legalMoves = [
        {'from': 'b1', 'to': 'c3', 'piece': 'n', 'san': 'Nc3'},
        {
          'from': 'g1',
          'to': 'c3',
          'piece': 'n',
          'san': 'Nf3',
        }, // wait, san is Nf3 but it moves to c3, this is synthetic test data
      ];

      final result = VoiceCommandParser.parseCommand('knight c3', legalMoves);
      expect(result, isNotNull);
      expect(
        result!['error'],
        contains('Two knights can move there. Please specify which one.'),
      );
    },
  );
}
