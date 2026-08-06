import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/chess_board.dart';
import '../models/chess_piece.dart';
import '../models/game_result.dart';
import '../models/chess_clock_config.dart';
import '../services/chess_engine_service.dart';
import '../services/statistics_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/diagnostic_recorder.dart';
import '../widgets/voice_command_widget.dart';
import '../services/voice_pipeline_service.dart';
import '../services/accessibility_settings_service.dart';
import '../services/tts_service.dart';
import '../services/haptic_service.dart';
import '../utils/chess_speech_synthesizer.dart';
import '../utils/pgn_processor.dart';
import '../services/chess_clock_service.dart';
import '../services/game_persistence_service.dart';
import 'stats_screen.dart';

/// Primary game mode screen for pass-and-play matches.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> implements VoicePipelineDelegate {
  // List of files (columns) from A to H to map files to indices.
  final files = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  /// [Boolean variables]
  /// A boolean is a primitive data type that holds one of two possible values: `true` or `false`.
  /// Here, `isWhitePerspective` keeps track of the active board view orientation.
  bool isWhitePerspective = true;

  /// A mutable state variable that holds the coordinate label of the currently selected chess square (e.g., "E4").
  /// It is initialized to `null` to represent that no square is selected initially (which prints "None").
  String? selectedSquare;

  // Selected row and column coordinates tracking to handle move origin.
  int? selectedRow;
  int? selectedCol;

  // Last move source and destination coordinates to display visual highlights.
  (int row, int col)? lastMoveStart;
  (int row, int col)? lastMoveEnd;

  // History tracking variables for Undo/Redo & Jump-to-Move
  List<String> uciMoves = [];
  List<String> sanMoves = [];
  int currentMoveIndex = -1; // -1 means start position

  // Clock variables
  late final ChessClockService _clockService;

  /// [highlightedSquares variable]
  /// Holds the 0-indexed row/column coordinates of all legal destination squares for the currently selected piece.
  /// Standard records (int, int) are used to represent coordinates cleanly.
  List<(int row, int col)> highlightedSquares = const [];
  Map<String, dynamic>? pendingMoveForClarification;
  DateTime? lastMoveTime;
  bool pendingUndoConfirmation = false;

  /// [ChessEngineService instance]
  /// We instantiate our new rules engine adapter service. It now serves as the single source
  /// of truth for piece layout, legal move calculations, and game rules.
  final ChessEngineService chessEngineService = ChessEngineService();

  // Blindfold Mode active state variable.
  bool isBlindfoldMode = false;

  // Keeps track of the total move count at the moment Blindfold Mode was toggled on.
  int _blindfoldToggleMoveCount = 0;

  // Preserves selected difficulty level across resets (default is Medium).
  BlindfoldDifficulty selectedDifficulty = BlindfoldDifficulty.medium;

  // Memory Score counters
  int totalGuesses = 0;
  int correctGuesses = 0;

  // Reveal state variables
  bool _isRevealed = false;
  int? _revealLastUsedMoveCount;
  Timer? _revealTimer;

  // Map of active overlays for correct/incorrect guesses
  final Map<(int, int), String> _flashStates = {};

  // Prevents recording the outcome of a single completed game multiple times
  bool _isGameStatsRecorded = false;

  void _handleTimeout() {
    final loser = _clockService.whiteTimeMs <= 0 ? PieceColor.white : PieceColor.black;
    final winner = loser == PieceColor.white ? PieceColor.black : PieceColor.white;
    final winnerStr = winner == PieceColor.white ? 'White' : 'Black';

    // Announce timeout using existing accessibility system
    TtsService.instance.speak('$winnerStr wins on time.', priority: AnnouncementPriority.high);
    AudioService.instance.playGameOver();
    HapticService.triggerGameOver();

    final result = GameResult(
      type: ResultType.timeout,
      winnerColor: winner,
      description: 'Timeout — $winnerStr wins.',
    );

    _saveCurrentGameSession(result: result);
    _showGameResultDialog(result);
  }

  void _applyClockConfig(ChessClockConfig config) {
    setState(() {
      _clockService.initialize(
        config: config,
        activeTurn: chessEngineService.activeTurn,
        onTimeout: _handleTimeout,
      );
      _saveCurrentGameSession();
    });
  }

  void _onMoveExecuted(String fromSquare, String toSquare, String? promotion, Map<String, dynamic>? executedMove) {
    setState(() {
      // Truncate history if browsing
      if (currentMoveIndex < uciMoves.length - 1) {
        uciMoves.removeRange(currentMoveIndex + 1, uciMoves.length);
        sanMoves.removeRange(currentMoveIndex + 1, sanMoves.length);
      }

      final promoStr = promotion != null ? promotion.toLowerCase() : '';
      final uci = '$fromSquare$toSquare$promoStr';
      uciMoves.add(uci);

      final lastSan = chessEngineService.getHistory().last.toString();
      sanMoves.add(lastSan);
      currentMoveIndex = uciMoves.length - 1;

      // Update coordinates
      lastMoveStart = _squareToCoords(fromSquare);
      lastMoveEnd = _squareToCoords(toSquare);
      lastMoveTime = DateTime.now();

      // Clear selection
      selectedSquare = null;
      selectedRow = null;
      selectedCol = null;
      highlightedSquares = const [];

      // Clock logic: add increment to the player who just moved
      if (_clockService.config.hasTimer) {
        _clockService.setActiveTurn(chessEngineService.activeTurn);
        _clockService.applyMoveIncrement();
        _clockService.start();
      }

      // Check result / status
      checkGameStatus();

      // Auto-save game session
      _saveCurrentGameSession();
    });
  }

  void _performUndo() {
    if (currentMoveIndex >= 0) {
      _jumpToMoveIndex(currentMoveIndex - 1);
      TtsService.instance.speak('Undo.', priority: AnnouncementPriority.normal);
      _saveCurrentGameSession();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Move undone.'), duration: Duration(seconds: 2)),
      );
    }
  }

  void _performRedo() {
    if (currentMoveIndex < uciMoves.length - 1) {
      _jumpToMoveIndex(currentMoveIndex + 1);
      final redoneMoveSan = sanMoves[currentMoveIndex];
      TtsService.instance.speak('Redo $redoneMoveSan.', priority: AnnouncementPriority.normal);
      _saveCurrentGameSession();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redo: $redoneMoveSan'), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _jumpToMoveIndex(int index) {
    setState(() {
      currentMoveIndex = index;

      // Load initial position
      chessEngineService.reset();

      // Re-apply moves up to index
      for (int i = 0; i <= index; i++) {
        chessEngineService.makeUciMove(uciMoves[i]);
      }

      // Clear current highlight selection
      selectedSquare = null;
      selectedRow = null;
      selectedCol = null;
      highlightedSquares = const [];

      // Update last-move highlights based on the selected move
      if (index >= 0 && index < uciMoves.length) {
        final uci = uciMoves[index];
        lastMoveStart = _squareToCoords(uci.substring(0, 2));
        lastMoveEnd = _squareToCoords(uci.substring(2, 4));
      } else {
        lastMoveStart = null;
        lastMoveEnd = null;
      }

      // If autoRotate is enabled, adjust the board perspective
      if (SettingsService.instance.autoRotate) {
        isWhitePerspective = (chessEngineService.activeTurn == PieceColor.white);
      }
      _clockService.setActiveTurn(chessEngineService.activeTurn);
      if (isGameOver) {
        _clockService.stop();
      }
    });
  }

  (int row, int col) _squareToCoords(String square) {
    final file = square[0];
    final rank = int.parse(square[1]);
    final col = file.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - rank;
    return (row, col);
  }

  @override
  void initState() {
    super.initState();
    isBlindfoldMode = SettingsService.instance.isBlindfoldMode;
    selectedDifficulty = SettingsService.instance.blindfoldDifficulty;
    VoicePipelineService.instance.setDelegate(this);
    _clockService = ChessClockService.instance;
    _clockService.addListener(_onClockTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndRestoreGame());
  }

  void _onClockTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    VoicePipelineService.instance.setDelegate(null);
    VoicePipelineService.instance.stopPipeline();
    _revealTimer?.cancel();
    _clockService.removeListener(_onClockTick);
    _clockService.stop();
    super.dispose();
  }

  /// Exposes if the game has reached an end state (checkmate, stalemate, draw, or timeout).
  bool get isGameOver {
    return chessEngineService.inCheckmate ||
        chessEngineService.inStalemate ||
        chessEngineService.inDraw ||
        (_clockService.config.hasTimer && (_clockService.whiteTimeMs <= 0 || _clockService.blackTimeMs <= 0));
  }

  /// Computes move threshold after which pieces hide dynamically based on selected difficulty.
  int get blindfoldMoveThreshold {
    switch (selectedDifficulty) {
      case BlindfoldDifficulty.easy:
        return 10;
      case BlindfoldDifficulty.medium:
        return 5;
      case BlindfoldDifficulty.hard:
        return 0;
    }
  }

  /// Getter that evaluates if the pieces would currently be hidden under Normal Blindfold rules.
  bool get isBlindfoldHidingActive {
    if (!isBlindfoldMode) return false;
    final currentMoves = chessEngineService.getHistory().length;
    return currentMoves >= (_blindfoldToggleMoveCount + blindfoldMoveThreshold);
  }

  /// Exposes whether pieces should actually be hidden visually at this moment.
  bool get shouldHidePieces {
    if (!isBlindfoldHidingActive) return false;
    return !_isRevealed;
  }

  /// Exposes remaining moves in the 10-move reveal cooldown.
  int get revealCooldownRemaining {
    if (_revealLastUsedMoveCount == null) return 0;
    final currentMoves = chessEngineService.getHistory().length;
    if (currentMoves < _revealLastUsedMoveCount!) {
      return 0;
    }
    final movesPlayedSince = currentMoves - _revealLastUsedMoveCount!;
    final remaining = 10 - movesPlayedSince;
    return remaining > 0 ? remaining : 0;
  }

  /// Determines if the Reveal button is interactive.
  bool get canReveal {
    return shouldHidePieces && revealCooldownRemaining == 0;
  }

  /// Computed label showing current reveal button state.
  String get revealButtonLabel {
    final remaining = revealCooldownRemaining;
    if (remaining > 0) {
      return 'Reveal ($remaining moves left)';
    }
    return 'Reveal Pieces';
  }

  void _toggleBlindfoldMode(bool value) {
    SettingsService.instance.setBlindfoldMode(value);
    setState(() {
      isBlindfoldMode = value;
      if (isBlindfoldMode) {
        _blindfoldToggleMoveCount = chessEngineService.getHistory().length;
      }
      totalGuesses = 0;
      correctGuesses = 0;
      _isRevealed = false;
      _revealLastUsedMoveCount = null;
      _revealTimer?.cancel();
    });
  }

  void _triggerFlash(int row, int col, String color) {
    setState(() {
      _flashStates[(row, col)] = color;
    });
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() {
          _flashStates.remove((row, col));
        });
      }
    });
  }

  void _revealPiecesTemporarily() {
    setState(() {
      _isRevealed = true;
      _revealLastUsedMoveCount = chessEngineService.getHistory().length;
    });
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isRevealed = false;
        });
      }
    });
  }

  /// Dynamically computes light/dark square colors based on Board Theme selection.
  Color getSquareColor(
    int rankIndex,
    int fileIndex,
    bool isHighlighted,
    bool isLastMove,
  ) {
    final isDark = (rankIndex + fileIndex) % 2 != 0;
    Color baseColor;

    switch (SettingsService.instance.boardTheme) {
      case 'classic_wood':
        baseColor = isDark ? const Color(0xFFB58863) : const Color(0xFFF0D9B5);
        break;
      case 'ocean_blue':
        baseColor = isDark ? const Color(0xFF0284C7) : const Color(0xFFE0F2FE);
        break;
      case 'slate_grey':
      default:
        baseColor = isDark ? const Color(0xFF475569) : const Color(0xFFF1F5F9);
        break;
    }

    // Blend last-move highlights (subtle yellow tint)
    if (isLastMove) {
      baseColor = Color.lerp(baseColor, Colors.yellow, 0.15) ?? baseColor;
    }

    // Blend legal-move highlights (green tint)
    if (isHighlighted) {
      baseColor = Color.lerp(baseColor, Colors.green, 0.3) ?? baseColor;
    }

    return baseColor;
  }

  void _confirmNewGame() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _startNewGameSetup();
      return;
    }
    if (uciMoves.isNotEmpty && !isGameOver) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New Game'),
          content: const Text('Are you sure you want to start a new game? Current game progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startNewGameSetup();
              },
              child: const Text('Yes'),
            ),
          ],
        ),
      );
    } else {
      _startNewGameSetup();
    }
  }

  void _confirmRestartGame() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _restartGameSetup();
      return;
    }
    if (uciMoves.isNotEmpty && !isGameOver) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restart Game'),
          content: const Text('Are you sure you want to restart this game? Current game progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _restartGameSetup();
              },
              child: const Text('Yes'),
            ),
          ],
        ),
      );
    } else {
      _restartGameSetup();
    }
  }

  void _startNewGameSetup() {
    setState(() {
      chessEngineService.reset();
      selectedSquare = null;
      selectedRow = null;
      selectedCol = null;
      lastMoveStart = null;
      lastMoveEnd = null;
      highlightedSquares = const [];
      _blindfoldToggleMoveCount = 0;
      totalGuesses = 0;
      correctGuesses = 0;
      _isRevealed = false;
      _revealLastUsedMoveCount = null;
      _revealTimer?.cancel();
      _isGameStatsRecorded = false;

      sanMoves.clear();
      uciMoves.clear();
      currentMoveIndex = -1;

      _applyClockConfig(_clockService.config);
    });

    TtsService.instance.speak('New game started.', priority: AnnouncementPriority.normal);
  }

  void _restartGameSetup() {
    setState(() {
      chessEngineService.reset();
      selectedSquare = null;
      selectedRow = null;
      selectedCol = null;
      lastMoveStart = null;
      lastMoveEnd = null;
      highlightedSquares = const [];
      _blindfoldToggleMoveCount = 0;
      totalGuesses = 0;
      correctGuesses = 0;
      _isRevealed = false;
      _revealLastUsedMoveCount = null;
      _revealTimer?.cancel();
      _isGameStatsRecorded = false;

      sanMoves.clear();
      uciMoves.clear();
      currentMoveIndex = -1;

      _applyClockConfig(_clockService.config);
    });

    TtsService.instance.speak('Game restarted.', priority: AnnouncementPriority.normal);
  }

  void _saveCurrentGameSession({GameResult? result}) {
    final isActive = uciMoves.isNotEmpty && !isGameOver && result == null;
    if (isActive) {
      GamePersistenceService.instance.saveGame(
        fen: chessEngineService.fen,
        uciMoves: uciMoves,
        sanMoves: sanMoves,
        whiteTimeMs: _clockService.whiteTimeMs,
        blackTimeMs: _clockService.blackTimeMs,
        clockLabel: _clockService.config.label,
        clockBaseSeconds: _clockService.config.baseSeconds,
        clockIncrementSeconds: _clockService.config.incrementSeconds,
        clockHasTimer: _clockService.config.hasTimer,
        currentMoveIndex: currentMoveIndex,
        gameActive: true,
      );
    } else {
      GamePersistenceService.instance.clearSavedGame();
    }
  }

  Future<void> _checkAndRestoreGame() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final saved = await GamePersistenceService.instance.restoreGame();
    if (saved != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Resume Game?'),
            content: const Text('An unfinished local game was found. Would you like to resume it?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  GamePersistenceService.instance.clearSavedGame();
                },
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _restoreSavedGameSetup(saved);
                },
                child: const Text('Resume'),
              ),
            ],
          );
        },
      );
    }
  }

  void _restoreSavedGameSetup(Map<String, dynamic> saved) {
    setState(() {
      sanMoves = List<String>.from(saved['sanMoves']);
      uciMoves = List<String>.from(saved['uciMoves']);
      currentMoveIndex = saved['currentMoveIndex'] as int;
      final label = saved['clockLabel'] as String;
      final base = saved['clockBaseSeconds'] as int;
      final inc = saved['clockIncrementSeconds'] as int;
      final hasTimer = saved['clockHasTimer'] as bool;

      final restoredConfig = ChessClockConfig(
        label: label,
        baseSeconds: base,
        incrementSeconds: inc,
        hasTimer: hasTimer,
      );

      _clockService.initialize(
        config: restoredConfig,
        whiteTimeMs: saved['whiteTimeMs'] as int,
        blackTimeMs: saved['blackTimeMs'] as int,
        activeTurn: chessEngineService.activeTurn,
        onTimeout: _handleTimeout,
      );

      chessEngineService.load(saved['fen'] as String);

      if (currentMoveIndex >= 0 && currentMoveIndex < uciMoves.length) {
        final lastUci = uciMoves[currentMoveIndex];
        lastMoveStart = _squareToCoords(lastUci.substring(0, 2));
        lastMoveEnd = _squareToCoords(lastUci.substring(2, 4));
      } else {
        lastMoveStart = null;
        lastMoveEnd = null;
      }

      if (_clockService.config.hasTimer && uciMoves.isNotEmpty && !isGameOver) {
        _clockService.start();
      }
    });

    TtsService.instance.speak('Resumed game. Position restored.', priority: AnnouncementPriority.normal);
  }

  void checkGameStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final isCheckmate = chessEngineService.inCheckmate;
      final isStalemate = chessEngineService.inStalemate;
      final isDraw = chessEngineService.inDraw;

      if (isCheckmate || isStalemate || isDraw) {
        if (!_isGameStatsRecorded) {
          _isGameStatsRecorded = true;
          _clockService.stop();

          String? winner;
          PieceColor? winnerColor;
          ResultType type = ResultType.drawAgreement;
          String desc = 'Draw.';

          if (isCheckmate) {
            final losingColor = chessEngineService.activeTurn;
            winner = (losingColor == PieceColor.white) ? 'black' : 'white';
            winnerColor = (losingColor == PieceColor.white) ? PieceColor.black : PieceColor.white;
            type = ResultType.checkmate;
            desc = 'Checkmate — ${winnerColor == PieceColor.white ? 'White' : 'Black'} wins.';
          } else if (isStalemate) {
            type = ResultType.stalemate;
            desc = 'Stalemate — Draw.';
          } else if (chessEngineService.inThreefoldRepetition) {
            type = ResultType.threefoldRepetition;
            desc = 'Draw by threefold repetition.';
          } else if (chessEngineService.insufficientMaterial) {
            type = ResultType.insufficientMaterial;
            desc = 'Draw by insufficient material.';
          } else if (isDraw) {
            type = ResultType.fiftyMoves;
            desc = 'Draw by fifty-move rule.';
          }

          final gameResult = GameResult(
            type: type,
            winnerColor: winnerColor,
            description: desc,
          );

          StatisticsService.instance.recordGame(
            isDraw: type != ResultType.checkmate && type != ResultType.timeout,
            winningColor: winner,
            isCheckmate: isCheckmate,
            halfMoves: uciMoves.length,
            isBlindfoldModeActive: isBlindfoldMode,
            memoryScorePercentage: isBlindfoldMode
                ? (totalGuesses > 0 ? (correctGuesses * 100 ~/ totalGuesses) : 0)
                : null,
          );

          _saveCurrentGameSession(result: gameResult);
          _showGameResultDialog(gameResult);
        }
      }
    });
  }

  void _showGameResultDialog(GameResult result) {
    String title = 'Game Over';
    if (result.type == ResultType.checkmate) {
      title = 'Checkmate';
    } else if (result.type == ResultType.stalemate) {
      title = 'Stalemate';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(result.description),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmNewGame();
              },
              child: const Text('New Game'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showPromotionDialog(PieceColor color) {
    final isWhite = color == PieceColor.white;
    final options = [
      (PieceType.queen, isWhite ? '♕' : '♛', 'q', 'Queen'),
      (PieceType.rook, isWhite ? '♖' : '♜', 'r', 'Rook'),
      (PieceType.bishop, isWhite ? '♗' : '♝', 'b', 'Bishop'),
      (PieceType.knight, isWhite ? '♘' : '♞', 'n', 'Knight'),
    ];

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Promote Pawn to:'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: options.map((opt) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(opt.$3);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(50, 50),
                    ),
                    child: Text(opt.$2, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(height: 4),
                  Text(opt.$4, style: const TextStyle(fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildClockWidget({required PieceColor color, required bool isTop}) {
    if (!_clockService.config.hasTimer) return const SizedBox.shrink();

    final bool isWhite = color == PieceColor.white;
    final int timeMs = isWhite ? _clockService.whiteTimeMs : _clockService.blackTimeMs;
    final bool isTurn = chessEngineService.activeTurn == color;

    final secondsTotal = (timeMs / 1000).ceil();
    final minutes = secondsTotal ~/ 60;
    final seconds = secondsTotal % 60;

    String timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    if (timeMs < 10000 && timeMs > 0) {
      final secondsFloat = timeMs / 1000.0;
      timeStr = secondsFloat.toStringAsFixed(1);
    } else if (timeMs <= 0) {
      timeStr = '0.0';
    }

    final Color clockColor = isTurn ? Colors.redAccent.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1);
    final Color textColor = isTurn ? Colors.red : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: clockColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isTurn ? Colors.red : Colors.grey.shade400, width: 2.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isWhite ? 'White' : 'Black',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showClockSelectorSheet() {
    if (uciMoves.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot change clock settings once the game has started.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Chess Clock Preset',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: ChessClockConfig.presets.map((preset) {
                    return ListTile(
                      title: Text(preset.label),
                      trailing: _clockService.config.label == preset.label ? const Icon(Icons.check, color: Colors.deepPurple) : null,
                      onTap: () {
                        Navigator.pop(context);
                        _applyClockConfig(preset);
                      },
                    );
                  }).toList() + [
                    ListTile(
                      title: const Text('Custom Time...'),
                      trailing: _clockService.config.label.startsWith('Custom') ? const Icon(Icons.check, color: Colors.deepPurple) : null,
                      onTap: () {
                        Navigator.pop(context);
                        _showCustomClockDialog();
                      },
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomClockDialog() {
    int minutes = 10;
    int increment = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Custom Chess Clock'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Base Minutes:'),
                      DropdownButton<int>(
                        value: minutes,
                        items: [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180].map((m) {
                          return DropdownMenuItem<int>(value: m, child: Text('$m min'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => minutes = val);
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Increment Seconds:'),
                      DropdownButton<int>(
                        value: increment,
                        items: [0, 1, 2, 3, 5, 10, 15, 30].map((s) {
                          return DropdownMenuItem<int>(value: s, child: Text('$s sec'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => increment = val);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final customPreset = ChessClockConfig(
                      label: 'Custom $minutes+$increment',
                      baseSeconds: minutes * 60,
                      incrementSeconds: increment,
                    );
                    _applyClockConfig(customPreset);
                  },
                  child: const Text('Set'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPgnOptionsDialog() {
    final exportController = TextEditingController(text: PgnProcessor.exportPgn(sanHistory: sanMoves));
    final importController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('PGN Options'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Export PGN:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: exportController,
                  readOnly: true,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    helperText: 'Copy this text to share your game.',
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: exportController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PGN copied to clipboard.')),
                        );
                      },
                      child: const Text('Copy PGN'),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Import PGN:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: importController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Paste PGN text here...',
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        final pgn = importController.text.trim();
                        if (pgn.isEmpty) return;

                        final parsed = PgnProcessor.importAndValidatePgn(pgn);
                        if (parsed != null) {
                          Navigator.pop(context);
                          setState(() {
                            sanMoves = parsed['sanMoves'] as List<String>;
                            uciMoves = parsed['uciMoves'] as List<String>;
                            currentMoveIndex = uciMoves.length - 1;

                            chessEngineService.load(parsed['finalFen'] as String);

                            if (uciMoves.isNotEmpty) {
                              final latestUci = uciMoves.last;
                              lastMoveStart = _squareToCoords(latestUci.substring(0, 2));
                              lastMoveEnd = _squareToCoords(latestUci.substring(2, 4));
                            } else {
                              lastMoveStart = null;
                              lastMoveEnd = null;
                            }

                            selectedSquare = null;
                            selectedRow = null;
                            selectedCol = null;
                            highlightedSquares = const [];

                            _applyClockConfig(_clockService.config);
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Game state imported successfully.')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid or unsupported PGN format.')),
                          );
                        }
                      },
                      child: const Text('Import PGN'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoveHistorySection() {
    final List<String> formatted = [];
    for (int i = 0; i < sanMoves.length; i += 2) {
      final moveNumber = (i ~/ 2) + 1;
      final whiteMove = sanMoves[i];
      final blackMove = (i + 1 < sanMoves.length) ? sanMoves[i + 1] : '';
      if (blackMove.isNotEmpty) {
        formatted.add('$moveNumber. $whiteMove $blackMove');
      } else {
        formatted.add('$moveNumber. $whiteMove');
      }
    }

    if (formatted.isEmpty) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: Text(
            'No moves played yet.',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    final ScrollController scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: formatted.length,
        itemBuilder: (context, index) {
          final turnString = formatted[index];
          final whiteIndex = index * 2;
          final blackIndex = index * 2 + 1;
          final isTurnActive = currentMoveIndex == whiteIndex || currentMoveIndex == blackIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () {
                if (blackIndex < sanMoves.length) {
                  _jumpToMoveIndex(blackIndex);
                } else {
                  _jumpToMoveIndex(whiteIndex);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isTurnActive ? Colors.deepPurple.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isTurnActive ? Border.all(color: Colors.deepPurple) : null,
                ),
                child: Center(
                  child: Text(
                    turnString,
                    style: TextStyle(
                      fontWeight: isTurnActive ? FontWeight.bold : FontWeight.normal,
                      color: isTurnActive ? Colors.deepPurple : Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoardPreferences() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.settings, color: Colors.deepPurple),
        title: const Text('Board Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Flip Board'),
                  value: SettingsService.instance.flipBoard,
                  onChanged: (val) {
                    SettingsService.instance.setFlipBoard(val);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Auto Rotate Board'),
                  subtitle: const Text('Rotates perspective to matching player turn'),
                  value: SettingsService.instance.autoRotate,
                  onChanged: (val) {
                    SettingsService.instance.setAutoRotate(val);
                    if (val) {
                      setState(() {
                        isWhitePerspective = (chessEngineService.activeTurn == PieceColor.white);
                      });
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Coordinates'),
                  value: SettingsService.instance.showCoordinates,
                  onChanged: (val) {
                    SettingsService.instance.setShowCoordinates(val);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Legal Move Hints'),
                  value: SettingsService.instance.showLegalHints,
                  onChanged: (val) {
                    SettingsService.instance.setShowLegalHints(val);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Highlight Last Move'),
                  value: SettingsService.instance.showLastMoveHighlight,
                  onChanged: (val) {
                    SettingsService.instance.setShowLastMoveHighlight(val);
                    setState(() {});
                  },
                ),
                ListTile(
                  title: const Text('Board Theme'),
                  trailing: DropdownButton<String>(
                    value: SettingsService.instance.boardTheme,
                    items: const [
                      DropdownMenuItem(value: 'classic_wood', child: Text('Classic Wood')),
                      DropdownMenuItem(value: 'ocean_blue', child: Text('Ocean Blue')),
                      DropdownMenuItem(value: 'slate_grey', child: Text('Slate Grey')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        SettingsService.instance.setBoardTheme(val);
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [Helper methods]
  /// A helper method is a function declared inside the class to perform specific calculations
  /// or lookups. Instead of cluttering our UI build tree with complex conditional logic,
  /// we move that code into a helper function to keep the visual tree neat and maintainable.
  ///
  /// [Returning values]
  /// Functions return values using the `return` keyword, passing calculated results back to the caller.
  ///
  /// [Why UI should not contain business logic]
  /// Decoupling business logic from rendering code is a core design standard in production software.
  /// The build method (UI) should focus solely on declarative layout structure, while metadata calculations
  /// are delegated to pure functions. This prevents visual clutter, improves readability, and makes it
  /// extremely easy to write unit tests for the logic functions without inflating widgets.
  String getPieceName(ChessPiece? piece) {
    if (piece == null) return 'Empty';
    switch (piece.pieceType) {
      case PieceType.king:
        return 'King';
      case PieceType.queen:
        return 'Queen';
      case PieceType.rook:
        return 'Rook';
      case PieceType.bishop:
        return 'Bishop';
      case PieceType.knight:
        return 'Knight';
      case PieceType.pawn:
        return 'Pawn';
    }
  }

  bool isWhitePiece(ChessPiece? piece) {
    return piece?.pieceColor == PieceColor.white;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('--------------------------------------------------');
    debugPrint('STEP 9');
    debugPrint('--------------------------------------------------');
    debugPrint('Board displayed with FEN: ${chessEngineService.fen}');

    // -------------------------------------------------------------------------
    // BEGINNER EXPLANATION: Flutter "RIGHT OVERFLOWED BY X PIXELS" Layout Warnings
    // -------------------------------------------------------------------------
    // 1. What causes a "RIGHT OVERFLOWED BY X PIXELS" warning?
    //    Flutter layout flows via "Constraints go down. Sizes go up. Parent sets position."
    //    When we layout elements horizontally (e.g. inside a Row or Flex), each child receives
    //    a constraint. If a child widget has a fixed width or a minimum size that exceeds the
    //    maximum width of the parent (the remaining screen width), the Flex layout cannot fit
    //    the child. Since standard Flex columns/rows do not auto-wrap or scroll by default,
    //    Flutter throws a RenderFlex overflow assertion and renders a yellow/black hazard stripe.
    //
    // 2. Why does Chrome-only testing miss real-device layout bugs?
    //    Desktop browser windows are wide, typically providing 1000px+ of logical width.
    //    Hardcoded element sizes (like 60px chessboard squares or fixed button lists) fit easily.
    //    Mobile devices, however, have narrow logical screens (e.g. 320dp to 390dp). When the app
    //    runs on a narrow phone like a Vivo, those same hardcoded widths exceed physical screens,
    //    triggering overflows. Testing at narrow constraints (e.g. 320dp to 360dp) is crucial to
    //    ensuring layout scaling works everywhere.
    // -------------------------------------------------------------------------

    // If the active side is in check, locate their King to render a red halo highlight
    (int row, int col)? checkedKingCoords;
    if (chessEngineService.inCheck) {
      checkedKingCoords = chessEngineService.findKing(
        chessEngineService.activeTurn,
      );
    }

    final compactButtonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: const Size(60, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    const buttonTextStyle = TextStyle(fontSize: 12);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('BlindChess Match'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Statistics',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatsScreen()),
                );
              },
            ),
          ],
        ),
        // We use SingleChildScrollView to make the screen scrollable, preventing layout overflow warnings.
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),

                // Chessboard Demo Title
                const Text(
                  'Chess Match',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 4),

                VoiceCommandWidget(
                  isEnabled: !isGameOver,
                  onCommand: (_, {sttConfidence}) {},
                ),

                const SizedBox(height: 4),

                // Top Player Clock
                Builder(
                  builder: (context) {
                    final effectivePerspective = isWhitePerspective ^ SettingsService.instance.flipBoard;
                    return _buildClockWidget(
                      color: effectivePerspective ? PieceColor.black : PieceColor.white,
                      isTop: true,
                    );
                  },
                ),

                // Control Action Buttons Row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      style: compactButtonStyle,
                      onPressed: () {
                        setState(() {
                          isWhitePerspective = !isWhitePerspective;
                        });
                      },
                      child: const Text('Flip Board', style: buttonTextStyle),
                    ),
                    ElevatedButton(
                      style: compactButtonStyle,
                      onPressed: currentMoveIndex >= 0 ? _performUndo : null,
                      child: const Text('Undo', style: buttonTextStyle),
                    ),
                    ElevatedButton(
                      style: compactButtonStyle,
                      onPressed: currentMoveIndex < uciMoves.length - 1 ? _performRedo : null,
                      child: const Text('Redo', style: buttonTextStyle),
                    ),
                    ElevatedButton(
                      style: compactButtonStyle,
                      onPressed: _confirmRestartGame,
                      child: const Text('Restart', style: buttonTextStyle),
                    ),
                    ElevatedButton(
                      style: compactButtonStyle,
                      onPressed: _confirmNewGame,
                      child: const Text('New Game', style: buttonTextStyle),
                    ),
                    ElevatedButton(
                      style: compactButtonStyle,
                      onPressed: _showPgnOptionsDialog,
                      child: const Text('PGN Options', style: buttonTextStyle),
                    ),
                    ElevatedButton(
                      style: compactButtonStyle,
                      onPressed: _showClockSelectorSheet,
                      child: Text(
                        _clockService.config.hasTimer ? 'Clock: ${_clockService.config.label}' : 'Set Clock',
                        style: buttonTextStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                /// [Blindfold Mode Toggle Switch]
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 4.0,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Normal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: isBlindfoldMode,
                        onChanged: _toggleBlindfoldMode,
                        activeThumbColor: Colors.deepPurple,
                      ),
                      const Text(
                        'Blindfold',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                /// [Difficulty Selector Segmented Control]
                if (isBlindfoldMode) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text(
                          'Easy',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected: selectedDifficulty == BlindfoldDifficulty.easy,
                        onSelected: (bool selected) {
                          if (selected) {
                            SettingsService.instance.setBlindfoldDifficulty(BlindfoldDifficulty.easy);
                            setState(() {
                              selectedDifficulty = BlindfoldDifficulty.easy;
                            });
                          }
                        },
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: selectedDifficulty == BlindfoldDifficulty.easy ? Colors.white : Colors.deepPurple,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text(
                          'Medium',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected: selectedDifficulty == BlindfoldDifficulty.medium,
                        onSelected: (bool selected) {
                          if (selected) {
                            SettingsService.instance.setBlindfoldDifficulty(BlindfoldDifficulty.medium);
                            setState(() {
                              selectedDifficulty = BlindfoldDifficulty.medium;
                            });
                          }
                        },
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: selectedDifficulty == BlindfoldDifficulty.medium ? Colors.white : Colors.deepPurple,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text(
                          'Hard',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected: selectedDifficulty == BlindfoldDifficulty.hard,
                        onSelected: (bool selected) {
                          if (selected) {
                            SettingsService.instance.setBlindfoldDifficulty(BlindfoldDifficulty.hard);
                            setState(() {
                              selectedDifficulty = BlindfoldDifficulty.hard;
                            });
                          }
                        },
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: selectedDifficulty == BlindfoldDifficulty.hard ? Colors.white : Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                /// [Reveal Button & Score display]
                if (isBlindfoldHidingActive) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: !canReveal ? null : _revealPiecesTemporarily,
                        child: Text(revealButtonLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Memory Score: $correctGuesses / $totalGuesses (${totalGuesses > 0 ? (correctGuesses * 100 ~/ totalGuesses) : 0}%)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                /// [Move History list panel]
                _buildMoveHistorySection(),
                const SizedBox(height: 12),

                // Bottom Player Clock
                Builder(
                  builder: (context) {
                    final effectivePerspective = isWhitePerspective ^ SettingsService.instance.flipBoard;
                    return _buildClockWidget(
                      color: effectivePerspective ? PieceColor.white : PieceColor.black,
                      isTop: false,
                    );
                  },
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ChessBoard(
                    chessEngineService: chessEngineService,
                    isWhitePerspective: isWhitePerspective,
                    shouldHidePieces: shouldHidePieces,
                    highlightedSquares: highlightedSquares,
                    lastMoveStart: lastMoveStart,
                    lastMoveEnd: lastMoveEnd,
                    checkedKingCoords: checkedKingCoords,
                    selectedSquare: selectedSquare,
                    flashStates: _flashStates,
                    readOnly: isGameOver,
                    onSquareTap: (actualRowIndex, actualColIndex, label) {
                      // Clear any existing snack bars to prevent queueing delay
                      ScaffoldMessenger.of(context).clearSnackBars();

                      // Show a sliding notification with the tapped square coordinates.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('You tapped $label'),
                          duration: const Duration(seconds: 1),
                        ),
                      );

                      setState(() {
                        // Evaluate guess attempts when pieces are hidden
                        final isDeselect = selectedSquare == label;
                        final isGuessAttempt =
                            shouldHidePieces &&
                            !highlightedSquares.contains((
                              actualRowIndex,
                              actualColIndex,
                            )) &&
                            !isDeselect;
                        if (isGuessAttempt) {
                          final tappedPiece = chessEngineService.pieceAt(
                            actualRowIndex,
                            actualColIndex,
                          );
                          final isCorrect =
                              tappedPiece != null &&
                              (tappedPiece.pieceColor ==
                                  chessEngineService.activeTurn);

                          totalGuesses++;
                          if (isCorrect) {
                            correctGuesses++;
                            _triggerFlash(
                              actualRowIndex,
                              actualColIndex,
                              'green',
                            );
                          } else {
                            _triggerFlash(
                              actualRowIndex,
                              actualColIndex,
                              'red',
                            );
                            AudioService.instance.playIncorrectGuess();
                          }
                        }

                        final tappedPiece = chessEngineService.pieceAt(
                          actualRowIndex,
                          actualColIndex,
                        );
                        final isCurrentPlayersPiece =
                            tappedPiece != null &&
                            (tappedPiece.pieceColor ==
                                chessEngineService.activeTurn);

                        if (selectedSquare == label) {
                          // Deselect
                          selectedSquare = null;
                          selectedRow = null;
                          selectedCol = null;
                          highlightedSquares = const [];
                        } else if (highlightedSquares.contains((
                          actualRowIndex,
                          actualColIndex,
                        ))) {
                          // Check if this move is a pawn promotion
                          final piece = chessEngineService.pieceAt(
                            selectedRow!,
                            selectedCol!,
                          );
                          final isPawn = piece?.pieceType == PieceType.pawn;
                          final isPromotionRow =
                              (piece?.pieceColor == PieceColor.white &&
                                  actualRowIndex == 0) ||
                              (piece?.pieceColor == PieceColor.black &&
                                  actualRowIndex == 7);

                          if (isPawn && isPromotionRow) {
                            final movingColor = piece!.pieceColor;
                            final fromR = selectedRow!;
                            final fromC = selectedCol!;
                            final toR = actualRowIndex;
                            final toC = actualColIndex;

                            // Clear active selection states before displaying dialog
                            setState(() {
                              selectedSquare = null;
                              selectedRow = null;
                              selectedCol = null;
                              highlightedSquares = const [];
                            });

                            // Show promotion dialog asynchronously
                            _showPromotionDialog(movingColor).then((choice) {
                              if (!mounted) return;
                              if (choice != null) {
                                final fromRank = 8 - fromR;
                                final filesList = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
                                final fromFile = filesList[fromC];
                                final fromSquare = '$fromFile$fromRank';
                                final toRank = 8 - toR;
                                final toFile = filesList[toC];
                                final toSquare = '$toFile$toRank';

                                final legalMoves = chessEngineService.getLegalMoves();
                                Map<String, dynamic>? executedMove;
                                for (final m in legalMoves) {
                                  if (m['from'] == fromSquare && m['to'] == toSquare && m['promotion'] == choice) {
                                    executedMove = m;
                                    break;
                                  }
                                }

                                final success = chessEngineService.makeMove(
                                  fromR,
                                  fromC,
                                  toR,
                                  toC,
                                  promotion: choice,
                                );
                                if (success) {
                                  _onMoveExecuted(fromSquare, toSquare, choice, executedMove);
                                  if (executedMove != null) {
                                    _announceMoveAndState(executedMove, isVoice: false);
                                  }
                                }
                              }
                            });
                          } else {
                            final fromRank = 8 - selectedRow!;
                            final filesList = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
                            final fromFile = filesList[selectedCol!];
                            final fromSquare = '$fromFile$fromRank';
                            final toRank = 8 - actualRowIndex;
                            final toFile = filesList[actualColIndex];
                            final toSquare = '$toFile$toRank';

                            final legalMoves = chessEngineService.getLegalMoves();
                            Map<String, dynamic>? executedMove;
                            for (final m in legalMoves) {
                              if (m['from'] == fromSquare && m['to'] == toSquare) {
                                executedMove = m;
                                break;
                              }
                            }

                            // Standard move execution
                            final success = chessEngineService.makeMove(
                              selectedRow!,
                              selectedCol!,
                              actualRowIndex,
                              actualColIndex,
                            );
                            if (success) {
                              _onMoveExecuted(fromSquare, toSquare, null, executedMove);
                              if (executedMove != null) {
                                _announceMoveAndState(executedMove, isVoice: false);
                              }
                            }
                          }
                        } else {
                          // Non-highlighted tap
                          if (isCurrentPlayersPiece) {
                            // Reselect
                            selectedSquare = label;
                            selectedRow = actualRowIndex;
                            selectedCol = actualColIndex;
                            highlightedSquares = chessEngineService
                                .legalDestinationsFrom(
                                  actualRowIndex,
                                  actualColIndex,
                                );
                          } else {
                            // Deselect
                            selectedSquare = null;
                            selectedRow = null;
                            selectedCol = null;
                            highlightedSquares = const [];
                          }
                        }
                      });
                    },
                  ),
                ),



                // Title displaying which square is currently selected
                const Text(
                  'Selected Square:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                /// [Conditional UI]
                /// We use conditional rendering (`selectedSquare ?? 'None'`) to decide what text to show.
                /// If the variable is `null`, it renders `'None'`. If it has a value, it renders the coordinate.
                Text(
                  selectedSquare ?? 'None',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 24),

                // Board Preferences Panel
                _buildBoardPreferences(),
                const SizedBox(height: 12),

                // Settings & Customization Panel
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Settings & Themes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Board Theme Row
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text(
                              'Board Theme:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                ChoiceChip(
                                  label: const Text(
                                    'Wood',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  selected:
                                      SettingsService.instance.boardTheme ==
                                      'classic_wood',
                                  onSelected: (bool selected) async {
                                    if (selected) {
                                      await SettingsService.instance
                                          .setBoardTheme('classic_wood');
                                      setState(() {});
                                    }
                                  },
                                  selectedColor: Colors.deepPurple,
                                  backgroundColor: Colors.deepPurple.withValues(
                                    alpha: 0.1,
                                  ),
                                  labelStyle: TextStyle(
                                    color:
                                        SettingsService.instance.boardTheme ==
                                            'classic_wood'
                                        ? Colors.white
                                        : Colors.deepPurple,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text(
                                    'Ocean',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  selected:
                                      SettingsService.instance.boardTheme ==
                                      'ocean_blue',
                                  onSelected: (bool selected) async {
                                    if (selected) {
                                      await SettingsService.instance
                                          .setBoardTheme('ocean_blue');
                                      setState(() {});
                                    }
                                  },
                                  selectedColor: Colors.deepPurple,
                                  backgroundColor: Colors.deepPurple.withValues(
                                    alpha: 0.1,
                                  ),
                                  labelStyle: TextStyle(
                                    color:
                                        SettingsService.instance.boardTheme ==
                                            'ocean_blue'
                                        ? Colors.white
                                        : Colors.deepPurple,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text(
                                    'Slate',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  selected:
                                      SettingsService.instance.boardTheme ==
                                      'slate_grey',
                                  onSelected: (bool selected) async {
                                    if (selected) {
                                      await SettingsService.instance
                                          .setBoardTheme('slate_grey');
                                      setState(() {});
                                    }
                                  },
                                  selectedColor: Colors.deepPurple,
                                  backgroundColor: Colors.deepPurple.withValues(
                                    alpha: 0.1,
                                  ),
                                  labelStyle: TextStyle(
                                    color:
                                        SettingsService.instance.boardTheme ==
                                            'slate_grey'
                                        ? Colors.white
                                        : Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Light / Dark mode switch
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text(
                              'Dark Mode:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Switch(
                              value: SettingsService.instance.isDarkMode,
                              onChanged: (bool val) async {
                                await SettingsService.instance.toggleDarkMode();
                                setState(() {});
                              },
                              activeThumbColor: Colors.deepPurple,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sound effects Muted state switch
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text(
                              'Muted:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Switch(
                              value: SettingsService.instance.isMuted,
                              onChanged: (bool val) async {
                                await SettingsService.instance.toggleMute();
                                setState(() {});
                              },
                              activeThumbColor: Colors.deepPurple,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Voice Debug Mode switch
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text(
                              'Voice Debug Mode:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Switch(
                              value: SettingsService.instance.isVoiceDebugMode,
                              onChanged: (bool val) async {
                                await SettingsService.instance
                                    .setVoiceDebugMode(val);
                                setState(() {});
                              },
                              activeThumbColor: Colors.deepPurple,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Back Home'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }



  // ==========================================
  // VoicePipelineDelegate Overrides
  // ==========================================
  @override
  List<Map<String, dynamic>> getLegalMoves() => chessEngineService.getLegalMoves();

  @override
  String getFen() => chessEngineService.fen;

  @override
  bool makeMove(int fromRow, int fromCol, int toRow, int toCol, {String? promotion}) {
    return chessEngineService.makeMove(fromRow, fromCol, toRow, toCol, promotion: promotion);
  }

  @override
  bool get canUndo => chessEngineService.canUndo;

  @override
  void undo() {
    _performUndo();
  }

  @override
  void onUndoSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Move undone.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _announceMoveAndState(Map<String, dynamic> move, {bool isVoice = false}) {
    final flags = move['flags'] as String? ?? '';
    final isCapture = flags.contains('c') || flags.contains('e');
    final isPromotion = move['promotion'] != null;
    final isCheck = chessEngineService.inCheck;
    final isCheckmate = chessEngineService.inCheckmate;
    final isStalemate = chessEngineService.inStalemate;
    final isDraw = chessEngineService.inDraw;
    final isGameOver = this.isGameOver;

    // 1. Play sound feedback
    if (isGameOver) {
      AudioService.instance.playGameOver();
    } else if (isCheck) {
      AudioService.instance.playCheck();
    } else if (isPromotion) {
      AudioService.instance.playPromotion();
    } else if (isCapture) {
      AudioService.instance.playCapture();
    } else {
      AudioService.instance.playMove();
    }

    // 2. Play haptic feedback
    if (isGameOver) {
      HapticService.triggerGameOver();
    } else if (isCheck) {
      HapticService.triggerCheck();
    } else {
      HapticService.triggerSuccessfulMove();
    }

    // 3. Spoken feedback
    final settings = AccessibilitySettingsService.instance;
    if (settings.speechEnabled && !isVoice) {
      final moverColor = chessEngineService.activeTurn == PieceColor.white 
          ? PieceColor.black 
          : PieceColor.white;
      
      var text = ChessSpeechSynthesizer.translateMove(
        move: move,
        verbosity: settings.verbosity,
        moverColor: moverColor,
        isCheck: isCheck,
        isCheckmate: isCheckmate,
        isStalemate: isStalemate,
      );

      if (!isCheckmate && !isStalemate && !isDraw) {
        final nextTurnStr = chessEngineService.activeTurn == PieceColor.white ? "White's turn." : "Black's turn.";
        if (settings.verbosity == VerbosityLevel.detailed) {
          text += '. $nextTurnStr';
        }
      }

      TtsService.instance.speak(text, priority: AnnouncementPriority.normal);
    }
  }

  @override
  void onMoveSuccess(Map<String, dynamic> move, String confirmationText) {
    final fromStr = move['from'] as String;
    final toStr = move['to'] as String;
    final promo = move['promotion'] as String?;

    _onMoveExecuted(fromStr, toStr, promo, move);

    _announceMoveAndState(move, isVoice: true);
    DiagnosticRecorder.instance.updateLastRecordExecution(success: true);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(confirmationText),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void onError(String message) {
    AudioService.instance.playIllegalMove();
    HapticService.triggerIllegalMove();

    DiagnosticRecorder.instance.updateLastRecordExecution(success: false);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void onResign() {
    final loser = chessEngineService.activeTurn;
    final winner = loser == PieceColor.white ? PieceColor.black : PieceColor.white;
    final winnerStr = winner == PieceColor.white ? 'White' : 'Black';
    final result = GameResult(
      type: ResultType.checkmate,
      winnerColor: winner,
      description: 'Resignation — $winnerStr wins.',
    );

    setState(() {
      _clockService.stop();
    });

    _saveCurrentGameSession(result: result);
    _showGameResultDialog(result);
  }

  @override
  void onDrawOffer() {
    final result = GameResult(
      type: ResultType.drawAgreement,
      description: 'Draw agreed.',
    );

    setState(() {
      _clockService.stop();
    });

    _saveCurrentGameSession(result: result);
    _showGameResultDialog(result);
  }

  @override
  void onRepeatAnnouncement() {
    // No-op, handled directly by the pipeline TTS replay
  }

  @override
  void onHelp() {
    _showVoiceHelpDialog();
  }

  @override
  void onNewGame() {
    _startNewGameSetup();
  }

  @override
  void onRestartGame() {
    _restartGameSetup();
  }

  void _showVoiceHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Commands Help'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You can speak the following commands:'),
            SizedBox(height: 8),
            Text('• Moves: "e2 to e4", "knight f3", "castle kingside", "promote to queen"'),
            Text('• Game Actions: "undo", "resign", "draw", "repeat", "help", "new game", "restart"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
