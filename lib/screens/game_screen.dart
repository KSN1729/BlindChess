import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/chess_board.dart';
import '../models/chess_piece.dart';
import '../services/chess_engine_service.dart';
import '../services/statistics_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/diagnostic_recorder.dart';
import '../widgets/voice_command_widget.dart';
import '../services/voice_pipeline_service.dart';
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

  /// [selectedSquare variable]
  /// A mutable state variable that holds the coordinate label of the currently selected chess square (e.g., "E4").
  /// It is initialized to `null` to represent that no square is selected initially (which prints "None").
  String? selectedSquare;

  // Selected row and column coordinates tracking to handle move origin.
  int? selectedRow;
  int? selectedCol;

  // Last move source and destination coordinates to display visual highlights.
  (int row, int col)? lastMoveStart;
  (int row, int col)? lastMoveEnd;

  // Track history of moves for last-move highlights.
  // Each entry is a pair of ((fromRow, fromCol), (toRow, toCol)) coordinates.
  final List<((int, int), (int, int))> _moveHistoryCoords = [];

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

  void _performUndo() {
    setState(() {
      final undone = chessEngineService.undo();
      if (undone != null) {
        if (_moveHistoryCoords.isNotEmpty) {
          _moveHistoryCoords.removeLast();
          if (_moveHistoryCoords.isNotEmpty) {
            final lastMove = _moveHistoryCoords.last;
            lastMoveStart = lastMove.$1;
            lastMoveEnd = lastMove.$2;
          } else {
            lastMoveStart = null;
            lastMoveEnd = null;
          }
        }
        // Clear active selections
        selectedSquare = null;
        selectedRow = null;
        selectedCol = null;
        highlightedSquares = const [];
        _isGameStatsRecorded = false;
        pendingMoveForClarification = null;
        pendingUndoConfirmation = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    isBlindfoldMode = SettingsService.instance.isBlindfoldMode;
    selectedDifficulty = SettingsService.instance.blindfoldDifficulty;
    VoicePipelineService.instance.setDelegate(this);
  }

  @override
  void dispose() {
    VoicePipelineService.instance.setDelegate(null);
    VoicePipelineService.instance.stopPipeline();
    _revealTimer?.cancel();
    super.dispose();
  }

  /// Exposes if the game has reached an end state (checkmate, stalemate, or draw).
  bool get isGameOver {
    return chessEngineService.inCheckmate ||
        chessEngineService.inStalemate ||
        chessEngineService.inDraw;
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

  /// Callback when Blindfold Mode switch state is toggled.
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

  /// Triggers a brief 450ms visual flash on the target cell coordinates.
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

  /// Temporarily reveals all hidden pieces for 3 seconds.
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

  /// Resets the game engine and UI state variables to start a fresh game.
  void resetGame() {
    setState(() {
      chessEngineService.reset();
      selectedSquare = null;
      selectedRow = null;
      selectedCol = null;
      lastMoveStart = null;
      lastMoveEnd = null;
      highlightedSquares = const [];
      _moveHistoryCoords.clear();
      _blindfoldToggleMoveCount = 0;
      totalGuesses = 0;
      correctGuesses = 0;
      _isRevealed = false;
      _revealLastUsedMoveCount = null;
      _revealTimer?.cancel();
      _isGameStatsRecorded = false;
      // selectedDifficulty is preserved across New Game taps
    });
  }

  /// Presents a custom dialog showing game completion details.
  void _showGameEndDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force active selection of dialog actions
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                resetGame();
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

  /// Checks the engine status after a move is completed and shows the relevant dialog if the game ended.
  void checkGameStatus() {
    // Execute after the frame builds to ensure visual pawn updates render before the dialog overlays
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final isCheckmate = chessEngineService.inCheckmate;
      final isStalemate = chessEngineService.inStalemate;
      final isDraw = chessEngineService.inDraw;

      if (isCheckmate || isStalemate || isDraw) {
        if (!_isGameStatsRecorded) {
          _isGameStatsRecorded = true;

          String? winner;
          if (isCheckmate) {
            final loserColor = chessEngineService.activeTurn;
            winner = (loserColor == PieceColor.white) ? 'black' : 'white';
          }

          StatisticsService.instance.recordGame(
            isDraw: isStalemate || isDraw,
            winningColor: winner,
            isCheckmate: isCheckmate,
            halfMoves: chessEngineService.getHistory().length,
            isBlindfoldModeActive: isBlindfoldMode,
            memoryScorePercentage: isBlindfoldMode
                ? (totalGuesses > 0
                      ? (correctGuesses * 100 ~/ totalGuesses)
                      : 0)
                : null,
          );
        }
      }

      if (isCheckmate) {
        AudioService.instance.playCheck();
        final losingColor = chessEngineService.activeTurn;
        final winningColorStr = (losingColor == PieceColor.white)
            ? 'Black'
            : 'White';
        _showGameEndDialog(
          title: 'Checkmate',
          message: 'Checkmate — $winningColorStr wins.',
        );
      } else if (isStalemate) {
        AudioService.instance.playCheck();
        _showGameEndDialog(title: 'Stalemate', message: 'Stalemate — Draw.');
      } else if (isDraw) {
        AudioService.instance.playCheck();
        String reason = 'Draw.';
        if (chessEngineService.inThreefoldRepetition) {
          reason = 'Draw by threefold repetition.';
        } else if (chessEngineService.insufficientMaterial) {
          reason = 'Draw by insufficient material.';
        }
        _showGameEndDialog(title: 'Game Over', message: reason);
      }
    });
  }

  /// Displays an alert dialog with options to choose the piece type to promote the pawn to.
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
      barrierDismissible: false, // Must tap one of the choices
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

  /// Formats raw Standard Algebraic Notation (SAN) move list into paired strings (e.g. "1. e4 e5").
  List<String> getFormattedHistory(List<dynamic> history) {
    final List<String> formatted = [];
    for (int i = 0; i < history.length; i += 2) {
      final moveNumber = (i ~/ 2) + 1;
      final whiteMove = history[i].toString();
      final blackMove = (i + 1 < history.length)
          ? history[i + 1].toString()
          : '';
      if (blackMove.isNotEmpty) {
        formatted.add('$moveNumber. $whiteMove $blackMove');
      } else {
        formatted.add('$moveNumber. $whiteMove');
      }
    }
    return formatted;
  }

  /// Builds the move history horizontal scrollable row panel.
  Widget _buildMoveHistorySection(List<dynamic> rawHistory) {
    final formattedMoves = getFormattedHistory(rawHistory);
    if (formattedMoves.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: formattedMoves.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Center(
              child: Text(
                formattedMoves[index],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
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
                const SizedBox(height: 16),

                // Chessboard Demo Title
                const Text(
                  'Chess Match',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),

                /// [Control Action Buttons Row]
                /// Displays Flip Board, Undo, and New Game buttons horizontally.
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isWhitePerspective = !isWhitePerspective;
                        });
                      },
                      child: const Text('Flip Board'),
                    ),
                    ElevatedButton(
                      onPressed: !chessEngineService.canUndo
                          ? null
                          : _performUndo,
                      child: const Text('Undo'),
                    ),
                    ElevatedButton(
                      onPressed: resetGame,
                      child: const Text('New Game'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                /// [Blindfold Mode Toggle Switch]
                /// Planks a Switch widget with Normal and Blindfold labels to toggle memory testing mode.
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
                /// Displays Easy, Medium, and Hard buttons as ToggleButtons when Blindfold is active.
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
                        selected:
                            selectedDifficulty == BlindfoldDifficulty.easy,
                        onSelected: (bool selected) {
                          if (selected) {
                            SettingsService.instance.setBlindfoldDifficulty(
                              BlindfoldDifficulty.easy,
                            );
                            setState(() {
                              selectedDifficulty = BlindfoldDifficulty.easy;
                            });
                          }
                        },
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.deepPurple.withValues(
                          alpha: 0.1,
                        ),
                        labelStyle: TextStyle(
                          color: selectedDifficulty == BlindfoldDifficulty.easy
                              ? Colors.white
                              : Colors.deepPurple,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text(
                          'Medium',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected:
                            selectedDifficulty == BlindfoldDifficulty.medium,
                        onSelected: (bool selected) {
                          if (selected) {
                            SettingsService.instance.setBlindfoldDifficulty(
                              BlindfoldDifficulty.medium,
                            );
                            setState(() {
                              selectedDifficulty = BlindfoldDifficulty.medium;
                            });
                          }
                        },
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.deepPurple.withValues(
                          alpha: 0.1,
                        ),
                        labelStyle: TextStyle(
                          color:
                              selectedDifficulty == BlindfoldDifficulty.medium
                              ? Colors.white
                              : Colors.deepPurple,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text(
                          'Hard',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected:
                            selectedDifficulty == BlindfoldDifficulty.hard,
                        onSelected: (bool selected) {
                          if (selected) {
                            SettingsService.instance.setBlindfoldDifficulty(
                              BlindfoldDifficulty.hard,
                            );
                            setState(() {
                              selectedDifficulty = BlindfoldDifficulty.hard;
                            });
                          }
                        },
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.deepPurple.withValues(
                          alpha: 0.1,
                        ),
                        labelStyle: TextStyle(
                          color: selectedDifficulty == BlindfoldDifficulty.hard
                              ? Colors.white
                              : Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                /// [Reveal Button & Score display]
                /// Placed below the toggles, showing score statistics and the reveal button when hiding triggers.
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
                _buildMoveHistorySection(chessEngineService.getHistory()),
                const SizedBox(height: 12),

                /// [Looping in Flutter]
                /// Since Flutter layouts are constructed as nested trees of widget objects, we can use Dart's
                /// loop mechanisms directly inside our widget trees to generate arrays of child widgets dynamically.
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
                          final isCapture =
                              chessEngineService.pieceAt(
                                actualRowIndex,
                                actualColIndex,
                              ) !=
                              null;
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
                                final success = chessEngineService.makeMove(
                                  fromR,
                                  fromC,
                                  toR,
                                  toC,
                                  promotion: choice,
                                );
                                if (success) {
                                  setState(() {
                                    _moveHistoryCoords.add((
                                      (fromR, fromC),
                                      (toR, toC),
                                    ));
                                    lastMoveStart = (fromR, fromC);
                                    lastMoveEnd = (toR, toC);
                                    lastMoveTime = DateTime.now();
                                  });
                                  if (chessEngineService.inCheck ||
                                      isGameOver) {
                                    AudioService.instance.playCheck();
                                  } else if (isCapture) {
                                    AudioService.instance.playCapture();
                                  } else {
                                    AudioService.instance.playMove();
                                  }
                                  checkGameStatus();
                                }
                              }
                            });
                          } else {
                            // Standard move execution
                            final success = chessEngineService.makeMove(
                              selectedRow!,
                              selectedCol!,
                              actualRowIndex,
                              actualColIndex,
                            );
                            if (success) {
                              if (chessEngineService.inCheck || isGameOver) {
                                AudioService.instance.playCheck();
                              } else if (isCapture) {
                                AudioService.instance.playCapture();
                              } else {
                                AudioService.instance.playMove();
                              }

                              lastMoveStart = (selectedRow!, selectedCol!);
                              lastMoveEnd = (actualRowIndex, actualColIndex);
                              _moveHistoryCoords.add((
                                (selectedRow!, selectedCol!),
                                (actualRowIndex, actualColIndex),
                              ));
                              lastMoveTime = DateTime.now();
                              selectedSquare = null;
                              selectedRow = null;
                              selectedCol = null;
                              highlightedSquares = const [];

                              // Verify if the move resulted in game over states
                              checkGameStatus();
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

                VoiceCommandWidget(
                  isEnabled: !isGameOver,
                  onCommand: (_, {sttConfidence}) {},
                ),

                const SizedBox(height: 12),

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

  @override
  void onMoveSuccess(Map<String, dynamic> move, String confirmationText) {
    setState(() {
      final flags = move['flags'] as String?;
      final isCapture = flags != null && (flags.contains('c') || flags.contains('e'));
      final isGameOver = this.isGameOver;

      if (chessEngineService.inCheck || isGameOver) {
        AudioService.instance.playCheck();
      } else if (isCapture) {
        AudioService.instance.playCapture();
      } else {
        AudioService.instance.playMove();
      }

      final fromStr = move['from'] as String;
      final toStr = move['to'] as String;
      final fromFile = fromStr[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
      final fromRow = 8 - int.parse(fromStr[1]);
      final toFile = toStr[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
      final toRow = 8 - int.parse(toStr[1]);

      lastMoveStart = (fromRow, fromFile);
      lastMoveEnd = (toRow, toFile);
      _moveHistoryCoords.add(((fromRow, fromFile), (toRow, toFile)));
      lastMoveTime = DateTime.now();

      selectedSquare = null;
      selectedRow = null;
      selectedCol = null;
      highlightedSquares = const [];

      checkGameStatus();

      DiagnosticRecorder.instance.updateLastRecordExecution(success: true);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confirmationText),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  void onError(String message) {
    DiagnosticRecorder.instance.updateLastRecordExecution(success: false);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
