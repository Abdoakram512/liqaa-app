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

  /// All 150 bundled ElevenLabs Egyptian Arabic WAV scripts (id -> durationMs).
  static const Map<String, int> bundledScriptDurationsMs = {
    'g01': 3284,
    'g02': 3245,
    'g03': 3237,
    'g04': 3404,
    'g05': 2400,
    'g06': 3649,
    'g07': 3111,
    'g08': 2857,
    'ob01': 3535,
    'ob02': 3923,
    'ob03': 3711,
    'ob04': 3244,
    'ob05': 4207,
    'ob06': 3862,
    'ob07': 3617,
    'ob08': 1992,
    'wi01': 4411,
    'wi02': 4162,
    'wi03': 3602,
    'wi04': 4058,
    'wi05': 4466,
    'wi06': 4109,
    'wi07': 3962,
    'wi08': 3090,
    'ex01': 4355,
    'ex02': 2688,
    'ex03': 2946,
    'ex04': 2380,
    'ex05': 3101,
    'ex06': 3124,
    'ex07': 4037,
    'ex08': 2667,
    'ai01': 3750,
    'ai02': 3589,
    'ai03': 3931,
    'ai04': 4553,
    'ai05': 3444,
    'ai06': 4674,
    'ai07': 3619,
    'ai08': 3552,
    'ev01': 2518,
    'ev02': 3284,
    'ev03': 3567,
    'ev04': 3234,
    'ev05': 3336,
    'ev06': 3106,
    'ev07': 3748,
    'ev08': 2984,
    'ev09': 2898,
    'ev10': 3494,
    'ev11': 3518,
    'ev12': 3526,
    'ev13': 2795,
    'ev14': 3522,
    'ev15': 2834,
    'ev16': 2739,
    'ev17': 3007,
    'ev18': 3281,
    'ev19': 3037,
    'ev20': 2947,
    'ev21': 2511,
    'ev22': 2874,
    'ev23': 3131,
    'ev24': 3419,
    'ev25': 3776,
    'ev26': 3867,
    'ev27': 3930,
    'ev28': 4373,
    'le01': 2843,
    'le02': 2606,
    'le03': 2484,
    'le04': 2562,
    'le05': 2349,
    'le06': 2707,
    'le07': 3736,
    'le08': 3024,
    'en01': 2181,
    'en02': 2393,
    'en03': 2535,
    'en04': 3000,
    'en05': 3108,
    'en06': 2536,
    'en07': 2307,
    'en08': 3360,
    'ca01': 3184,
    'ca02': 2983,
    'ca03': 3498,
    'ca04': 3213,
    'ca05': 3322,
    'ca06': 2507,
    'ca07': 3393,
    'ca08': 3012,
    'ic01': 3250,
    'ic02': 2559,
    'ic03': 3562,
    'ic04': 3305,
    'ic05': 3688,
    'ic06': 2956,
    'ic07': 3555,
    'ic08': 2559,
    'us01': 4007,
    'us02': 3508,
    'us03': 3990,
    'us04': 4106,
    'us05': 3753,
    'us06': 3128,
    'rp01': 3426,
    'rp02': 3639,
    'rp03': 3633,
    'rp04': 3714,
    'rp05': 3497,
    'rp06': 4635,
    'rw01': 2927,
    'rw02': 3685,
    'rw03': 2543,
    'rw04': 3258,
    'rw05': 2468,
    'rw06': 2880,
    'rw07': 2608,
    'rw08': 2458,
    'ss01': 3875,
    'ss02': 4289,
    'ss03': 3798,
    'ss04': 3481,
    'ss05': 3284,
    'ss06': 3291,
    'rg01': 3671,
    'rg02': 3538,
    'rg03': 3331,
    'rg04': 3638,
    'rg05': 4499,
    'rg06': 3909,
    'rg07': 3512,
    'rg08': 2886,
    'fw01': 3483,
    'fw02': 2938,
    'fw03': 3293,
    'fw04': 3150,
    'fw05': 2429,
    'fw06': 3574,
    'fw07': 3625,
    'fw08': 2671,
    'st01': 4345,
    'st02': 4620,
    'st03': 4191,
    'st04': 4221,
    'st05': 4450,
    'st06': 4563,
    'st07': 4289,
    'st08': 4362,
  };

  /// Maps vocabulary word IDs and Adventure Book aliases to their bundled
  /// ElevenLabs word-introduction WAV ID (`ev01`..`ev28`).
  static const Map<String, String> bundledWordScriptIds = {
    'word_kora': 'ev01',
    'word_samaka': 'ev02',
    'word_batta': 'ev03',
    'word_2etta': 'ev04',
    'word_qetta': 'ev04',
    'word_arnab': 'ev05',
    'word_shams': 'ev06',
    'word_kalb': 'ev07',
    'word_tofa7a': 'ev08',
    'word_tuffaha': 'ev08',
    'word_moza': 'ev09',
    'word_gamal': 'ev10',
    'word_7osan': 'ev11',
    'word_feel': 'ev12',
    'word_fil': 'ev12',
    'word_alam': 'ev13',
    'word_qalam': 'ev13',
    'word_ketab': 'ev14',
    'word_beit': 'ev15',
    'word_3arabeya': 'ev16',
    'word_sayara': 'ev16',
    'word_bab': 'ev17',
    'word_tayara': 'ev18',
    'word_walad': 'ev19',
    'word_bent': 'ev20',
    'word_3ein': 'ev21',
    'word_eed': 'ev22',
    'word_regl': 'ev23',
    'word_ta3lab': 'ev24',
    'word_dahab': 'ev25',
    'word_zarafa': 'ev26',
    'word_zerafa': 'ev26',
    'word_hodhod': 'ev27',
    'word_farasha': 'ev28',
  };

  /// Returns the bundled relative AssetSource path for any of the 150 script
  /// IDs or mapped vocabulary word IDs, or null if not bundled.
  static String? bundledAssetPathForScript(String scriptId) {
    final resolvedId = bundledScriptDurationsMs.containsKey(scriptId)
        ? scriptId
        : bundledWordScriptIds[scriptId];
    if (resolvedId == null) return null;
    return 'pronunciation/prompts/$resolvedId.wav';
  }

  /// Resolves a bundled [YasserPrompt] with timed visemes for studio word WAVs
  /// and all 150 synthesized Egyptian Arabic prompt WAVs.
  static YasserPrompt? resolvePrompt({
    required String scriptId,
    required String arabicText,
    String? explicitAssetPath,
  }) {
    final directWord = byWordId[scriptId];
    if (directWord != null) return directWord;

    final resolvedId = bundledScriptDurationsMs.containsKey(scriptId)
        ? scriptId
        : bundledWordScriptIds[scriptId];
    if (resolvedId != null) {
      final durationMs = bundledScriptDurationsMs[resolvedId] ?? 1800;
      final cues = cuesForWord(
        arabicWord: arabicText,
        duration: Duration(milliseconds: durationMs),
      ).map((c) => (c.startMs, c.pose)).toList(growable: false);
      return YasserPrompt('pronunciation/prompts/$resolvedId.wav', cues);
    }

    if (explicitAssetPath != null && explicitAssetPath.isNotEmpty) {
      final cleaned = explicitAssetPath.startsWith('assets/')
          ? explicitAssetPath.substring('assets/'.length)
          : explicitAssetPath;
      for (final sid in bundledScriptDurationsMs.keys) {
        if (cleaned == 'pronunciation/prompts/$sid.wav') {
          final durationMs = bundledScriptDurationsMs[sid] ?? 1800;
          final cues = cuesForWord(
            arabicWord: arabicText,
            duration: Duration(milliseconds: durationMs),
          ).map((c) => (c.startMs, c.pose)).toList(growable: false);
          return YasserPrompt(cleaned, cues);
        }
      }
    }
    return null;
  }

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
