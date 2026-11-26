import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../animation/yasser/yasser_viseme.dart';
import '../widgets/yasser_tactile_surface.dart';
import '../../features/pronunciation_game/models/yasser_prompt.dart';

/// Gentle, child-friendly harmonic sound effect categories.
enum YasserSfx {
  buttonTap,
  pageTransition,
  activitySelect,
  recordStart,
  recordStop,
  retryGentle,
  starReward,
  sessionComplete,
}

/// Catalog of Yasser's Egyptian Arabic conversational voice lines.
///
/// Word prompts with bundled studio WAVs (`word_kora`, `word_samaka`) play
/// real pre-recorded audio with cue-synced visemes. Conversational lines whose
/// studio WAVs have not yet been recorded degrade gracefully to warm speech
/// bubble copy + gentle harmonic cue without calling paid runtime TTS APIs.
enum YasserVoiceCue {
  welcomeHero(arabicText: 'أهلاً يا بطل! أنا ياسر، يلا نلعب بالأصوات!'),
  listenExampleFirst(
    arabicText: 'اسمع الكلمة من ياسر الأول، وبعدها قولها بصوتك الجميل!',
  ),
  yourTurnSpeak(
    arabicText: 'دلوقتي دورك يا بطل! اضغط على المايك وانطق الكلمة.',
  ),
  praiseBravo(arabicText: 'برافو عليك يا بطل! نطقك واضح وممتاز!'),
  retrySupportive(
    arabicText: 'محاولة حلوة! معلش، يلا نسمع الكلمة ونجرب تاني بهدوء.',
  ),
  silenceHint(arabicText: 'مسمعتش صوتك كويس.. قرّب شوية من المايك وجرّب تاني!'),
  noiseHint(arabicText: 'فيه دوشة حوالينا.. يلا نجرب في مكان أهدى شوية!'),
  sessionCompleted(arabicText: 'الله ينور يا بطل! خلصت جلسة التدريب بنجاح!');

  final String arabicText;

  const YasserVoiceCue({required this.arabicText});
}

/// Centralized coordinator for Yasser's voice prompts, gentle UI sound effects,
/// haptic preferences, app-lifecycle interruption cleanup, and strict
/// mutual exclusion with active microphone capture.
class YasserAudioCoordinator extends ChangeNotifier
    with WidgetsBindingObserver {
  static const String prefVoiceEnabled = 'yasser_audio_voice_enabled';
  static const String prefSfxEnabled = 'yasser_audio_sfx_enabled';
  static const String prefHapticsEnabled = 'yasser_audio_haptics_enabled';

  final SharedPreferences? _prefs;
  final AudioPlayer _voicePlayer;
  final AudioPlayer _sfxPlayer;
  final bool _enablePlatformAudio;

  final Map<YasserSfx, Uint8List> _synthesizedSfxCache = {};

  bool _voiceEnabled = true;
  bool _sfxEnabled = true;
  bool _hapticsEnabled = true;
  bool _isRecordingActive = false;
  bool _isPlayingVoice = false;
  bool _disposed = false;

  YasserPrompt? _activePrompt;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _voiceStateSub;

  final ValueNotifier<YasserViseme> visemeNotifier =
      ValueNotifier<YasserViseme>(YasserViseme.rest);

  YasserAudioCoordinator({
    SharedPreferences? prefs,
    AudioPlayer? voicePlayer,
    AudioPlayer? sfxPlayer,
    bool enablePlatformAudio = true,
    bool observeAppLifecycle = true,
  }) : _prefs = prefs,
       _voicePlayer = voicePlayer ?? AudioPlayer(),
       _sfxPlayer = sfxPlayer ?? AudioPlayer(),
       _enablePlatformAudio = enablePlatformAudio {
    _voiceEnabled = _prefs?.getBool(prefVoiceEnabled) ?? true;
    _sfxEnabled = _prefs?.getBool(prefSfxEnabled) ?? true;
    _hapticsEnabled = _prefs?.getBool(prefHapticsEnabled) ?? true;

    _syncGlobalUiFeedback();
    _bindVoiceStreams();

    if (observeAppLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  bool get voiceEnabled => _voiceEnabled;
  bool get sfxEnabled => _sfxEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get isRecordingActive => _isRecordingActive;
  bool get isPlayingVoice => _isPlayingVoice;

  void _syncGlobalUiFeedback() {
    YasserUiFeedback.enableHaptics = _hapticsEnabled;
    YasserUiFeedback.onButtonPress = () {
      unawaited(playSfx(YasserSfx.buttonTap));
    };
  }

  void _bindVoiceStreams() {
    _positionSub = _voicePlayer.onPositionChanged.listen((pos) {
      if (_disposed || !_isPlayingVoice || _activePrompt == null) return;
      final nextPose = _activePrompt!.poseAt(pos);
      if (visemeNotifier.value != nextPose) {
        visemeNotifier.value = nextPose;
      }
    });

    _voiceStateSub = _voicePlayer.onPlayerStateChanged.listen((state) {
      if (_disposed) return;
      if (state == PlayerState.playing) {
        if (!_isPlayingVoice) {
          _isPlayingVoice = true;
          notifyListeners();
        }
      } else if (_isPlayingVoice || state == PlayerState.completed) {
        _resetVoiceState();
      }
    });
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    if (_voiceEnabled == enabled) return;
    _voiceEnabled = enabled;
    await _prefs?.setBool(prefVoiceEnabled, enabled);
    if (!enabled) {
      await stopVoice();
    }
    notifyListeners();
  }

  Future<void> setSfxEnabled(bool enabled) async {
    if (_sfxEnabled == enabled) return;
    _sfxEnabled = enabled;
    await _prefs?.setBool(prefSfxEnabled, enabled);
    if (!enabled) {
      await _safeStopPlayer(_sfxPlayer);
    }
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    YasserUiFeedback.enableHaptics = enabled;
    await _prefs?.setBool(prefHapticsEnabled, enabled);
    notifyListeners();
  }

  /// Enforces strict mutual exclusion before opening the child's microphone:
  /// stops any active voice prompt or UI chime immediately so speaker output
  /// never contaminates recorded speech.
  Future<void> enterRecordingSession() async {
    _isRecordingActive = true;
    await stopAllAudio();
    notifyListeners();
  }

  /// Releases the recording lock once microphone capture has stopped.
  void exitRecordingSession({bool playStopChime = false}) {
    if (!_isRecordingActive) return;
    _isRecordingActive = false;
    notifyListeners();
    if (playStopChime) {
      unawaited(playSfx(YasserSfx.recordStop));
    }
  }

  /// Plays a bundled word prompt (`kora.wav`, `samaka.wav`) with cue-driven
  /// visemes, respecting `voiceEnabled` and `_isRecordingActive`.
  Future<bool> playWordPrompt(YasserPrompt prompt) async {
    if (_disposed || !_voiceEnabled || _isRecordingActive) {
      return false;
    }
    await stopVoice();
    _activePrompt = prompt;
    if (!_enablePlatformAudio) {
      return false;
    }

    try {
      await _voicePlayer.play(AssetSource(prompt.assetPath));
      if (!_disposed && _voicePlayer.state == PlayerState.playing) {
        _isPlayingVoice = true;
        notifyListeners();
        return true;
      } else {
        _resetVoiceState();
        return false;
      }
    } catch (_) {
      _resetVoiceState();
      return false;
    }
  }

  /// Plays a gentle, harmonic, non-intrusive PCM16 WAV sound effect.
  Future<void> playSfx(YasserSfx effect) async {
    if (_disposed ||
        !_sfxEnabled ||
        _isRecordingActive ||
        !_enablePlatformAudio) {
      return;
    }
    try {
      final bytes = _synthesizedSfxCache.putIfAbsent(
        effect,
        () => YasserHarmonicSfxSynthesizer.generateWav(effect),
      );
      await _sfxPlayer.stop();
      await _sfxPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Never crash or surface errors if platform audio backend is unavailable.
    }
  }

  Future<void> stopVoice() async {
    await _safeStopPlayer(_voicePlayer);
    _resetVoiceState();
  }

  Future<void> stopAllAudio() async {
    await Future.wait([
      _safeStopPlayer(_voicePlayer),
      _safeStopPlayer(_sfxPlayer),
    ]);
    _resetVoiceState();
  }

  Future<void> _safeStopPlayer(AudioPlayer player) async {
    if (!_enablePlatformAudio) return;
    try {
      await player.stop();
    } catch (_) {}
  }

  void _resetVoiceState() {
    final bool changed =
        _isPlayingVoice ||
        _activePrompt != null ||
        visemeNotifier.value != YasserViseme.rest;
    _activePrompt = null;
    _isPlayingVoice = false;
    visemeNotifier.value = YasserViseme.rest;
    if (changed && !_disposed) {
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(stopAllAudio());
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (YasserUiFeedback.onButtonPress != null) {
      YasserUiFeedback.onButtonPress = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    await _positionSub?.cancel();
    await _voiceStateSub?.cancel();
    try {
      if (_enablePlatformAudio) {
        await _voicePlayer.dispose();
        await _sfxPlayer.dispose();
      }
    } catch (_) {}
    visemeNotifier.dispose();
    super.dispose();
  }
}

/// Generates soft, musical, child-safe 16kHz mono PCM16 RIFF/WAVE chimes
/// in memory with smooth cosine attack and exponential decay envelopes.
abstract final class YasserHarmonicSfxSynthesizer {
  static const int _sampleRate = 16000;

  static Uint8List generateWav(YasserSfx effect) {
    final List<_ToneNote> notes = switch (effect) {
      YasserSfx.buttonTap => const [
        _ToneNote(freqHz: 587.33, startMs: 0, durationMs: 48, gain: 0.16),
      ],
      YasserSfx.pageTransition => const [
        _ToneNote(freqHz: 440.0, startMs: 0, durationMs: 65, gain: 0.11),
        _ToneNote(freqHz: 554.37, startMs: 40, durationMs: 75, gain: 0.12),
      ],
      YasserSfx.activitySelect => const [
        _ToneNote(freqHz: 523.25, startMs: 0, durationMs: 85, gain: 0.20),
        _ToneNote(freqHz: 783.99, startMs: 65, durationMs: 110, gain: 0.22),
      ],
      YasserSfx.recordStart => const [
        _ToneNote(freqHz: 587.33, startMs: 0, durationMs: 70, gain: 0.22),
        _ToneNote(freqHz: 880.00, startMs: 55, durationMs: 95, gain: 0.24),
      ],
      YasserSfx.recordStop => const [
        _ToneNote(freqHz: 783.99, startMs: 0, durationMs: 65, gain: 0.18),
        _ToneNote(freqHz: 523.25, startMs: 50, durationMs: 85, gain: 0.18),
      ],
      YasserSfx.retryGentle => const [
        _ToneNote(freqHz: 392.00, startMs: 0, durationMs: 95, gain: 0.18),
        _ToneNote(freqHz: 440.00, startMs: 80, durationMs: 115, gain: 0.18),
      ],
      YasserSfx.starReward => const [
        _ToneNote(freqHz: 523.25, startMs: 0, durationMs: 90, gain: 0.22),
        _ToneNote(freqHz: 659.25, startMs: 70, durationMs: 95, gain: 0.23),
        _ToneNote(freqHz: 783.99, startMs: 140, durationMs: 110, gain: 0.25),
        _ToneNote(freqHz: 1046.50, startMs: 215, durationMs: 160, gain: 0.26),
      ],
      YasserSfx.sessionComplete => const [
        _ToneNote(freqHz: 523.25, startMs: 0, durationMs: 110, gain: 0.22),
        _ToneNote(freqHz: 659.25, startMs: 90, durationMs: 110, gain: 0.23),
        _ToneNote(freqHz: 783.99, startMs: 180, durationMs: 120, gain: 0.25),
        _ToneNote(freqHz: 1046.50, startMs: 280, durationMs: 240, gain: 0.28),
      ],
    };

    int totalDurationMs = 60;
    for (final n in notes) {
      totalDurationMs = math.max(
        totalDurationMs,
        n.startMs + n.durationMs + 15,
      );
    }

    final int numSamples = (_sampleRate * totalDurationMs) ~/ 1000;
    final Float64List mix = Float64List(numSamples);

    for (final note in notes) {
      final int startIdx = (_sampleRate * note.startMs) ~/ 1000;
      final int lenSamples = (_sampleRate * note.durationMs) ~/ 1000;
      final int attackSamples = math.max(1, (_sampleRate * 8) ~/ 1000);

      for (int i = 0; i < lenSamples && (startIdx + i) < numSamples; i++) {
        final double t = i / _sampleRate;
        final double progress = i / lenSamples;
        final double attack = i < attackSamples
            ? 0.5 * (1.0 - math.cos(math.pi * i / attackSamples))
            : 1.0;
        final double decay = math.exp(-3.8 * progress);
        // Warm fundamental + soft second harmonic for marimba-like timbre
        final double wave =
            math.sin(2.0 * math.pi * note.freqHz * t) +
            0.22 * math.sin(4.0 * math.pi * note.freqHz * t);
        mix[startIdx + i] += wave * note.gain * attack * decay;
      }
    }

    return _encodePcm16Wav(mix);
  }

  static Uint8List _encodePcm16Wav(Float64List samples) {
    final int dataBytes = samples.length * 2;
    final ByteData buffer = ByteData(44 + dataBytes);

    void writeAscii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    buffer.setUint32(4, 36 + dataBytes, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // PCM chunk size
    buffer.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    buffer.setUint16(22, 1, Endian.little); // NumChannels = 1 (Mono)
    buffer.setUint32(24, _sampleRate, Endian.little);
    buffer.setUint32(28, _sampleRate * 2, Endian.little); // ByteRate
    buffer.setUint16(32, 2, Endian.little); // BlockAlign
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample = 16
    writeAscii(36, 'data');
    buffer.setUint32(40, dataBytes, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final int pcm = (samples[i].clamp(-0.95, 0.95) * 32767.0).round();
      buffer.setInt16(44 + i * 2, pcm, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}

class _ToneNote {
  final double freqHz;
  final int startMs;
  final int durationMs;
  final double gain;

  const _ToneNote({
    required this.freqHz,
    required this.startMs,
    required this.durationMs,
    required this.gain,
  });
}
