import '../config/square_dictionary.dart';
import '../config/number_dictionary.dart';

class PhoneticEncoder {
  static final PhoneticEncoder instance = PhoneticEncoder._();
  PhoneticEncoder._();

  String encode(String word) {
    String clean = word.toLowerCase().trim().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (clean.isEmpty) return '0000';

    // Direct mapping for digits/numbers
    if (RegExp(r'^[0-9]+$').hasMatch(clean)) {
      return 'N$clean'.padRight(4, '0').substring(0, 4);
    }

    // Number word homophones
    final Map<String, String> numberMap = {};
    for (final entry in rankDictionary.entries) {
      final canonical = entry.key;
      for (final synonym in entry.value) {
        if (synonym != canonical) {
          numberMap[synonym] = canonical;
        }
      }
    }
    if (numberMap.containsKey(clean)) {
      return 'N${numberMap[clean]}'.padRight(4, '0').substring(0, 4);
    }

    // File homophones
    final Map<String, String> fileMap = {};
    for (final entry in fileDictionary.entries) {
      final canonical = entry.key;
      for (final synonym in entry.value) {
        if (synonym != canonical) {
          fileMap[synonym] = canonical;
        }
      }
    }
    if (fileMap.containsKey(clean)) {
      clean = fileMap[clean]!;
    }

    // Word boundary cluster replacements
    if (clean.startsWith('kn')) {
      clean = 'n${clean.substring(2)}';
    }
    if (clean.startsWith('qu')) {
      clean = 'kw${clean.substring(2)}';
    } else if (clean.startsWith('q')) {
      clean = 'kw${clean.substring(1)}';
    }
    if (clean.startsWith('wr')) {
      clean = 'r${clean.substring(2)}';
    }
    if (clean.startsWith('ph')) {
      clean = 'f${clean.substring(2)}';
    }

    // Silent clusters
    if (clean.contains('ght')) {
      clean = clean.replaceAll('ght', 't');
    }
    if (clean.contains('sh')) {
      clean = clean.replaceAll('sh', 's');
    }
    if (clean.contains('ck')) {
      clean = clean.replaceAll('ck', 'k');
    }

    // Vowel replacements
    clean = clean.replaceAll('ee', 'i');
    clean = clean.replaceAll('oo', 'u');
    clean = clean.replaceAll('y', 'i');

    // End-of-word cluster simplify
    if (clean.endsWith('ng')) {
      clean = '${clean.substring(0, clean.length - 2)}n';
    }

    // Phonetic groupings (like keng/king/kin)
    if (clean == 'keng' || clean == 'king' || clean == 'kin') {
      clean = 'kin';
    }

    final firstLetter = clean[0].toUpperCase();
    final buffer = StringBuffer(firstLetter);

    // Soundex consonant mapping
    final codeMap = {
      'b': '1',
      'f': '1',
      'p': '1',
      'v': '1',
      'c': '2',
      'g': '2',
      'j': '2',
      'k': '2',
      'q': '2',
      's': '2',
      'x': '2',
      'z': '2',
      'd': '3',
      't': '3',
      'l': '4',
      'm': '5',
      'n': '5',
      'r': '6',
    };

    String prevCode = codeMap[clean[0]] ?? '';
    for (int i = 1; i < clean.length; i++) {
      final char = clean[i];
      final code = codeMap[char] ?? '';
      if (code.isNotEmpty && code != prevCode) {
        buffer.write(code);
        prevCode = code;
      }
    }

    String result = buffer.toString();
    if (result.length > 4) {
      result = result.substring(0, 4);
    } else {
      result = result.padRight(4, '0');
    }
    return result;
  }
}
