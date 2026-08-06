import 'package:chess/chess.dart' as chess;

/// Utility class to parse, validate, import, and export chess matches in PGN format.
class PgnProcessor {
  /// Exports played moves into standard algebraic PGN notation format.
  static String exportPgn({
    required List<String> sanHistory,
    String? result,
    String? whitePlayer,
    String? blackPlayer,
    String? date,
  }) {
    final buffer = StringBuffer();
    final eventName = 'Local Game';
    final dateStr = date ?? _getTodayPgnDate();
    final res = result ?? '*';
    final wName = whitePlayer ?? 'White';
    final bName = blackPlayer ?? 'Black';

    buffer.writeln('[Event "$eventName"]');
    buffer.writeln('[Site "BlindChess App"]');
    buffer.writeln('[Date "$dateStr"]');
    buffer.writeln('[Round "1"]');
    buffer.writeln('[White "$wName"]');
    buffer.writeln('[Black "$bName"]');
    buffer.writeln('[Result "$res"]');
    buffer.writeln();

    // Generate standard moves numbering sequence (1. e4 e5 2. Nf3 Nc6)
    for (int i = 0; i < sanHistory.length; i += 2) {
      final moveNum = (i ~/ 2) + 1;
      buffer.write('$moveNum. ${sanHistory[i]}');
      if (i + 1 < sanHistory.length) {
        buffer.write(' ${sanHistory[i + 1]} ');
      }
    }

    if (sanHistory.isNotEmpty && !buffer.toString().endsWith(' ')) {
      buffer.write(' ');
    }
    buffer.write(res);

    return buffer.toString();
  }

  /// Validates a PGN string. If valid, returns the list of SAN moves, UCI moves and the final FEN.
  /// If invalid, returns null.
  static Map<String, dynamic>? importAndValidatePgn(String rawPgn) {
    try {
      // Clean comment braces e.g. evaluations or clocks
      final commentStripped = rawPgn.replaceAll(
        RegExp(r'\{[^}]*\}', multiLine: true, dotAll: true),
        '',
      );

      final tempChess = chess.Chess();
      if (!tempChess.load_pgn(commentStripped)) {
        return null;
      }

      final List<String> sanMoves = List<String>.from(tempChess.getHistory());
      final List<String> uciMoves = [];

      final verboseHistory = tempChess.getHistory({'verbose': true});
      for (final m in verboseHistory) {
        if (m is Map) {
          final from = m['from'] as String? ?? '';
          final to = m['to'] as String? ?? '';
          final promo = m['promotion'] as String? ?? '';
          uciMoves.add('$from$to$promo');
        }
      }

      return {
        'sanMoves': sanMoves,
        'uciMoves': uciMoves,
        'finalFen': tempChess.fen,
      };
    } catch (e) {
      return null;
    }
  }

  static String _getTodayPgnDate() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }
}
