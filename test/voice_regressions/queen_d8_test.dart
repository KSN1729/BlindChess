import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test('regression: queen d8 resolves to queen d8', () {
    final legalMoves = [
      {'from': 'd1', 'to': 'd8', 'piece': 'q', 'san': 'Qd8'},
      {'from': 'e1', 'to': 'd1', 'piece': 'k', 'san': 'Kd1'},
    ];

    final result = VoiceCommandParser.parseCommand('queen d8', legalMoves);
    expect(result, isNotNull);
    expect(result!['to'], equals('d8'));
    expect(result['piece'], equals('q'));
  });
}
