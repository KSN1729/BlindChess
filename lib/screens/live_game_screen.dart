import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chess_piece.dart';
import '../services/chess_engine_service.dart';
import '../services/lichess_service.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/statistics_service.dart';
import '../services/diagnostic_recorder.dart';
import '../widgets/chess_board.dart';
import '../widgets/voice_command_widget.dart';
import '../utils/voice_command_parser.dart';
import '../utils/tts/tts_base.dart' as tts;
import '../config/voice_confidence_config.dart';

class LiveGameScreen extends StatefulWidget {
  final String gameId;
  final bool? initialBlindfoldMode;
  final BlindfoldDifficulty? initialBlindfoldDifficulty;

  const LiveGameScreen({
    super.key,
    required this.gameId,
    this.initialBlindfoldMode,
    this.initialBlindfoldDifficulty,
  });

  @override
  State<LiveGameScreen> createState() => _LiveGameScreenState();
}

class _LiveGameScreenState extends State<LiveGameScreen>
    with WidgetsBindingObserver {
  final ChessEngineService _chessEngineService = ChessEngineService();
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  bool _isLoading = true;
  String? _errorMessage;
  bool _connectionLost = false;

  // Game data parsed from stream
  String _opponentName = 'Stockfish AI';
  PieceColor _playerColor = PieceColor.white;
  String _gameStatus = 'Connecting...';
  int _moveCount = 0;

  // Highlighting last move squares
  (int row, int col)? _lastMoveStart;
  (int row, int col)? _lastMoveEnd;
  (int row, int col)? _checkedKingCoords;

  // Selection & sending states for player moves
  bool _isSendingMove = false;
  List<(int, int)> _highlightedSquares = const [];
  String? _selectedSquare;
  int? _selectedRow;
  int? _selectedCol;

  // Clock state variables
  int _whiteTimeMs = 0;
  int _blackTimeMs = 0;
  Timer? _clockTimer;

  // Draw offer state
  bool _opponentDrawOffered = false;
  bool _isGameStatsRecorded = false;

  // Blindfold Mode State
  int _blindfoldToggleMoveCount = 0;
  bool _isRevealed = false;
  int? _revealLastUsedMoveCount;
  Timer? _revealTimer;
  int totalGuesses = 0;
  int correctGuesses = 0;
  final Map<(int, int), String> _flashStates = {};
  Map<String, dynamic>? pendingMoveForClarification;
  DateTime? lastMoveTime;
  bool pendingUndoConfirmation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialBlindfoldMode != null) {
      SettingsService.instance.setBlindfoldMode(widget.initialBlindfoldMode!);
    }
    if (widget.initialBlindfoldDifficulty != null) {
      SettingsService.instance.setBlindfoldDifficulty(
        widget.initialBlindfoldDifficulty!,
      );
    }
    _startStreaming();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final isGameOver =
          _gameStatus.startsWith('Game Over') ||
          _chessEngineService.inCheckmate ||
          _chessEngineService.inStalemate;
      if (!isGameOver) {
        debugPrint('App resumed, re-establishing live game stream...');
        _startStreaming(isReconnecting: true);
      }
    }
  }

  void _startStreaming({bool isReconnecting = false}) {
    setState(() {
      if (!isReconnecting) {
        _isLoading = true;
      }
      _errorMessage = null;
      _connectionLost = false;
    });

    _clockTimer?.cancel();
    _streamSubscription?.cancel();
    _streamSubscription = LichessService.instance
        .streamGameState(widget.gameId)
        .listen(
          _handleStreamEvent,
          onError: _handleStreamError,
          onDone: _handleStreamDone,
          cancelOnError: true,
        );
    _startClockTimer();
  }

  void _handleStreamEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final type = event['type'] as String?;

    if (type == 'gameFull') {
      final white = event['white'];
      final black = event['black'];
      final whiteName = white?['name'] ?? 'White';
      final blackName = black?['name'] ?? 'Black';

      final currentUsername = LichessService.instance.username;
      if (currentUsername != null &&
          currentUsername.toLowerCase() == whiteName.toString().toLowerCase()) {
        _playerColor = PieceColor.white;
        _opponentName = blackName.toString();
      } else {
        _playerColor = PieceColor.black;
        _opponentName = whiteName.toString();
      }

      final state = event['state'] ?? {};
      if (state['wtime'] != null) {
        _whiteTimeMs = state['wtime'] as int;
      }
      if (state['btime'] != null) {
        _blackTimeMs = state['btime'] as int;
      }

      final wdraw = state['wdraw'] == true;
      final bdraw = state['bdraw'] == true;
      _opponentDrawOffered = _playerColor == PieceColor.white ? bdraw : wdraw;

      final movesStr = (state['moves'] as String?) ?? '';
      _applyMoves(movesStr);

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      final status = state['status'] as String? ?? 'started';
      final winner = state['winner'] as String?;
      _updateStatus(status, winner);
    } else if (type == 'gameState') {
      if (event['wtime'] != null) {
        _whiteTimeMs = event['wtime'] as int;
      }
      if (event['btime'] != null) {
        _blackTimeMs = event['btime'] as int;
      }

      final wdraw = event['wdraw'] == true;
      final bdraw = event['bdraw'] == true;
      _opponentDrawOffered = _playerColor == PieceColor.white ? bdraw : wdraw;

      final movesStr = (event['moves'] as String?) ?? '';
      _applyMoves(movesStr);

      final status = event['status'] as String? ?? 'started';
      final winner = event['winner'] as String?;
      _updateStatus(status, winner);
    }
  }

  void _applyMoves(String movesStr) {
    final oldMoveCount = _moveCount;
    _chessEngineService.reset();
    _lastMoveStart = null;
    _lastMoveEnd = null;

    final trimmed = movesStr.trim();
    if (trimmed.isEmpty) {
      _moveCount = 0;
      _updateCheckedKing();
      if (mounted) setState(() {});
      return;
    }

    final movesList = trimmed.split(' ');
    bool lastMoveCaptured = false;
    for (int i = 0; i < movesList.length; i++) {
      final uci = movesList[i];
      if (uci.length >= 4) {
        if (i == movesList.length - 1 &&
            oldMoveCount > 0 &&
            movesList.length > oldMoveCount) {
          final toFile = uci[2];
          final toRank = uci[3];
          final toCol = toFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
          final toRow = 8 - int.parse(toRank);
          lastMoveCaptured = _chessEngineService.pieceAt(toRow, toCol) != null;
        }

        final success = _chessEngineService.makeUciMove(uci);
        if (success && i == movesList.length - 1) {
          final fromFile = uci[0];
          final fromRank = uci[1];
          final toFile = uci[2];
          final toRank = uci[3];

          final fromCol = fromFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
          final fromRow = 8 - int.parse(fromRank);
          final toCol = toFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
          final toRow = 8 - int.parse(toRank);

          _lastMoveStart = (fromRow, fromCol);
          _lastMoveEnd = (toRow, toCol);
        }
      }
    }

    _moveCount = movesList.length;
    _updateCheckedKing();

    if (_moveCount > oldMoveCount && oldMoveCount > 0) {
      if (_chessEngineService.inCheck || _chessEngineService.inCheckmate) {
        AudioService.instance.playCheck();
      } else if (lastMoveCaptured) {
        AudioService.instance.playCapture();
      } else {
        AudioService.instance.playMove();
      }
    }

    if (mounted) setState(() {});
  }

  void _updateCheckedKing() {
    _checkedKingCoords = null;
    if (_chessEngineService.inCheck) {
      final activeColor = _chessEngineService.activeTurn;
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final piece = _chessEngineService.pieceAt(r, c);
          if (piece != null &&
              piece.pieceType == PieceType.king &&
              piece.pieceColor == activeColor) {
            _checkedKingCoords = (r, c);
            return;
          }
        }
      }
    }
  }

  void _updateStatus(String status, String? winner) {
    if (!mounted) return;

    final terminalStatuses = {
      'mate',
      'resign',
      'draw',
      'stalemate',
      'timeout',
      'outoftime',
      'cheat',
      'variantEnd',
    };
    final isGameOver = terminalStatuses.contains(status.toLowerCase());

    if (isGameOver && !_isGameStatsRecorded) {
      _isGameStatsRecorded = true;
      final isDrawResult = (winner == null);

      StatisticsService.instance.recordGame(
        isDraw: isDrawResult,
        winningColor: winner,
        isCheckmate: status.toLowerCase() == 'mate',
        halfMoves: _moveCount,
        isBlindfoldModeActive: isBlindfoldMode,
        memoryScorePercentage: isBlindfoldMode
            ? (totalGuesses > 0 ? (correctGuesses * 100 ~/ totalGuesses) : 0)
            : null,
        isOnline: true,
      );
    }

    setState(() {
      if (status != 'started') {
        _gameStatus = 'Game Over: ${status.toUpperCase()}';
      } else {
        if (_chessEngineService.inCheckmate) {
          _gameStatus = 'Checkmate!';
        } else if (_chessEngineService.inStalemate) {
          _gameStatus = 'Stalemate!';
        } else if (_chessEngineService.inCheck) {
          _gameStatus = 'Check!';
        } else {
          final turn = _chessEngineService.activeTurn;
          if (turn == _playerColor) {
            _gameStatus = 'Your turn';
          } else {
            _gameStatus = "Opponent's turn";
          }
        }
      }
    });
  }

  void _handleStreamError(dynamic error) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _connectionLost = true;
      _errorMessage = error.toString().replaceAll('Exception: ', '');
    });
  }

  void _handleStreamDone() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _connectionLost = true;
    });
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      if (_isLoading || _connectionLost) return;

      // Do not tick if game is over
      if (_gameStatus.startsWith('Game Over') ||
          _chessEngineService.inCheckmate ||
          _chessEngineService.inStalemate) {
        return;
      }

      final turn = _chessEngineService.activeTurn;
      setState(() {
        if (turn == PieceColor.white) {
          _whiteTimeMs = (_whiteTimeMs - 100).clamp(0, 999999999).toInt();
        } else {
          _blackTimeMs = (_blackTimeMs - 100).clamp(0, 999999999).toInt();
        }
      });
    });
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '00:00';
    final seconds = (ms / 1000).ceil();
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    final secsStr = secs.toString().padLeft(2, '0');
    if (hours > 0) {
      final minsStr = mins.toString().padLeft(2, '0');
      return '$hours:$minsStr:$secsStr';
    } else {
      final minsStr = mins.toString().padLeft(2, '0');
      return '$minsStr:$secsStr';
    }
  }

  void _handleMidGameExit() {
    if (!_isLoading &&
        !_isGameStatsRecorded &&
        !_gameStatus.startsWith('Game Over')) {
      _isGameStatsRecorded = true;
      final winningColor = _playerColor == PieceColor.white ? 'black' : 'white';
      StatisticsService.instance.recordGame(
        isDraw: false,
        winningColor: winningColor,
        isCheckmate: false,
        halfMoves: _moveCount,
        isBlindfoldModeActive: isBlindfoldMode,
        memoryScorePercentage: isBlindfoldMode
            ? (totalGuesses > 0 ? (correctGuesses * 100 ~/ totalGuesses) : 0)
            : null,
        isOnline: true,
      );
      LichessService.instance.resignGame(widget.gameId).catchError((e) {
        debugPrint('Failed to resign game on exit: $e');
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _streamSubscription?.cancel();
    _revealTimer?.cancel();
    super.dispose();
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

  List<(int, int)> get highlightedSquares => _highlightedSquares;

  bool get isBlindfoldMode => SettingsService.instance.isBlindfoldMode;
  BlindfoldDifficulty get selectedDifficulty =>
      SettingsService.instance.blindfoldDifficulty;

  int get blindfoldMoveThreshold => selectedDifficulty.hideThreshold;

  bool get isBlindfoldHidingActive {
    if (!isBlindfoldMode) return false;
    return _moveCount >= (_blindfoldToggleMoveCount + blindfoldMoveThreshold);
  }

  bool get shouldHidePieces {
    if (!isBlindfoldHidingActive) return false;
    return !_isRevealed;
  }

  int get revealCooldownRemaining {
    if (_revealLastUsedMoveCount == null) return 0;
    if (_moveCount < _revealLastUsedMoveCount!) {
      return 0;
    }
    final movesPlayedSince = _moveCount - _revealLastUsedMoveCount!;
    final remaining = 10 - movesPlayedSince;
    return remaining > 0 ? remaining : 0;
  }

  bool get canReveal {
    return shouldHidePieces && revealCooldownRemaining == 0;
  }

  String get revealButtonLabel {
    final remaining = revealCooldownRemaining;
    if (remaining > 0) {
      return 'Reveal ($remaining moves left)';
    }
    return 'Reveal Pieces';
  }

  void _revealPiecesTemporarily() {
    setState(() {
      _isRevealed = true;
      _revealLastUsedMoveCount = _moveCount;
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

  void _confirmResign() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resign Game?'),
          content: const Text(
            'Are you sure you want to resign the game? This will result in a loss.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Resign'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _executeResign();
      }
    });
  }

  void _confirmAbort() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Abort Game?'),
          content: const Text(
            'Are you sure you want to abort this game? The game will be canceled without any result.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Abort'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _executeAbort();
      }
    });
  }

  void _executeResign() {
    setState(() {
      _isSendingMove = true;
    });
    LichessService.instance
        .resignGame(widget.gameId)
        .then((_) {
          if (!mounted) return;
          setState(() {
            _isSendingMove = false;
          });
        })
        .catchError((err) {
          if (!mounted) return;
          setState(() {
            _isSendingMove = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to resign: ${err.toString().replaceAll('Exception: ', '')}',
              ),
              backgroundColor: Colors.red[800],
            ),
          );
        });
  }

  void _executeAbort() {
    setState(() {
      _isSendingMove = true;
    });
    LichessService.instance
        .abortGame(widget.gameId)
        .then((_) {
          if (!mounted) return;
          setState(() {
            _isSendingMove = false;
          });
        })
        .catchError((err) {
          if (!mounted) return;
          setState(() {
            _isSendingMove = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to abort: ${err.toString().replaceAll('Exception: ', '')}',
              ),
              backgroundColor: Colors.red[800],
            ),
          );
        });
  }

  void _handleDraw(bool accept) {
    setState(() {
      _isSendingMove = true;
    });
    LichessService.instance
        .drawGame(widget.gameId, accept)
        .then((_) {
          if (!mounted) return;
          setState(() {
            _isSendingMove = false;
            if (!accept) {
              _opponentDrawOffered = false;
            }
          });
        })
        .catchError((err) {
          if (!mounted) return;
          setState(() {
            _isSendingMove = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Draw action failed: ${err.toString().replaceAll('Exception: ', '')}',
              ),
              backgroundColor: Colors.red[800],
            ),
          );
        });
  }

  void _onSquareTap(int actualRowIndex, int actualColIndex, String label) {
    if (_isSendingMove) return;

    // Clear any existing snack bars to prevent queueing delay
    ScaffoldMessenger.of(context).clearSnackBars();

    final isDeselect = _selectedSquare == label;
    final isGuessAttempt =
        shouldHidePieces &&
        !_highlightedSquares.contains((actualRowIndex, actualColIndex)) &&
        !isDeselect;
    if (isGuessAttempt) {
      final tappedPiece = _chessEngineService.pieceAt(
        actualRowIndex,
        actualColIndex,
      );
      final isCorrect =
          tappedPiece != null && (tappedPiece.pieceColor == _playerColor);

      setState(() {
        totalGuesses++;
        if (isCorrect) {
          correctGuesses++;
          _triggerFlash(actualRowIndex, actualColIndex, 'green');
        } else {
          _triggerFlash(actualRowIndex, actualColIndex, 'red');
          AudioService.instance.playIncorrectGuess();
        }
      });
    }

    final tappedPiece = _chessEngineService.pieceAt(
      actualRowIndex,
      actualColIndex,
    );
    final isCurrentPlayersPiece =
        tappedPiece != null &&
        (tappedPiece.pieceColor == _chessEngineService.activeTurn) &&
        (tappedPiece.pieceColor == _playerColor);

    if (_selectedSquare == label) {
      // Deselect
      setState(() {
        _selectedSquare = null;
        _selectedRow = null;
        _selectedCol = null;
        _highlightedSquares = const [];
      });
    } else if (_highlightedSquares.contains((actualRowIndex, actualColIndex))) {
      // It is a legal destination selected in the highlighted squares
      final piece = _chessEngineService.pieceAt(_selectedRow!, _selectedCol!);
      final isPawn = piece?.pieceType == PieceType.pawn;
      final isPromotionRow =
          (piece?.pieceColor == PieceColor.white && actualRowIndex == 0) ||
          (piece?.pieceColor == PieceColor.black && actualRowIndex == 7);

      if (isPawn && isPromotionRow) {
        final movingColor = piece!.pieceColor;
        final fromR = _selectedRow!;
        final fromC = _selectedCol!;
        final toR = actualRowIndex;
        final toC = actualColIndex;

        // Clear active selection states before displaying dialog
        setState(() {
          _selectedSquare = null;
          _selectedRow = null;
          _selectedCol = null;
          _highlightedSquares = const [];
        });

        // Show promotion dialog asynchronously
        _showPromotionDialog(movingColor).then((choice) {
          if (!mounted) return;
          if (choice != null) {
            _transmitMove(fromR, fromC, toR, toC, promotion: choice);
          }
        });
      } else {
        // Standard move execution
        _transmitMove(
          _selectedRow!,
          _selectedCol!,
          actualRowIndex,
          actualColIndex,
        );
      }
    } else {
      // Non-highlighted tap
      if (isCurrentPlayersPiece) {
        // Select / Reselect
        setState(() {
          _selectedSquare = label;
          _selectedRow = actualRowIndex;
          _selectedCol = actualColIndex;
          _highlightedSquares = _chessEngineService.legalDestinationsFrom(
            actualRowIndex,
            actualColIndex,
          );
        });
      } else {
        // Tap an empty or opponent piece when not highlighting
        setState(() {
          _selectedSquare = null;
          _selectedRow = null;
          _selectedCol = null;
          _highlightedSquares = const [];
        });
      }
    }
  }

  void _transmitMove(
    int fromRow,
    int fromCol,
    int toRow,
    int toCol, {
    String? promotion,
  }) {
    final fromFile = String.fromCharCode('a'.codeUnitAt(0) + fromCol);
    final fromRank = (8 - fromRow).toString();
    final toFile = String.fromCharCode('a'.codeUnitAt(0) + toCol);
    final toRank = (8 - toRow).toString();
    String uci = '$fromFile$fromRank$toFile$toRank';
    if (promotion != null) {
      uci += promotion.toLowerCase();
    }

    setState(() {
      _isSendingMove = true;
      // Optimistically clear active selections
      _selectedSquare = null;
      _selectedRow = null;
      _selectedCol = null;
      _highlightedSquares = const [];
    });

    LichessService.instance
        .sendMove(widget.gameId, uci)
        .then((_) {
          if (!mounted) return;
          DiagnosticRecorder.instance.updateLastRecordExecution(success: true);
          setState(() {
            _isSendingMove = false;
            lastMoveTime = DateTime.now();
          });
        })
        .catchError((err) {
          if (!mounted) return;
          DiagnosticRecorder.instance.updateLastRecordExecution(
            success: false,
            error: 'Move rejected: ${err.toString()}',
          );
          setState(() {
            _isSendingMove = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Move rejected: ${err.toString().replaceAll('Exception: ', '')}',
              ),
              backgroundColor: Colors.red[800],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('--------------------------------------------------');
    debugPrint('STEP 9');
    debugPrint('--------------------------------------------------');
    debugPrint('Board displayed with FEN: ${_chessEngineService.fen}');

    final theme = Theme.of(context);
    final isMyTurn =
        !_isLoading &&
        !_connectionLost &&
        !_gameStatus.startsWith('Game Over') &&
        _chessEngineService.activeTurn == _playerColor;

    final turn = _chessEngineService.activeTurn;
    final isGameOver =
        _gameStatus.startsWith('Game Over') ||
        _chessEngineService.inCheckmate ||
        _chessEngineService.inStalemate;

    final opponentIsActiveTurn = !isGameOver && (turn != _playerColor);
    final playerIsActiveTurn = !isGameOver && (turn == _playerColor);

    final opponentTimeMs = _playerColor == PieceColor.white
        ? _blackTimeMs
        : _whiteTimeMs;
    final playerTimeMs = _playerColor == PieceColor.white
        ? _whiteTimeMs
        : _blackTimeMs;

    final opponentLowTime = opponentTimeMs < 30000;
    final playerLowTime = playerTimeMs < 30000;

    final isDark = theme.brightness == Brightness.dark;

    Color getClockBg(bool isActive, bool isLow) {
      if (_connectionLost) {
        return isDark ? Colors.grey[800]! : Colors.grey[200]!;
      }
      if (isLow) return isDark ? const Color(0x33B71C1C) : Colors.red[50]!;
      if (isActive) {
        return isDark ? const Color(0x33673AB7) : Colors.deepPurple[50]!;
      }
      return isDark ? Colors.grey[800]! : Colors.grey[100]!;
    }

    Border getClockBorder(bool isActive, bool isLow) {
      if (_connectionLost) return Border.all(color: Colors.grey[500]!);
      if (isActive) return Border.all(color: Colors.deepPurple, width: 2.0);
      if (isLow) return Border.all(color: Colors.red, width: 1.0);
      return Border.all(
        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        width: 1.0,
      );
    }

    Color getClockTextColor(bool isActive, bool isLow) {
      if (_connectionLost) return Colors.grey[500]!;
      if (isLow) return Colors.red[700]!;
      if (isActive) {
        return isDark ? Colors.deepPurple[200]! : Colors.deepPurple[900]!;
      }
      return isDark ? Colors.white : Colors.grey[800]!;
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _handleMidGameExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lichess Live Game'),
          backgroundColor: theme.colorScheme.inversePrimary,
          actions: [
            if (!_isLoading &&
                !_connectionLost &&
                !_gameStatus.startsWith('Game Over'))
              PopupMenuButton<String>(
                key: const ValueKey('game_actions_menu'),
                onSelected: (value) {
                  if (value == 'resign') {
                    _confirmResign();
                  } else if (value == 'abort') {
                    _confirmAbort();
                  } else if (value == 'offer_draw') {
                    _handleDraw(true);
                  } else if (value == 'accept_draw') {
                    _handleDraw(true);
                  } else if (value == 'decline_draw') {
                    _handleDraw(false);
                  }
                },
                itemBuilder: (BuildContext context) {
                  final isAbortable = _moveCount < 2;
                  return [
                    if (_opponentDrawOffered) ...[
                      const PopupMenuItem<String>(
                        value: 'accept_draw',
                        key: ValueKey('action_accept_draw'),
                        child: Row(
                          children: [
                            Icon(Icons.check, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Accept Draw'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'decline_draw',
                        key: ValueKey('action_decline_draw'),
                        child: Row(
                          children: [
                            Icon(Icons.close, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Decline Draw'),
                          ],
                        ),
                      ),
                    ] else
                      const PopupMenuItem<String>(
                        value: 'offer_draw',
                        key: ValueKey('action_offer_draw'),
                        child: Row(
                          children: [
                            Icon(Icons.handshake, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Offer Draw'),
                          ],
                        ),
                      ),
                    const PopupMenuItem<String>(
                      value: 'resign',
                      key: ValueKey('action_resign'),
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Resign'),
                        ],
                      ),
                    ),
                    if (isAbortable)
                      const PopupMenuItem<String>(
                        value: 'abort',
                        key: ValueKey('action_abort'),
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Abort Game'),
                          ],
                        ),
                      ),
                  ];
                },
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading live game stream...'),
                  ],
                ),
              )
            : SafeArea(
                child: Column(
                  children: [
                    // Opponent stats header card
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.smart_toy,
                                color: Colors.deepPurple,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _opponentName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 2,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'Playing as ${_playerColor == PieceColor.white ? "Black" : "White"}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '•',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _gameStatus,
                                          style: const TextStyle(
                                            color: Colors.deepPurple,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: getClockBg(
                                    opponentIsActiveTurn,
                                    opponentLowTime,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: getClockBorder(
                                    opponentIsActiveTurn,
                                    opponentLowTime,
                                  ),
                                ),
                                child: Text(
                                  _connectionLost
                                      ? 'Paused'
                                      : _formatTime(opponentTimeMs),
                                  key: const ValueKey('opponent_clock'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: getClockTextColor(
                                      opponentIsActiveTurn,
                                      opponentLowTime,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_connectionLost)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 4.0,
                        ),
                        child: Card(
                          color: Colors.red[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wifi_off,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Connection Lost',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _errorMessage ??
                                            'The connection to Lichess was interrupted.',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _startStreaming,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text(
                                    'Reconnect',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (_isSendingMove)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: LinearProgressIndicator(),
                      ),

                    // Reused Chessboard widget in interactive / readOnly mode
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ChessBoard(
                                  chessEngineService: _chessEngineService,
                                  isWhitePerspective:
                                      _playerColor == PieceColor.white,
                                  shouldHidePieces: shouldHidePieces,
                                  highlightedSquares: _highlightedSquares,
                                  lastMoveStart: _lastMoveStart,
                                  lastMoveEnd: _lastMoveEnd,
                                  checkedKingCoords: _checkedKingCoords,
                                  selectedSquare: _selectedSquare,
                                  flashStates: _flashStates,
                                  readOnly:
                                      !isMyTurn ||
                                      _isSendingMove ||
                                      _gameStatus.startsWith('Game Over'),
                                  onSquareTap: _onSquareTap,
                                ),
                                if (isBlindfoldMode) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        key: const ValueKey('reveal_button'),
                                        onPressed: !canReveal
                                            ? null
                                            : _revealPiecesTemporarily,
                                        child: Text(revealButtonLabel),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Memory Score: $correctGuesses / $totalGuesses (${totalGuesses > 0 ? (correctGuesses * 100 ~/ totalGuesses) : 0}%)',
                                    key: const ValueKey('memory_score_text'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                // Blindfold Toggle switch and Difficulty chips
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    const Text(
                                      'Normal',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Switch(
                                      key: const ValueKey('blindfold_switch'),
                                      value: isBlindfoldMode,
                                      onChanged: (value) {
                                        SettingsService.instance
                                            .setBlindfoldMode(value);
                                        setState(() {
                                          if (value) {
                                            _blindfoldToggleMoveCount =
                                                _moveCount;
                                          }
                                          totalGuesses = 0;
                                          correctGuesses = 0;
                                          _isRevealed = false;
                                          _revealLastUsedMoveCount = null;
                                          _revealTimer?.cancel();
                                        });
                                      },
                                      activeThumbColor: Colors.deepPurple,
                                    ),
                                    const Text(
                                      'Blindfold',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isBlindfoldMode) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      ChoiceChip(
                                        key: const ValueKey('chip_easy'),
                                        label: const Text(
                                          'Easy',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        selected:
                                            selectedDifficulty ==
                                            BlindfoldDifficulty.easy,
                                        onSelected: (bool selected) {
                                          if (selected) {
                                            SettingsService.instance
                                                .setBlindfoldDifficulty(
                                                  BlindfoldDifficulty.easy,
                                                );
                                            setState(() {});
                                          }
                                        },
                                        selectedColor: Colors.deepPurple,
                                        backgroundColor: Colors.deepPurple
                                            .withValues(alpha: 0.1),
                                        labelStyle: TextStyle(
                                          color:
                                              selectedDifficulty ==
                                                  BlindfoldDifficulty.easy
                                              ? Colors.white
                                              : Colors.deepPurple,
                                        ),
                                      ),
                                      ChoiceChip(
                                        key: const ValueKey('chip_medium'),
                                        label: const Text(
                                          'Medium',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        selected:
                                            selectedDifficulty ==
                                            BlindfoldDifficulty.medium,
                                        onSelected: (bool selected) {
                                          if (selected) {
                                            SettingsService.instance
                                                .setBlindfoldDifficulty(
                                                  BlindfoldDifficulty.medium,
                                                );
                                            setState(() {});
                                          }
                                        },
                                        selectedColor: Colors.deepPurple,
                                        backgroundColor: Colors.deepPurple
                                            .withValues(alpha: 0.1),
                                        labelStyle: TextStyle(
                                          color:
                                              selectedDifficulty ==
                                                  BlindfoldDifficulty.medium
                                              ? Colors.white
                                              : Colors.deepPurple,
                                        ),
                                      ),
                                      ChoiceChip(
                                        key: const ValueKey('chip_hard'),
                                        label: const Text(
                                          'Hard',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        selected:
                                            selectedDifficulty ==
                                            BlindfoldDifficulty.hard,
                                        onSelected: (bool selected) {
                                          if (selected) {
                                            SettingsService.instance
                                                .setBlindfoldDifficulty(
                                                  BlindfoldDifficulty.hard,
                                                );
                                            setState(() {});
                                          }
                                        },
                                        selectedColor: Colors.deepPurple,
                                        backgroundColor: Colors.deepPurple
                                            .withValues(alpha: 0.1),
                                        labelStyle: TextStyle(
                                          color:
                                              selectedDifficulty ==
                                                  BlindfoldDifficulty.hard
                                              ? Colors.white
                                              : Colors.deepPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Player stats card (Bottom)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: Colors.deepPurple,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      LichessService.instance.username ?? 'You',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Playing as ${_playerColor == PieceColor.white ? "White" : "Black"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: getClockBg(
                                    playerIsActiveTurn,
                                    playerLowTime,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: getClockBorder(
                                    playerIsActiveTurn,
                                    playerLowTime,
                                  ),
                                ),
                                child: Text(
                                  _connectionLost
                                      ? 'Paused'
                                      : _formatTime(playerTimeMs),
                                  key: const ValueKey('player_clock'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: getClockTextColor(
                                      playerIsActiveTurn,
                                      playerLowTime,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    VoiceCommandWidget(
                      isEnabled: isMyTurn,
                      onCommand: (spokenText, {sttConfidence = 1.0}) {
                        final cleanSpoken = spokenText.toLowerCase().trim();

                        // Voice Undo Check
                        final undoKeywords = {
                          'undo',
                          'cancel',
                          'wrong',
                          'stop',
                        };
                        if (undoKeywords.contains(cleanSpoken)) {
                          if (_chessEngineService.getHistory().isNotEmpty) {
                            final timeSinceLastMove = lastMoveTime != null
                                ? DateTime.now().difference(lastMoveTime!)
                                : const Duration(seconds: 999);
                            if (timeSinceLastMove.inSeconds <=
                                VoiceConfidenceConfig.undoWindowSeconds) {
                              final messenger = ScaffoldMessenger.of(context);
                              LichessService.instance
                                  .requestTakeback(widget.gameId)
                                  .then((_) {
                                    if (!mounted) return;
                                    messenger.clearSnackBars();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Takeback requested.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    tts.speak('Takeback requested.');
                                  })
                                  .catchError((e) {
                                    if (!mounted) return;
                                    messenger.clearSnackBars();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Takeback request failed: $e',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  });
                              setState(() {
                                pendingUndoConfirmation = false;
                              });
                            } else {
                              setState(() {
                                pendingUndoConfirmation = true;
                              });
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Are you sure you want to request a takeback?',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              tts.speak(
                                'Are you sure you want to request a takeback?',
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No moves to undo.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            tts.speak('No moves to undo.');
                          }
                          return;
                        }

                        final confirmations = {
                          'yes',
                          'yeah',
                          'sure',
                          'correct',
                          'confirm',
                          'ok',
                        };
                        if (confirmations.contains(cleanSpoken)) {
                          if (pendingUndoConfirmation) {
                            setState(() {
                              pendingUndoConfirmation = false;
                            });
                            final messenger = ScaffoldMessenger.of(context);
                            LichessService.instance
                                .requestTakeback(widget.gameId)
                                .then((_) {
                                  if (!mounted) return;
                                  messenger.clearSnackBars();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Takeback requested.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  tts.speak('Takeback requested.');
                                })
                                .catchError((e) {
                                  if (!mounted) return;
                                  messenger.clearSnackBars();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Takeback request failed: $e',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                });
                            return;
                          }
                          if (pendingMoveForClarification != null) {
                            final moveToPlay = pendingMoveForClarification!;
                            pendingMoveForClarification = null;
                            _executeMatchedMove(moveToPlay);
                            return;
                          }
                        }

                        // Reset pending undo confirmation on any other spoken command
                        setState(() {
                          pendingUndoConfirmation = false;
                        });

                        final legalMoves = _chessEngineService.getLegalMoves();
                        final matchedMove = VoiceCommandParser.parseCommand(
                          spokenText,
                          legalMoves,
                          sttConfidence: sttConfidence ?? 1.0,
                          boardFen: _chessEngineService.fen,
                        );

                        if (matchedMove != null) {
                          if (matchedMove.containsKey('error')) {
                            final errorMsg = matchedMove['error'] as String;
                            if (matchedMove.containsKey('clarificationMove')) {
                              pendingMoveForClarification =
                                  matchedMove['clarificationMove']
                                      as Map<String, dynamic>;
                            } else {
                              pendingMoveForClarification = null;
                            }

                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            tts.speak(errorMsg);
                            return;
                          }

                          pendingMoveForClarification = null;
                          _executeMatchedMove(matchedMove);
                        } else {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Couldn't understand that move, try again or tap to move",
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),

                    // Footer stats & actions
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Moves Played: $_moveCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Exit Game'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _executeMatchedMove(Map<String, dynamic> move) {
    final fromStr = move['from'] as String;
    final toStr = move['to'] as String;
    final promotion = move['promotion'] as String?;

    final fromFile = fromStr[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final fromRow = 8 - int.parse(fromStr[1]);
    final toFile = toStr[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRow = 8 - int.parse(toStr[1]);

    _transmitMove(fromRow, fromFile, toRow, toFile, promotion: promotion);

    final pMap = {
      'n': 'Knight',
      'r': 'Rook',
      'q': 'Queen',
      'b': 'Bishop',
      'k': 'King',
      'p': 'Pawn',
    };
    final pieceName = pMap[move['piece']] ?? 'Pawn';
    final String confirmationText;
    final san = move['san'] as String? ?? '';
    if (san.startsWith('O-O-O')) {
      confirmationText = 'Castles queenside';
    } else if (san.startsWith('O-O')) {
      confirmationText = 'Castles kingside';
    } else if (pieceName == 'Pawn') {
      confirmationText = toStr;
    } else {
      confirmationText = '$pieceName to $toStr';
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(confirmationText),
        duration: const Duration(seconds: 2),
      ),
    );
    tts.speak(confirmationText);
  }
}
