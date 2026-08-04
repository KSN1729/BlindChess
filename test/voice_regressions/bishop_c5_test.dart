import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test('regression: bishop c5 resolves to bishop c5', () {
    final legalMoves = [
      {'from': 'f8', 'to': 'c5', 'piece': 'b', 'san': 'Bc5'},
      {'from': 'c1', 'to': 'd2', 'piece': 'b', 'san': 'Bd2'},
    ];

    final result = VoiceCommandParser.parseCommand('bishop c5', legalMoves);
    expect(result, isNotNull);
    expect(result!['to'], equals('c5'));
    expect(result['piece'], equals('b'));
  });
}
