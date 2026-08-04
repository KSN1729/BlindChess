import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test('regression: knight b f3 resolves to knight b f3', () {
    final legalMoves = [
      {'from': 'b1', 'to': 'f3', 'piece': 'n', 'san': 'Nbf3'},
      {'from': 'g1', 'to': 'f3', 'piece': 'n', 'san': 'Ngf3'},
    ];

    final result = VoiceCommandParser.parseCommand('knight b f3', legalMoves);
    expect(result, isNotNull);
    expect(result!['to'], equals('f3'));
    expect(result['from'], equals('b1'));
    expect(result['piece'], equals('n'));
  });
}
