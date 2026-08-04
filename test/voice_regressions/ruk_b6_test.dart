import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test('regression: ruk b6 resolves to rook b6', () {
    final legalMoves = [
      {'from': 'a6', 'to': 'b6', 'piece': 'r', 'san': 'Rab6'},
      {'from': 'b1', 'to': 'b2', 'piece': 'r', 'san': 'Rb2'},
    ];

    final result = VoiceCommandParser.parseCommand('ruk b6', legalMoves);
    expect(result, isNotNull);
    expect(result!['to'], equals('b6'));
    expect(result['piece'], equals('r'));
  });
}
