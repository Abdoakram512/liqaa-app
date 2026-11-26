import '../../../core/animation/yasser/yasser_viseme.dart';

/// Timed mouth articulation cue paired with an optional phoneme label.
class YasserVisemeCue {
  final int startMs;
  final YasserViseme pose;
  final String phoneme;

  const YasserVisemeCue(this.startMs, this.pose, [this.phoneme = '']);
}

/// Articulation cues annotated against bundled WAV prompts and dynamic Arabic words.
class YasserPrompt {
  final String assetPath;
  final List<(int, YasserViseme)> _cues;

  const YasserPrompt(this.assetPath, this._cues);

  List<(int, YasserViseme)> get cues => _cues;

  static const byWordId = {
    'word_samaka': YasserPrompt('pronunciation/prompts/samaka.wav', [
      (140, YasserViseme.teeth), // س
      (229, YasserViseme.open), // َ
      (324, YasserViseme.closed), // م
      (410, YasserViseme.open), // َ
      (523, YasserViseme.consonant), // ك
      (562, YasserViseme.midOpen), // ة
      (645, YasserViseme.rest),
    ]),
    'word_kora': YasserPrompt('pronunciation/prompts/kora.wav', [
      (188, YasserViseme.consonant), // ك
      (219, YasserViseme.rounded), // ُ
      (309, YasserViseme.consonant), // ر
      (330, YasserViseme.open), // َ
      (383, YasserViseme.rest),
    ]),
  };

  /// Returns hand-tuned cues when a bundled studio WAV exists, or generates
  /// deterministic Arabic phoneme-approximate cues for any Arabic vocabulary word.
  static List<YasserVisemeCue> cuesForWord({
    String? wordId,
    required String arabicWord,
    Duration duration = const Duration(milliseconds: 900),
  }) {
    if (wordId != null && byWordId.containsKey(wordId)) {
      return byWordId[wordId]!._cues
          .map((e) => YasserVisemeCue(e.$1, e.$2))
          .toList(growable: false);
    }

    final clean = arabicWord.trim();
    if (clean.isEmpty) {
      return const [YasserVisemeCue(0, YasserViseme.rest)];
    }

    final parsed = <(String, YasserViseme)>[];
    for (final rune in clean.runes) {
      final ch = String.fromCharCode(rune);
      if (ch.trim().isEmpty) continue;
      parsed.add((ch, _visemeForArabicRune(ch)));
    }
    if (parsed.isEmpty) {
      return const [YasserVisemeCue(0, YasserViseme.rest)];
    }

    final totalMs = duration.inMilliseconds.clamp(250, 5000);
    final stepMs = mathMax(65, (totalMs * 0.84 / parsed.length).round());
    final out = <YasserVisemeCue>[];
    var cursor = 60;
    for (final item in parsed) {
      out.add(YasserVisemeCue(cursor, item.$2, item.$1));
      cursor += stepMs;
    }
    out.add(YasserVisemeCue(cursor, YasserViseme.rest, ''));
    return out;
  }

  static int mathMax(int a, int b) => a > b ? a : b;

  static YasserViseme _visemeForArabicRune(String ch) {
    switch (ch) {
      case 'م':
      case 'ب':
      case 'ْ':
        return YasserViseme.closed;
      case 'ف':
        return YasserViseme.labiodental;
      case 'و':
      case 'ؤ':
      case 'ُ':
      case 'ٌ':
        return YasserViseme.rounded;
      case 'س':
      case 'ص':
      case 'ز':
      case 'ذ':
      case 'ث':
      case 'ظ':
        return YasserViseme.teeth;
      case 'ا':
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ى':
      case 'ع':
      case 'ح':
      case 'خ':
      case 'ق':
      case 'َ':
      case 'ً':
        return YasserViseme.wideOpen;
      case 'ي':
      case 'ئ':
      case 'ش':
      case 'ج':
      case 'ض':
      case 'ِ':
      case 'ٍ':
        return YasserViseme.midOpen;
      default:
        return YasserViseme.consonant;
    }
  }

  YasserViseme poseAt(Duration position) {
    for (var i = _cues.length - 1; i >= 0; i--) {
      final (startMs, pose) = _cues[i];
      if (position.inMilliseconds >= startMs) return pose;
    }
    return YasserViseme.rest;
  }
}
