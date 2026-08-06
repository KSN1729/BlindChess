import 'package:chess/chess.dart' as chess;

void main() {
  final game = chess.Chess();
  game.move('e4');
  game.move('e5');
  game.move('Nf3');
  game.move('Nc6');
  
  print('=== HISTORY ===');
  print(game.getHistory());
  
  print('=== PGN EXPORT ATTEMPT ===');
  try {
    // Let's print the methods/properties or try to see if there is a pgn() method
    // In many chess libraries, game.pgn() exports the PGN string.
    // Let's try calling it.
    print(game.pgn());
  } catch (e) {
    print('Failed calling game.pgn(): $e');
  }

  print('=== MANUAL PGN GENERATION ===');
  // If game.pgn() doesn't exist, we can easily generate a clean standard PGN 
  // ourselves from the history! 
  // Standard PGN looks like:
  // [Event "Local Game"]
  // [Site "BlindChess App"]
  // [Date "2026.08.05"]
  // [Round "1"]
  // [White "Player 1"]
  // [Black "Player 2"]
  // [Result "*"]
  //
  // 1. e4 e5 2. Nf3 Nc6 ...
}
