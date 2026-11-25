import '../../../core/animation/yasser/yasser_viseme.dart';

/// Approximate articulation cues annotated against each final spoken WAV.
class YasserPrompt {
  final String assetPath;
  final List<(int, YasserViseme)> _cues;

  const YasserPrompt(this.assetPath, this._cues);

  static const byWordId = {
    'word_samaka': YasserPrompt('pronunciation/prompts/samaka.wav', [
      (140, YasserViseme.teeth), // s
      (229, YasserViseme.open), // a
      (324, YasserViseme.closed), // m
      (410, YasserViseme.open), // a
      (523, YasserViseme.consonant), // k
      (562, YasserViseme.open), // a
      (645, YasserViseme.rest),
    ]),
    'word_kora': YasserPrompt('pronunciation/prompts/kora.wav', [
      (188, YasserViseme.consonant), // k
      (219, YasserViseme.rounded), // oo
      (309, YasserViseme.consonant), // r
      (330, YasserViseme.open), // a
      (383, YasserViseme.rest),
    ]),
  };

  YasserViseme poseAt(Duration position) {
    for (var i = _cues.length - 1; i >= 0; i--) {
      final (startMs, pose) = _cues[i];
      if (position.inMilliseconds >= startMs) return pose;
    }
    return YasserViseme.rest;
  }
}
