import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chess_piece.dart';
import '../services/chess_engine_service.dart';
import '../services/lichess_service.dart';
import '../services/chess_clock_service.dart';
import '../models/lichess_connection_state.dart';
import '../models/chess_clock_config.dart';
import '../services/lichess_api_client.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/statistics_service.dart';
import '../services/diagnostic_recorder.dart';
import '../widgets/chess_board.dart';
import '../widgets/voice_command_widget.dart';
import '../services/voice_pipeline_service.dart';
import '../services/accessibility_settings_service.dart';
import '../services/tts_service.dart';
import '../services/haptic_service.dart';
import '../utils/chess_speech_synthesizer.dart';

enum OnlineConnectionState {
  connected,
  reconnecting,
  syncing,
  disconnected,
}

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

class _LiveGameScreenState extends State<LiveGameScreen> with WidgetsBindingObserver implements VoicePipelineDelegate {
  final ChessEngineService _chessEngineService = ChessEngineService();
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  int _reconnectDelaySec = 2;
  Timer? _reconnectTimer;
  bool _myDrawOffered = false;
  
  OnlineConnectionState _onlineConnectionState = OnlineConnectionState.reconnecting;
  int _reconnectAttempts = 0;
  bool _isConnecting = false;

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
  bool _isVoiceMoveExecuted = false;
  List<(int, int)> _highlightedSquares = const [];
  String? _selectedSquare;
  int? _selectedRow;
  int? _selectedCol;

  void _announceMoveAndState(Map<String, dynamic> move, {bool isVoice = false}) {
    final flags = move['flags'] as String? ?? '';
    final isCapture = flags.contains('c') || flags.contains('e');
    final isPromotion = move['promotion'] != null;
    final isCheck = _chessEngineService.inCheck;
    final isCheckmate = _chessEngineService.inCheckmate;
    final isStalemate = _chessEngineService.inStalemate;
    final isDraw = _chessEngineService.inDraw;

    // 1. Play sound feedback
    final isGameOverStatus = isCheckmate || isStalemate || isDraw;
    if (isGameOverStatus) {
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
    if (isGameOverStatus) {
      HapticService.triggerGameOver();
    } else if (isCheck) {
      HapticService.triggerCheck();
    } else {
      HapticService.triggerSuccessfulMove();
    }

    // 3. Spoken feedback
    final settings = AccessibilitySettingsService.instance;
    if (settings.speechEnabled && !isVoice) {
      final moverColor = _chessEngineService.activeTurn == PieceColor.white 
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
        final nextTurnStr = _chessEngineService.activeTurn == PieceColor.white ? "White's turn." : "Black's turn.";
        if (settings.verbosity == VerbosityLevel.detailed) {
          text += '. $nextTurnStr';
        }
      }

      TtsService.instance.speak(text, priority: AnnouncementPriority.normal);
    }
  }

  // Clock state variables
  late final ChessClockService _clockService;

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
    VoicePipelineService.instance.setDelegate(this);
    _clockService = ChessClockService.instance;
    _clockService.addListener(_onClockTick);
    _saveActiveGameId();
    _startStreaming();
  }

  void _onClockTick() {
    if (mounted) {
      setState(() {});
    }
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

  Future<void> _saveActiveGameId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lichess_active_game_id', widget.gameId);
    debugPrint('[Resilience] Saved active online game ID: ${widget.gameId}');
  }

  Future<void> _clearActiveGameId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lichess_active_game_id');
    debugPrint('[Resilience] Cleared active online game ID');
  }

  void _startStreaming({bool isReconnecting = false}) {
    if (_isConnecting) {
      debugPrint('[Resilience] Already connecting, ignoring concurrent request to avoid race condition.');
      return;
    }
    _isConnecting = true;

    _reconnectTimer?.cancel();

    if (isReconnecting) {
      _reconnectAttempts++;
      if (_reconnectAttempts > 5) {
        debugPrint('[Resilience] Maximum automatic reconnect attempts (5) reached.');
        setState(() {
          _onlineConnectionState = OnlineConnectionState.disconnected;
          _connectionLost = true;
          _isLoading = false;
          _errorMessage = 'Connection failed after 5 attempts.';
        });
        TtsService.instance.speak("Connection failed. Please reconnect manually.", priority: AnnouncementPriority.high);
        _isConnecting = false;
        return;
      }
    } else {
      _reconnectAttempts = 0;
    }

    setState(() {
      _onlineConnectionState = OnlineConnectionState.reconnecting;
      if (!isReconnecting) {
        _isLoading = true;
      }
      _errorMessage = null;
      _connectionLost = true;
    });

    _clockService.stop();
    _streamSubscription?.cancel();

    try {
      _streamSubscription = LichessService.instance
          .streamGameState(widget.gameId)
          .listen(
            _handleStreamEvent,
            onError: _handleStreamError,
            onDone: _handleStreamDone,
            cancelOnError: true,
          );
    } catch (e) {
      _handleStreamError(e);
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleAutomaticReconnect() {
    _reconnectTimer?.cancel();
    if (_gameStatus.startsWith('Game Over') || 
        _chessEngineService.inCheckmate || 
        _chessEngineService.inStalemate) {
      return;
    }
    debugPrint('Scheduling automatic reconnect in $_reconnectDelaySec seconds...');
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySec), () {
      if (!mounted) return;
      _reconnectDelaySec = (_reconnectDelaySec * 2).clamp(2, 16);
      _startStreaming(isReconnecting: true);
    });
  }

  void _handleStreamEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final type = event['type'] as String?;

    if (type == 'gameFull' || type == 'gameState') {
      _reconnectAttempts = 0;
      _reconnectDelaySec = 2;
      _reconnectTimer?.cancel();

      final wasLost = _connectionLost || _onlineConnectionState != OnlineConnectionState.connected;
      if (wasLost) {
        setState(() {
          _connectionLost = false;
          _onlineConnectionState = OnlineConnectionState.connected;
        });
        TtsService.instance.speak("Reconnected. Board synchronized.", priority: AnnouncementPriority.high);
      }
    }

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
      final wtime = state['wtime'] as int? ?? 0;
      final btime = state['btime'] as int? ?? 0;
      final hasClock = state['wtime'] != null;

      final clockData = event['clock'] ?? {};
      final limit = clockData['limit'] as int? ?? 0;
      final increment = clockData['increment'] as int? ?? 0;

      _clockService.initialize(
        config: ChessClockConfig(
          label: 'Live Clock',
          baseSeconds: limit,
          incrementSeconds: increment,
          hasTimer: hasClock,
        ),
        whiteTimeMs: wtime,
        blackTimeMs: btime,
        activeTurn: _chessEngineService.activeTurn,
      );
      if (hasClock) {
        _clockService.start();
      }

      final wdraw = state['wdraw'] == true;
      final bdraw = state['bdraw'] == true;
      final myOffer = _playerColor == PieceColor.white ? wdraw : bdraw;
      final opponentOffer = _playerColor == PieceColor.white ? bdraw : wdraw;

      if (opponentOffer && !_opponentDrawOffered) {
        _opponentDrawOffered = true;
        TtsService.instance.speak("Opponent offers a draw.", priority: AnnouncementPriority.high);
      } else if (!opponentOffer && _opponentDrawOffered) {
        _opponentDrawOffered = false;
      }

      if (_myDrawOffered && !myOffer) {
        _myDrawOffered = false;
        TtsService.instance.speak("Draw offer declined.", priority: AnnouncementPriority.normal);
      }

      final movesStr = (state['moves'] as String?) ?? '';
      _reconcileAndVerifyState(movesStr, state);
      _applyMoves(movesStr);

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      final status = state['status'] as String? ?? 'started';
      final winner = state['winner'] as String?;
      _updateStatus(status, winner);
    } else if (type == 'gameState') {
      final wtime = event['wtime'] as int? ?? _clockService.whiteTimeMs;
      final btime = event['btime'] as int? ?? _clockService.blackTimeMs;
      _clockService.setRemainingTimes(wtime, btime);
      _clockService.setActiveTurn(_chessEngineService.activeTurn);

      final wdraw = event['wdraw'] == true;
      final bdraw = event['bdraw'] == true;
      final myOffer = _playerColor == PieceColor.white ? wdraw : bdraw;
      final opponentOffer = _playerColor == PieceColor.white ? bdraw : wdraw;

      if (opponentOffer && !_opponentDrawOffered) {
        _opponentDrawOffered = true;
        TtsService.instance.speak("Opponent offers a draw.", priority: AnnouncementPriority.high);
      } else if (!opponentOffer && _opponentDrawOffered) {
        _opponentDrawOffered = false;
      }

      if (_myDrawOffered && !myOffer) {
        _myDrawOffered = false;
        TtsService.instance.speak("Draw offer declined.", priority: AnnouncementPriority.normal);
      }

      final movesStr = (event['moves'] as String?) ?? '';
      _reconcileAndVerifyState(movesStr, event);
      _applyMoves(movesStr);

      final status = event['status'] as String? ?? 'started';
      final winner = event['winner'] as String?;
      _updateStatus(status, winner);
    } else if (type == 'opponentGone') {
      final gone = event['gone'] == true;
      if (gone) {
        TtsService.instance.speak("Opponent disconnected.", priority: AnnouncementPriority.high);
      } else {
        TtsService.instance.speak("Opponent reconnected.", priority: AnnouncementPriority.high);
      }
    }
  }

  void _reconcileAndVerifyState(String movesStr, Map<String, dynamic> state) {
    final tempEngine = ChessEngineService();
    final trimmed = movesStr.trim();
    if (trimmed.isNotEmpty) {
      final movesList = trimmed.split(' ');
      for (final uci in movesList) {
        if (uci.length >= 4) {
          tempEngine.makeUciMove(uci);
        }
      }
    }

    final fenMismatch = tempEngine.fen != _chessEngineService.fen;
    final turnMismatch = tempEngine.activeTurn != _chessEngineService.activeTurn;
    final countMismatch = (trimmed.isEmpty ? 0 : trimmed.split(' ').length) != _moveCount;

    if (fenMismatch || turnMismatch || countMismatch) {
      debugPrint('[Resilience] State verification mismatch detected! FEN: $fenMismatch, Turn: $turnMismatch, Count: $countMismatch. Resetting moveCount to force server state reconciliation.');
      _moveCount = -1; // Forces _applyMoves to fully replay from the server moves
    }
  }

  void _applyMoves(String movesStr) {
    final oldMoveCount = _moveCount;
    final trimmed = movesStr.trim();
    if (trimmed.isEmpty) {
      if (_moveCount != 0) {
        _chessEngineService.reset();
        _moveCount = 0;
        _lastMoveStart = null;
        _lastMoveEnd = null;
        _updateCheckedKing();
        if (mounted) setState(() {});
      }
      return;
    }

    final movesList = trimmed.split(' ');
    if (movesList.length == _moveCount) {
      return;
    }

    _chessEngineService.reset();
    _lastMoveStart = null;
    _lastMoveEnd = null;
    Map<String, dynamic>? executedMove;
    for (int i = 0; i < movesList.length; i++) {
      final uci = movesList[i];
      if (uci.length >= 4) {
        if (i == movesList.length - 1 &&
            oldMoveCount > 0 &&
            movesList.length > oldMoveCount) {
          final fromSq = uci.substring(0, 2);
          final toSq = uci.substring(2, 4);
          final legalMovesBefore = _chessEngineService.getLegalMoves();
          for (final m in legalMovesBefore) {
            if (m['from'] == fromSq && m['to'] == toSq) {
              executedMove = m;
              break;
            }
          }
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
      if (executedMove != null) {
        _announceMoveAndState(executedMove, isVoice: _isVoiceMoveExecuted);
      }
      _isVoiceMoveExecuted = false; // Reset voice flag
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
      'aborted',
    };
    final isGameOver = terminalStatuses.contains(status.toLowerCase());

    if (isGameOver && !_isGameStatsRecorded) {
      _clearActiveGameId();
      _isGameStatsRecorded = true;
      _clockService.stop();
      _reconnectTimer?.cancel();

      // Audio & Haptic GameOver feedback
      AudioService.instance.playGameOver();
      HapticService.triggerGameOver();

      final isDrawResult = (winner == null);

      if (status.toLowerCase() != 'aborted') {
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

      final myColorName = _playerColor == PieceColor.white ? 'white' : 'black';
      final isWinner = winner == myColorName;
      String ttsText = 'Game over.';

      switch (status.toLowerCase()) {
        case 'mate':
          ttsText = isWinner ? 'Checkmate. You win!' : 'Checkmate. Opponent wins.';
          break;
        case 'resign':
          ttsText = isWinner ? 'Opponent resigned. You win!' : 'You resigned. Opponent wins.';
          break;
        case 'draw':
          ttsText = 'Draw by agreement.';
          break;
        case 'stalemate':
          ttsText = 'Stalemate. Draw.';
          break;
        case 'timeout':
        case 'outoftime':
          ttsText = isWinner ? 'Time forfeit. You win!' : 'Time forfeit. Opponent wins.';
          break;
        case 'aborted':
          ttsText = 'Game aborted.';
          break;
        default:
          ttsText = 'Game over.';
      }

      TtsService.instance.speak(ttsText, priority: AnnouncementPriority.high);
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
    if (error is LichessNetworkException) {
      LichessService.instance.sessionManager.setConnectionState(LichessConnectionState.networkUnavailable);
    }
    _clockService.stop();
    final wasLost = _connectionLost;
    setState(() {
      _isLoading = false;
      _connectionLost = true;
      _errorMessage = LichessService.formatError(error);
    });
    if (!wasLost) {
      TtsService.instance.speak("Connection lost. Reconnecting.", priority: AnnouncementPriority.high);
    }
    _scheduleAutomaticReconnect();
  }

  void _handleStreamDone() {
    if (!mounted) return;
    _clockService.stop();
    final wasLost = _connectionLost;
    setState(() {
      _isLoading = false;
      _connectionLost = true;
      _errorMessage = 'Stream completed.';
    });
    if (!wasLost) {
      TtsService.instance.speak("Connection lost. Reconnecting.", priority: AnnouncementPriority.high);
    }
    _scheduleAutomaticReconnect();
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
    _clearActiveGameId();
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
    VoicePipelineService.instance.setDelegate(null);
    VoicePipelineService.instance.stopPipeline();
    _clockService.removeListener(_onClockTick);
    _clockService.stop();
    _streamSubscription?.cancel();
    _revealTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  // Public members for testing
  int get moveCount => _moveCount;
  OnlineConnectionState get onlineConnectionState => _onlineConnectionState;
  int get reconnectDelaySec => _reconnectDelaySec;
  void simulateStreamError(dynamic error) => _handleStreamError(error);
  void simulateStreamDone() => _handleStreamDone();
  void simulateManualExit() => _handleMidGameExit();

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
                'Failed to resign: ${LichessService.formatError(err)}',
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
                'Failed to abort: ${LichessService.formatError(err)}',
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
                'Draw action failed: ${LichessService.formatError(err)}',
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
    if (_isSendingMove) return;

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
          AudioService.instance.playIllegalMove();
          HapticService.triggerIllegalMove();
          final formattedErr = LichessService.formatError(err);
          TtsService.instance.speak("Move rejected: $formattedErr", priority: AnnouncementPriority.high);
          setState(() {
            _isSendingMove = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Move rejected: $formattedErr',
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
        ? _clockService.blackTimeMs
        : _clockService.whiteTimeMs;
    final playerTimeMs = _playerColor == PieceColor.white
        ? _clockService.whiteTimeMs
        : _clockService.blackTimeMs;

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

    Widget? connectionBanner;
    if (_onlineConnectionState == OnlineConnectionState.reconnecting) {
      connectionBanner = Container(
        color: Colors.orange[850],
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Reconnecting to Lichess... (Attempt $_reconnectAttempts of 5)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    } else if (_onlineConnectionState == OnlineConnectionState.syncing) {
      connectionBanner = Container(
        color: Colors.blue[800],
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Syncing game state with Lichess...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    } else if (_onlineConnectionState == OnlineConnectionState.disconnected) {
      connectionBanner = Container(
        color: Colors.red[800],
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'You are offline. Connection failed.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _startStreaming(isReconnecting: false),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[800],
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
      );
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
          title: Row(
            children: [
              const Text('Lichess Live Game'),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _onlineConnectionState == OnlineConnectionState.connected
                      ? Colors.green
                      : (_onlineConnectionState == OnlineConnectionState.disconnected
                          ? Colors.red
                          : Colors.orange),
                ),
              ),
            ],
          ),
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
                    ?connectionBanner,
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
                      onCommand: (_, {sttConfidence}) {},
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



  // ==========================================
  // VoicePipelineDelegate Overrides
  // ==========================================
  @override
  List<Map<String, dynamic>> getLegalMoves() => _chessEngineService.getLegalMoves();

  @override
  String getFen() => _chessEngineService.fen;

  @override
  bool makeMove(int fromRow, int fromCol, int toRow, int toCol, {String? promotion}) {
    final isMyTurn =
        !_isLoading &&
        !_connectionLost &&
        !_gameStatus.startsWith('Game Over') &&
        _chessEngineService.activeTurn == _playerColor;

    if (!isMyTurn || _isSendingMove) {
      return false;
    }
    _transmitMove(fromRow, fromCol, toRow, toCol, promotion: promotion);
    return true;
  }

  @override
  bool get canUndo => _chessEngineService.getHistory().isNotEmpty;

  @override
  void undo() {
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
        })
        .catchError((e) {
          if (!mounted) return;
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Takeback request failed: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        });
  }

  @override
  void onUndoSuccess() {}

  @override
  void onMoveSuccess(Map<String, dynamic> move, String confirmationText) {
    _isVoiceMoveExecuted = true;
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
    _executeResign();
  }

  @override
  void onDrawOffer() {
    _handleDraw(true);
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
    Navigator.of(context).pop();
  }

  @override
  void onRestartGame() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot restart a live Lichess game.'),
        duration: Duration(seconds: 2),
      ),
    );
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
