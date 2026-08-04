import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test('regression: night e8 resolves to knight e8', () {
    final legalMoves = [
      {'from': 'f6', 'to': 'e8', 'piece': 'n', 'san': 'Ne8'},
      {'from': 'd7', 'to': 'f6', 'piece': 'n', 'san': 'Nf6'},
    ];

    final result = VoiceCommandParser.parseCommand('night e8', legalMoves);
    expect(result, isNotNull);
    expect(result!['to'], equals('e8'));
    expect(result['piece'], equals('n'));
  });
}
