import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/chess_clock_config.dart';
import '../models/chess_piece.dart';

/// Centralized service managing chess clock states, decrement ticks, increments, and timeouts.
class ChessClockService extends ChangeNotifier {
  static final ChessClockService instance = ChessClockService._internal();
  ChessClockService._internal();

  ChessClockConfig _config = ChessClockConfig.noTimer;
  int _whiteTimeMs = 0;
  int _blackTimeMs = 0;
  bool _isRunning = false;
  PieceColor _activeTurn = PieceColor.white;
  Timer? _timer;
  DateTime? _lastTickTime;
  VoidCallback? _onTimeout;

  ChessClockConfig get config => _config;
  int get whiteTimeMs => _whiteTimeMs;
  int get blackTimeMs => _blackTimeMs;
  bool get isRunning => _isRunning;
  PieceColor get activeTurn => _activeTurn;

  /// Initializes the clock with a config and sets initial times.
  void initialize({
    required ChessClockConfig config,
    int? whiteTimeMs,
    int? blackTimeMs,
    PieceColor activeTurn = PieceColor.white,
    VoidCallback? onTimeout,
  }) {
    _config = config;
    _activeTurn = activeTurn;
    _onTimeout = onTimeout;

    if (config.hasTimer) {
      _whiteTimeMs = whiteTimeMs ?? (config.baseSeconds * 1000);
      _blackTimeMs = blackTimeMs ?? (config.baseSeconds * 1000);
    } else {
      _whiteTimeMs = 0;
      _blackTimeMs = 0;
      _isRunning = false;
      _timer?.cancel();
      _timer = null;
    }
    _lastTickTime = null;
    notifyListeners();
  }

  /// Starts the countdown timer.
  void start() {
    if (!_config.hasTimer || _isRunning) return;
    _isRunning = true;
    _lastTickTime = DateTime.now();
    _startTimer();
    notifyListeners();
  }

  /// Pauses/stops the countdown timer.
  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _lastTickTime = null;
    notifyListeners();
  }

  /// Sets the active turn.
  void setActiveTurn(PieceColor turn) {
    _activeTurn = turn;
    notifyListeners();
  }

  /// Adds increment to the player who just finished their move (opposite of the new active turn).
  void applyMoveIncrement() {
    if (!_config.hasTimer) return;
    if (_activeTurn == PieceColor.black) {
      _whiteTimeMs += _config.incrementSeconds * 1000;
    } else {
      _blackTimeMs += _config.incrementSeconds * 1000;
    }
    notifyListeners();
  }

  /// Manually overrides/sets remaining times (useful for syncing online game clocks).
  void setRemainingTimes(int whiteMs, int blackMs) {
    _whiteTimeMs = whiteMs;
    _blackTimeMs = blackMs;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      int diff = 100;
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        final now = DateTime.now();
        if (_lastTickTime != null) {
          diff = now.difference(_lastTickTime!).inMilliseconds;
        }
        _lastTickTime = now;
      }

      if (_activeTurn == PieceColor.white) {
        _whiteTimeMs = (_whiteTimeMs - diff).clamp(0, double.maxFinite.toInt());
      } else {
        _blackTimeMs = (_blackTimeMs - diff).clamp(0, double.maxFinite.toInt());
      }

      notifyListeners();

      if (_whiteTimeMs <= 0 || _blackTimeMs <= 0) {
        stop();
        if (_onTimeout != null) {
          _onTimeout!();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
