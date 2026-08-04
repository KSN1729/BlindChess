import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/services/speech_synthesis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechSynthesisService Tests', () {
    test('MockSpeechSynthesisService generates and speaks correctly', () async {
      final mockService = MockSpeechSynthesisService();
      
      expect(mockService.generatedTexts, isEmpty);
      
      final path = await mockService.generateSpeech('pawn to e4');
      expect(path, equals('mock_speech_path.wav'));
      expect(mockService.generatedTexts, contains('pawn to e4'));
      
      await mockService.speak('knight to f3');
      expect(mockService.generatedTexts, contains('knight to f3'));
    });

    test('MockSpeechSynthesisService handles generation failure gracefully', () async {
      final mockService = MockSpeechSynthesisService();
      mockService.lastGenerationSuccess = false;
      
      final path = await mockService.generateSpeech('pawn to e4');
      expect(path, isNull);
    });

    test('RealSpeechSynthesisService produces different canonical moves for different phrases', () async {
      final service = RealSpeechSynthesisService();
      
      final path1 = await service.generateSpeech('pawn to e4');
      final path2 = await service.generateSpeech('knight to f3');
      
      expect(path1, isNotNull);
      expect(path2, isNotNull);
      
      final file1 = File(path1!);
      final file2 = File(path2!);
      
      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);
      
      final metaFile1 = File('$path1.json');
      final metaFile2 = File('$path2.json');
      
      expect(metaFile1.existsSync(), isTrue);
      expect(metaFile2.existsSync(), isTrue);
      
      final meta1 = jsonDecode(metaFile1.readAsStringSync());
      final meta2 = jsonDecode(metaFile2.readAsStringSync());
      
      expect(meta1['canonicalMove'], equals('e2e4'));
      expect(meta2['canonicalMove'], equals('g1f3'));
    });
  });
}
