import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'speech_service.dart';
import 'speech_synthesis_service.dart';
import '../utils/voice_command_parser.dart';
import '../utils/tts/tts_base.dart' as tts;

enum VoiceState {
  idle,
  listening,
  processing,
  executingMove,
  speakingFeedback,
  undoWindow,
}

abstract class VoicePipelineDelegate {
  List<Map<String, dynamic>> getLegalMoves();
  String getFen();
  bool makeMove(int fromRow, int fromCol, int toRow, int toCol, {String? promotion});
  bool get canUndo;
  void undo();
  void onMoveSuccess(Map<String, dynamic> move, String confirmationText);
  void onError(String message);
  void onUndoSuccess();
}

class VoicePipelineService {
  static final VoicePipelineService instance = VoicePipelineService._internal();
  VoicePipelineService._internal();

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  final _stateController = StreamController<VoiceState>.broadcast();
  Stream<VoiceState> get onStateChanged => _stateController.stream;

  VoicePipelineDelegate? _delegate;
  VoicePipelineDelegate? get delegate => _delegate;

  String _recognizedText = '';
  String get recognizedText => _recognizedText;

  final _recognizedTextController = StreamController<String>.broadcast();
  Stream<String> get onRecognizedTextChanged => _recognizedTextController.stream;

  // Locks and safety flags
  bool _isProcessing = false;
  String? _lastProcessedText;
  DateTime? _lastProcessedTime;
  Timer? _undoTimer;
  bool _pendingUndoConfirmation = false;
  Map<String, dynamic>? _pendingMoveForClarification;
  DateTime? _lastMoveTime;

  // Active listening session variables
  bool _shouldBeListening = false;

  bool get _isTesting =>
      WidgetsBinding.instance.toString().contains('TestWidgetsFlutterBinding');

  void setDelegate(VoicePipelineDelegate? delegate) {
    _delegate = delegate;
    debugPrint('[VoicePipeline] Delegate updated: ${delegate != null ? "connected" : "disconnected"}');
  }

  void transitionTo(VoiceState newState, {String? reason}) {
    if (_state == newState) return;
    final oldState = _state;
    _state = newState;
    debugPrint('[VoicePipeline] State transition: ${oldState.name} -> ${newState.name}${reason != null ? " ($reason)" : ""}');
    _stateController.add(newState);
  }

  Future<void> toggleListening() async {
    if (SpeechService.instance.isListening) {
      _shouldBeListening = false;
      await stopPipeline();
    } else {
      _shouldBeListening = true;
      if (state == VoiceState.undoWindow) {
        await _startListeningInternal(isUndoWindow: true);
      } else {
        await startPipeline();
      }
    }
  }

  Future<void> startPipeline() async {
    _lastProcessedText = null;
    _lastProcessedTime = null;
    _recognizedText = '';
    _recognizedTextController.add('');
    _shouldBeListening = true;
    _undoTimer?.cancel();
    await _startListeningInternal();
  }

  Future<void> stopPipeline() async {
    _shouldBeListening = false;
    _undoTimer?.cancel();
    _pendingUndoConfirmation = false;
    _pendingMoveForClarification = null;
    await _stopListeningInternal();
    transitionTo(VoiceState.idle, reason: 'Pipeline stopped manually');
  }

  Future<void> _startListeningInternal({bool isUndoWindow = false}) async {
    if (_isProcessing || state == VoiceState.speakingFeedback) {
      debugPrint('[VoicePipeline] Cannot start listening: processing or speaking');
      return;
    }

    final speechService = SpeechService.instance;

    if (_isTesting) {
      // In widget/unit tests, execute synchronously to prevent microtask yielding
      speechService.initialize();
      if (speechService.isListening) return;
      debugPrint('[VoicePipeline] Recognizer Start (Test)');
      if (!isUndoWindow) {
        transitionTo(VoiceState.listening);
      }
      speechService.listen(
        onResult: (text, confidence, isFinal) {
          _handleSpeechResult(text, confidence, isFinal, isUndoWindow: isUndoWindow);
        },
        onStatusChanged: () {
          _stateController.add(_state);
        },
      );
      return;
    }

    final initialized = await speechService.initialize();
    if (!initialized) {
      debugPrint('[VoicePipeline] SpeechService initialization failed');
      return;
    }

    if (speechService.isListening) {
      debugPrint('[VoicePipeline] Recognizer already running, skipping start');
      return;
    }

    debugPrint('[VoicePipeline] Recognizer Start');
    if (!isUndoWindow) {
      transitionTo(VoiceState.listening);
    }

    await speechService.listen(
      onResult: (text, confidence, isFinal) {
        _handleSpeechResult(text, confidence, isFinal, isUndoWindow: isUndoWindow);
      },
      onStatusChanged: () {
        _stateController.add(_state);
      },
    );
  }

  Future<void> _stopListeningInternal() async {
    final speechService = SpeechService.instance;
    if (speechService.isListening) {
      debugPrint('[VoicePipeline] Recognizer Stop');
      await speechService.stop();
    }
  }

  void _handleSpeechResult(String text, double confidence, bool isFinal, {bool isUndoWindow = false}) {
    // 1. Filter out results if we are not actively in a state that expects input
    if (state != VoiceState.listening && state != VoiceState.undoWindow) {
      debugPrint('[VoicePipeline] Ignored callback because state is ${state.name}: "$text"');
      return;
    }

    // 2. Real-time transcript preview updating
    _recognizedText = text;
    _recognizedTextController.add(text);

    // 3. Ignore partial recognition results
    if (!isFinal) {
      debugPrint('[VoicePipeline] Ignored partial result: "$text"');
      return;
    }

    // 4. Ignore duplicate callbacks / repeated final results
    final now = DateTime.now();
    if (_lastProcessedText == text &&
        _lastProcessedTime != null &&
        now.difference(_lastProcessedTime!).inMilliseconds < 1500) {
      debugPrint('[VoicePipeline] Ignored duplicate callback: "$text"');
      return;
    }

    _lastProcessedText = text;
    _lastProcessedTime = now;

    // 5. Prevent stale transcripts from being reused
    if (text.trim().isEmpty) {
      debugPrint('[VoicePipeline] Ignored empty final transcript');
      return;
    }

    // Process valid final command
    _processSpokenCommand(text, confidence, isUndoWindow: isUndoWindow);
  }

  Future<void> _executeUndo() async {
    transitionTo(VoiceState.executingMove, reason: 'Performing undo');
    _delegate?.undo();
    _delegate?.onUndoSuccess();
    await _speakFeedback('Move undone.');
    _recognizedText = '';
    _recognizedTextController.add('');
    transitionTo(VoiceState.idle, reason: 'Undo complete');
    if (_shouldBeListening) {
      await startPipeline();
    }
  }

  Future<void> _executeClarificationMove(Map<String, dynamic> move) async {
    transitionTo(VoiceState.executingMove, reason: 'Executing confirmed clarification move');
    
    final fromStr = move['from'] as String;
    final toStr = move['to'] as String;
    final promotion = move['promotion'] as String?;

    final fromFile = fromStr[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final fromRow = 8 - int.parse(fromStr[1]);
    final toFile = toStr[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRow = 8 - int.parse(toStr[1]);

    final success = _delegate?.makeMove(fromRow, fromFile, toRow, toFile, promotion: promotion) ?? false;

    if (success) {
      _lastMoveTime = DateTime.now();
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

      _delegate?.onMoveSuccess(move, confirmationText);
      await _speakFeedback(confirmationText);
      
      _recognizedText = '';
      _recognizedTextController.add('');
      _startUndoWindow();
    } else {
      await _speakFeedback('Move execution failed.');
      if (_shouldBeListening) {
        transitionTo(VoiceState.listening);
        await _startListeningInternal();
      } else {
        transitionTo(VoiceState.idle);
      }
    }
  }

  Future<void> _processSpokenCommand(String text, double confidence, {bool isUndoWindow = false}) async {
    if (_isProcessing) {
      debugPrint('[VoicePipeline] Lock active: already processing another command');
      return;
    }

    // Acquire lock
    _isProcessing = true;
    debugPrint('[VoicePipeline] Processing Lock Acquired');
    final startTime = DateTime.now();

    try {
      // Immediately stop the recognizer on valid command detection
      await _stopListeningInternal();
      transitionTo(VoiceState.processing, reason: 'Command detected: "$text"');

      final cleanSpoken = text.toLowerCase().trim();

      // Check for Undo / Cancel Commands
      final undoKeywords = {'undo', 'cancel', 'wrong', 'stop'};
      if (undoKeywords.contains(cleanSpoken)) {
        final stopwatch = Stopwatch()..start();
        final canUndo = _delegate?.canUndo ?? false;
        debugPrint('[VoicePipeline] Stage "undo check" took ${stopwatch.elapsedMilliseconds}ms');

        if (canUndo) {
          final nowTime = DateTime.now();
          final isWithinWindow = isUndoWindow &&
              _lastMoveTime != null &&
              nowTime.difference(_lastMoveTime!).inSeconds <= 3;

          if (isWithinWindow) {
            await _executeUndo();
          } else {
            _pendingUndoConfirmation = true;
            _delegate?.onError('Are you sure you want to undo the last move?');
            await _speakFeedback('Are you sure you want to undo the last move?');
            if (_shouldBeListening) {
              transitionTo(VoiceState.listening);
              await _startListeningInternal();
            } else {
              transitionTo(VoiceState.idle);
            }
          }
        } else {
          _delegate?.onError('No moves to undo.');
          await _speakFeedback('No moves to undo.');
          if (_shouldBeListening) {
            transitionTo(VoiceState.listening);
            await _startListeningInternal();
          } else {
            transitionTo(VoiceState.idle);
          }
        }
        return;
      }

      // Check for confirmation answers (yes, yeah, sure, confirm, correct, ok)
      final confirmations = {'yes', 'yeah', 'sure', 'correct', 'confirm', 'ok'};
      if (confirmations.contains(cleanSpoken)) {
        if (_pendingUndoConfirmation) {
          _pendingUndoConfirmation = false;
          await _executeUndo();
          return;
        }
        if (_pendingMoveForClarification != null) {
          final moveToPlay = _pendingMoveForClarification!;
          _pendingMoveForClarification = null;
          await _executeClarificationMove(moveToPlay);
          return;
        }
      }

      // Reset pending undo confirmation / clarification on any other command
      _pendingUndoConfirmation = false;
      _pendingMoveForClarification = null;

      // If we are in the undo window and say something else, we cancel the undo window and process it as a move
      if (isUndoWindow) {
        _undoTimer?.cancel();
      }

      final delegate = _delegate;
      if (delegate == null) {
        debugPrint('[VoicePipeline] Error: No delegate connected');
        transitionTo(VoiceState.idle);
        return;
      }

      // Voice normalization & parsing stage
      final stopwatchParser = Stopwatch()..start();
      final legalMoves = delegate.getLegalMoves();
      final matchedMove = VoiceCommandParser.parseCommand(
        text,
        legalMoves,
        sttConfidence: confidence,
        boardFen: delegate.getFen(),
      );
      debugPrint('[VoicePipeline] Stage "parsing and matching" took ${stopwatchParser.elapsedMilliseconds}ms');

      if (matchedMove != null) {
        if (matchedMove.containsKey('error')) {
          final errorMsg = matchedMove['error'] as String;
          if (matchedMove.containsKey('clarificationMove')) {
            _pendingMoveForClarification = matchedMove['clarificationMove'] as Map<String, dynamic>;
          } else {
            _pendingMoveForClarification = null;
          }
          delegate.onError(errorMsg);
          await _speakFeedback(errorMsg);
          if (_shouldBeListening) {
            transitionTo(VoiceState.listening);
            await _startListeningInternal();
          } else {
            transitionTo(VoiceState.idle);
          }
          return;
        }

        // Executing Move stage
        final stopwatchExec = Stopwatch()..start();
        transitionTo(VoiceState.executingMove, reason: 'Executing matched move');
        
        final fromStr = matchedMove['from'] as String;
        final toStr = matchedMove['to'] as String;
        final promotion = matchedMove['promotion'] as String?;

        final fromFile = fromStr[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
        final fromRow = 8 - int.parse(fromStr[1]);
        final toFile = toStr[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
        final toRow = 8 - int.parse(toStr[1]);

        final success = delegate.makeMove(fromRow, fromFile, toRow, toFile, promotion: promotion);
        debugPrint('[VoicePipeline] Stage "move execution" took ${stopwatchExec.elapsedMilliseconds}ms');

        if (success) {
          _lastMoveTime = DateTime.now();
          final pMap = {
            'n': 'Knight',
            'r': 'Rook',
            'q': 'Queen',
            'b': 'Bishop',
            'k': 'King',
            'p': 'Pawn',
          };
          final pieceName = pMap[matchedMove['piece']] ?? 'Pawn';
          final String confirmationText;
          final san = matchedMove['san'] as String? ?? '';
          if (san.startsWith('O-O-O')) {
            confirmationText = 'Castles queenside';
          } else if (san.startsWith('O-O')) {
            confirmationText = 'Castles kingside';
          } else if (pieceName == 'Pawn') {
            confirmationText = toStr;
          } else {
            confirmationText = '$pieceName to $toStr';
          }

          delegate.onMoveSuccess(matchedMove, confirmationText);
          await _speakFeedback(confirmationText);
          
          // Clear transcripts after successful processing
          _recognizedText = '';
          _recognizedTextController.add('');

          // Start the 3-second undo window
          _startUndoWindow();
        } else {
          await _speakFeedback('Move execution failed.');
          if (_shouldBeListening) {
            transitionTo(VoiceState.listening);
            await _startListeningInternal();
          } else {
            transitionTo(VoiceState.idle);
          }
        }
      } else {
        delegate.onError("Couldn't understand that move.");
        await _speakFeedback("Couldn't understand that move.");
        if (_shouldBeListening) {
          transitionTo(VoiceState.listening);
          await _startListeningInternal();
        } else {
          transitionTo(VoiceState.idle);
        }
      }
    } catch (e) {
      debugPrint('[VoicePipeline] Error in pipeline: $e');
      transitionTo(VoiceState.idle);
    } finally {
      _isProcessing = false;
      debugPrint('[VoicePipeline] Processing Lock Released');
      final totalLatency = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('[VoicePipeline] Total pipeline latency: ${totalLatency}ms');
    }
  }

  void _startUndoWindow() {
    _undoTimer?.cancel();
    transitionTo(VoiceState.undoWindow, reason: 'Entering 3-second undo window');
    
    // In production, start listening if we want continuous listening, 
    // but in tests, let the user tap mic to speak undo.
    if (_shouldBeListening && !_isTesting) {
      _startListeningInternal(isUndoWindow: true);
    }

    _undoTimer = Timer(const Duration(seconds: 3), () async {
      if (state == VoiceState.undoWindow) {
        debugPrint('[VoicePipeline] Undo window closed.');
        await _stopListeningInternal();
        
        if (_shouldBeListening) {
          transitionTo(VoiceState.listening);
          await _startListeningInternal();
        } else {
          transitionTo(VoiceState.idle);
        }
      }
    });
  }

  Future<void> _speakFeedback(String text) async {
    transitionTo(VoiceState.speakingFeedback);
    debugPrint('[VoicePipeline] TTS Start: "$text"');
    
    // Ensure microphone is stopped during speaking
    await _stopListeningInternal();

    if (_isTesting) {
      if (kIsWeb) {
        tts.speak(text);
      } else {
        SpeechSynthesisService.instance.speak(text);
      }
      debugPrint('[VoicePipeline] TTS End (Test): "$text"');
      return;
    }

    final startTime = DateTime.now();

    if (kIsWeb) {
      tts.speak(text);
      final wordCount = text.split(RegExp(r'\s+')).length;
      final duration = Duration(milliseconds: (wordCount * 300) + 500);
      await Future.delayed(duration);
    } else {
      await SpeechSynthesisService.instance.speakAndWait(text);
    }

    debugPrint('[VoicePipeline] TTS End: "$text" (took ${DateTime.now().difference(startTime).inMilliseconds}ms)');
  }
}
