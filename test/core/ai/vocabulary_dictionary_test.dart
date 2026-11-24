import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';

void main() {
  group('Egyptian Arabic Dictionary Validation Tests', () {
    test('Dictionary JSON file exists and contains at least 25 words', () {
      final file = File('assets/pronunciation/egyptian_arabic_dictionary.json');
      expect(file.existsSync(), isTrue);

      final String content = file.readAsStringSync();
      final Map<String, dynamic> jsonMap = json.decode(content);

      final List<dynamic> words = jsonMap['words'] as List<dynamic>;
      expect(words.length, greaterThanOrEqualTo(25));

      for (final w in words) {
        final vocab = VocabularyWord.fromJson(w as Map<String, dynamic>);
        expect(vocab.id, isNotEmpty);
        expect(vocab.wordArabic, isNotEmpty);
        expect(vocab.targetPhoneme, isNotEmpty);
        expect(vocab.expectedPhonemes, isNotEmpty);
        expect(vocab.expectedArabicPhonemes, isNotEmpty);
        expect(vocab.yasserTip, isNotEmpty);
        expect(vocab.commonChildErrors, isNotEmpty);
      }
    });
  });
}
