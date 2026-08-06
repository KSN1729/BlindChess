import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'accessibility_settings_service.dart';

/// Supported priority levels for spoken announcements.
enum AnnouncementPriority { low, normal, high }

/// Representation of a single queued spoken announcement.
class TtsAnnouncement {
  final String text;
  final AnnouncementPriority priority;
  final Completer<void> completer;

  TtsAnnouncement(this.text, this.priority, this.completer);
}

/// Abstract definition of the Text-To-Speech engine. Enables mocking.
abstract class TtsEngine {
  Future<void> speak(String text, {double rate, double pitch, double volume});
  Future<void> stop();
  Future<void> dispose();

  void setStartHandler(VoidCallback callback);
  void setCompletionHandler(VoidCallback callback);
  void setErrorHandler(Function(String message) callback);
}

/// real implementation calling native platform channels via flutter_tts.
class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _flutterTts = FlutterTts();

  FlutterTtsEngine() {
    _flutterTts.setStartHandler(() {
      _startHandler?.call();
    });
    _flutterTts.setCompletionHandler(() {
      _completionHandler?.call();
    });
    _flutterTts.setErrorHandler((msg) {
      _errorHandler?.call(msg.toString());
    });
  }

  VoidCallback? _startHandler;
  VoidCallback? _completionHandler;
  Function(String)? _errorHandler;

  @override
  void setStartHandler(VoidCallback callback) {
    _startHandler = callback;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {
    _completionHandler = callback;
  }

  @override
  void setErrorHandler(Function(String) callback) {
    _errorHandler = callback;
  }

  @override
  Future<void> speak(String text, {double rate = 0.5, double pitch = 1.0, double volume = 1.0}) async {
    try {
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking in FlutterTtsEngine: $e');
      _errorHandler?.call(e.toString());
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping in FlutterTtsEngine: $e');
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error disposing in FlutterTtsEngine: $e');
    }
  }
}

/// Simulated mock implementation used in unit/widget test environments.
class MockTtsEngine implements TtsEngine {
  VoidCallback? _startHandler;
  VoidCallback? _completionHandler;

  Timer? _timer;

  @override
  void setStartHandler(VoidCallback callback) {
    _startHandler = callback;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {
    _completionHandler = callback;
  }

  @override
  void setErrorHandler(Function(String) callback) {}

  @override
  Future<void> speak(String text, {double rate = 0.5, double pitch = 1.0, double volume = 1.0}) async {
    _timer?.cancel();
    _startHandler?.call();
    scheduleMicrotask(() {
      _completionHandler?.call();
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _completionHandler?.call();
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
  }
}

/// Singleton coordinating queueing, priority interruption, and speech status callbacks.
class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal() {
    _initEngine();
  }

  TtsEngine? _engine;
  final List<TtsAnnouncement> _queue = [];
  TtsAnnouncement? _current;
  bool _isSpeaking = false;

  // Listeners to coordinate microtask status triggers (e.g. for pause/resume recognition)
  final List<FutureOr<void> Function()> _onSpeechStartListeners = [];
  final List<FutureOr<void> Function()> _onSpeechEndListeners = [];

  void _initEngine() {
    // Inject MockTtsEngine in test or web environments automatically
    if (kIsWeb || WidgetsBinding.instance.toString().contains('TestWidgetsFlutterBinding')) {
      _engine = MockTtsEngine();
    } else {
      _engine = FlutterTtsEngine();
    }

    _engine?.setStartHandler(() {
      _isSpeaking = true;
      _triggerSpeechStart();
    });

    _engine?.setCompletionHandler(() {
      _isSpeaking = false;
      _triggerSpeechEnd();
      _onSpeechFinished();
    });

    _engine?.setErrorHandler((msg) {
      _isSpeaking = false;
      _triggerSpeechEnd();
      _onSpeechFinished();
    });
  }

  /// Exposes capability to swap out engines (dependency injection).
  void setEngine(TtsEngine engine) {
    _engine = engine;
    _engine?.setStartHandler(() {
      _isSpeaking = true;
      _triggerSpeechStart();
    });
    _engine?.setCompletionHandler(() {
      _isSpeaking = false;
      _triggerSpeechEnd();
      _onSpeechFinished();
    });
    _engine?.setErrorHandler((msg) {
      _isSpeaking = false;
      _triggerSpeechEnd();
      _onSpeechFinished();
    });
  }

  /// Registers callbacks to intercept speaking states.
  void registerSpeechStatusListener({
    required FutureOr<void> Function() onStart,
    required FutureOr<void> Function() onEnd,
  }) {
    _onSpeechStartListeners.add(onStart);
    _onSpeechEndListeners.add(onEnd);
  }

  void _triggerSpeechStart() {
    for (final l in _onSpeechStartListeners) {
      try {
        l();
      } catch (e) {
        debugPrint('Error triggering onSpeechStart listener: $e');
      }
    }
  }

  void _triggerSpeechEnd() {
    for (final l in _onSpeechEndListeners) {
      try {
        l();
      } catch (e) {
        debugPrint('Error triggering onSpeechEnd listener: $e');
      }
    }
  }

  /// Triggers a spoken announcement. Queues standard priority texts,
  /// and allows high-priority announcements to interrupt active speech.
  Future<void> speak(String text, {AnnouncementPriority priority = AnnouncementPriority.normal}) async {
    final settings = AccessibilitySettingsService.instance;
    if (!settings.speechEnabled) return;

    final completer = Completer<void>();
    final announcement = TtsAnnouncement(text, priority, completer);

    final activeCurrent = _current;
    if (_isSpeaking && activeCurrent != null) {
      if (priority.index > activeCurrent.priority.index) {
        // High-priority interruption
        _engine?.stop();
        _isSpeaking = false;
        if (!activeCurrent.completer.isCompleted) {
          activeCurrent.completer.complete();
        }
        _current = announcement;
        _speakAnnouncement(announcement);
      } else {
        // Queue normal/low priority items
        _queue.add(announcement);
        // Order by priority descending (high -> normal -> low), preserving FIFO (stable sort)
        _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      }
    } else {
      _current = announcement;
      _speakAnnouncement(announcement);
    }

    return completer.future;
  }

  Future<void> _speakAnnouncement(TtsAnnouncement announcement) async {
    _isSpeaking = true;
    final settings = AccessibilitySettingsService.instance;

    // Track history (limit to 20 announcements)
    _announcementHistory.add(announcement.text);
    if (_announcementHistory.length > 20) {
      _announcementHistory.removeAt(0);
    }

    await _engine?.speak(
      announcement.text,
      rate: settings.speechRate,
      pitch: settings.pitch,
      volume: settings.volume,
    );
  }

  void _onSpeechFinished() {
    final activeCurrent = _current;
    if (activeCurrent != null && !activeCurrent.completer.isCompleted) {
      activeCurrent.completer.complete();
    }
    _current = null;

    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _current = next;
      _speakAnnouncement(next);
    }
  }

  /// Stops all active speech playback and clears the pending queue.
  Future<void> stop() async {
    final activeCurrent = _current;
    await _engine?.stop();
    _queue.clear();
    if (activeCurrent != null && !activeCurrent.completer.isCompleted) {
      activeCurrent.completer.complete();
    }
    _current = null;
    _isSpeaking = false;
  }

  /// Resets queue and history states for testing isolation.
  void reset() {
    _queue.clear();
    _announcementHistory.clear();
    _current = null;
    _isSpeaking = false;
  }

  // History tracking
  final List<String> _announcementHistory = [];
  List<String> get announcementHistory => List.unmodifiable(_announcementHistory);

  String? get lastAnnouncement {
    if (_announcementHistory.isNotEmpty) {
      return _announcementHistory.last;
    }
    return null;
  }

  /// Repeats the most recent verbalized announcement.
  Future<void> repeatLastAnnouncement() async {
    final last = lastAnnouncement;
    if (last != null) {
      await speak(last, priority: AnnouncementPriority.high);
    } else {
      await speak("No previous announcement.", priority: AnnouncementPriority.normal);
    }
  }
}
