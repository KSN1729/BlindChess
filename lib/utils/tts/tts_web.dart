import 'package:web/web.dart' as web;

void speakText(String text) {
  try {
    final synth = web.window.speechSynthesis;
    final utterance = web.SpeechSynthesisUtterance(text);
    synth.speak(utterance);
  } catch (e) {
    // Ignore error
  }
}
