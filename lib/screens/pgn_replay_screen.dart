// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import '../models/lichess_game.dart';
import '../services/lichess_service.dart';
import '../services/chess_engine_service.dart';
import '../widgets/chess_board.dart';

/// Screen to step through and visually replay a past Lichess game.
class PgnReplayScreen extends StatefulWidget {
  final LichessGame game;

  const PgnReplayScreen({super.key, required this.game});

  @override
  State<PgnReplayScreen> createState() => _PgnReplayScreenState();
}

class _PgnReplayScreenState extends State<PgnReplayScreen> {
  bool _isLoading = true;
  String? _error;

  /// Holds the list of FEN strings representing the position at each index.
  /// Index 0 is the initial start layout (move index = -1).
  final List<String> _fens = [];

  /// Holds details for last-move highlighting.
  /// Index 0 corresponds to move 1 (move index = 0), which has no preceding move to highlight.
  final List<((int, int), (int, int))?> _moveCoords = [];

  List<String> _sanMoves = [];
  int _currentMoveIndex = -1; // -1 means starting position
  bool _isWhitePerspective = true;

  @override
  void initState() {
    super.initState();
    _loadAndPreparePgn();
  }

  /// Cleans the PGN and caches board FEN states for quick manual stepping.
  Future<void> _loadAndPreparePgn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? pgn = widget.game.pgn;
      if (pgn == null) {
        try {
          pgn = await LichessService.instance.fetchGamePgn(widget.game.id);
          widget.game.pgn = pgn; // Cache back in the model
        } catch (fetchErr) {
          if (mounted) {
            setState(() {
              _error = fetchErr.toString();
              _isLoading = false;
            });
          }
          return;
        }
      }

      try {
        _parsePgn(pgn);
      } catch (parseErr) {
        if (mounted) {
          setState(() {
            _error = 'This game variant is not supported for replay.';
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An unexpected error occurred.';
          _isLoading = false;
        });
      }
    }
  }

  /// Cleans Lichess PGN and parses moves utilizing the chess.dart library capabilities.
  void _parsePgn(String rawPgn) {
    // -------------------------------------------------------------------------
    // BEGINNER EXPLANATION: Comments and clock annotations inside curly braces
    // -------------------------------------------------------------------------
    // Lichess PGN exports contain inline evaluations and clock comments inside curly
    // braces, e.g., "1. e4 { [%clk 0:03:00] } 1... e5 { [%clk 0:02:59] }".
    // Some simpler engine PGN parsers will fail or halt when encountering these braces.
    // We defensively strip these comments via RegExp before loading the PGN.
    // Print the exact raw PGN string to the console before cleaning/parsing
    print('--- RAW LICHESS PGN START ---');
    print(rawPgn);
    print('--- RAW LICHESS PGN END ---');

    final commentStripped = rawPgn.replaceAll(
      RegExp(r'\{[^}]*\}', multiLine: true, dotAll: true),
      '',
    );

    final lines = commentStripped.split(RegExp(r'\r?\n'));
    final normalizedLines = <String>[];
    for (var line in lines) {
      final trimmed = line.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
      if (trimmed.isNotEmpty) {
        normalizedLines.add(trimmed);
      }
    }
    final cleaned = normalizedLines.join('\n');

    print('--- CLEANED LICHESS PGN START ---');
    print(cleaned);
    print('--- CLEANED LICHESS PGN END ---');

    final tempChess = chess.Chess();
    if (!tempChess.load_pgn(cleaned)) {
      throw Exception(
        'Lichess PGN parsing failed. The PGN content is invalid or malformed.',
      );
    }

    _sanMoves = List<String>.from(tempChess.getHistory());
    final verboseHistory = tempChess.getHistory({'verbose': true});

    // Step through the game to cache FENs and move coordinates
    final stepChess = chess.Chess();
    _fens.clear();
    _moveCoords.clear();

    _fens.add(
      stepChess.fen,
    ); // Initial position (Index 0 in _fens -> Move index -1)
    _moveCoords.add(null); // No move highlights for starting position

    for (final move in verboseHistory) {
      if (move is Map) {
        final fromStr = move['from'] as String?;
        final toStr = move['to'] as String?;

        if (fromStr != null && toStr != null) {
          _moveCoords.add((_squareToCoords(fromStr), _squareToCoords(toStr)));
        } else {
          _moveCoords.add(null);
        }
      } else {
        _moveCoords.add(null);
      }

      stepChess.move(move);
      _fens.add(stepChess.fen);
    }
  }

  /// Maps algebraic coordinates (e.g. "e2") to grid row/column coordinate pairs.
  (int row, int col) _squareToCoords(String square) {
    final file = square[0];
    final rank = int.parse(square[1]);
    final col = file.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - rank;
    return (row, col);
  }

  /// Returns the current ChessEngineService adapter state configured with the current FEN.
  ChessEngineService _getCurrentEngineService() {
    final service = ChessEngineService();
    // Move index -1 maps to _fens[0]
    final fen = _fens[_currentMoveIndex + 1];
    service.load(fen);
    return service;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PGN Replay'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'Flip Board',
            onPressed: () {
              setState(() {
                _isWhitePerspective = !_isWhitePerspective;
              });
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load replay:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAndPreparePgn,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentEngine = _getCurrentEngineService();

    // Determine check highlight on replayer
    (int row, int col)? checkedKingCoords;
    if (currentEngine.inCheck) {
      checkedKingCoords = currentEngine.findKing(currentEngine.activeTurn);
    }

    // Determine last move highlight coordinates
    final lastMove = _moveCoords[_currentMoveIndex + 1];
    final lastMoveStart = lastMove?.$1;
    final lastMoveEnd = lastMove?.$2;

    // Get current move textual notation
    String moveIndicator = 'Starting Position';
    if (_currentMoveIndex >= 0) {
      final fullMoveNo = (_currentMoveIndex ~/ 2) + 1;
      final side = (_currentMoveIndex % 2 == 0) ? 'White' : 'Black';
      moveIndicator =
          'Move $fullMoveNo ($side: ${_sanMoves[_currentMoveIndex]})';
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Player header block
          Text(
            'vs. ${widget.game.opponentUsername}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Played as ${widget.game.colorPlayed}  |  Outcome: ${widget.game.result}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            '$moveIndicator  |  Total: ${_sanMoves.length} half-moves',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 20),

          // Decoupled board rendered in strictly read-only mode
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ChessBoard(
              chessEngineService: currentEngine,
              isWhitePerspective: _isWhitePerspective,
              shouldHidePieces: false,
              highlightedSquares: const [],
              lastMoveStart: lastMoveStart,
              lastMoveEnd: lastMoveEnd,
              checkedKingCoords: checkedKingCoords,
              readOnly: true, // Guarantees tap behaviors are disabled
            ),
          ),

          const SizedBox(height: 24),

          // Playback control row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                iconSize: 36,
                tooltip: 'First Move',
                onPressed: _currentMoveIndex <= -1
                    ? null
                    : () {
                        setState(() {
                          _currentMoveIndex = -1;
                        });
                      },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                iconSize: 36,
                tooltip: 'Previous',
                onPressed: _currentMoveIndex <= -1
                    ? null
                    : () {
                        setState(() {
                          _currentMoveIndex--;
                        });
                      },
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                iconSize: 36,
                tooltip: 'Next',
                onPressed: _currentMoveIndex >= _sanMoves.length - 1
                    ? null
                    : () {
                        setState(() {
                          _currentMoveIndex++;
                        });
                      },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.last_page),
                iconSize: 36,
                tooltip: 'Last Move',
                onPressed: _currentMoveIndex >= _sanMoves.length - 1
                    ? null
                    : () {
                        setState(() {
                          _currentMoveIndex = _sanMoves.length - 1;
                        });
                      },
              ),
            ],
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}
