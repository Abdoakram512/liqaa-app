import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_viseme.dart';
import 'package:liqaa_app/core/audio/yasser_audio_coordinator.dart';
import 'package:liqaa_app/features/pronunciation_game/models/yasser_prompt.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(AssetSource('fallback.wav'));
  });

  group('YasserHarmonicSfxSynthesizer', () {
    test(
      'generates valid non-empty RIFF WAVE PCM16 bytes for every UI effect',
      () {
        for (final sfx in YasserSfx.values) {
          final wav = YasserHarmonicSfxSynthesizer.generateWav(sfx);
          expect(wav.length, greaterThan(200));
          expect(String.fromCharCodes(wav.sublist(0, 4)), equals('RIFF'));
          expect(String.fromCharCodes(wav.sublist(8, 12)), equals('WAVE'));
          expect(String.fromCharCodes(wav.sublist(12, 16)), equals('fmt '));
          expect(String.fromCharCodes(wav.sublist(36, 40)), equals('data'));
        }
      },
    );
  });

  group('YasserAudioCoordinator', () {
    late _MockAudioPlayer voicePlayer;
    late _MockAudioPlayer sfxPlayer;
    late StreamController<Duration> posController;
    late StreamController<PlayerState> stateController;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      voicePlayer = _MockAudioPlayer();
      sfxPlayer = _MockAudioPlayer();
      posController = StreamController<Duration>.broadcast(sync: true);
      stateController = StreamController<PlayerState>.broadcast(sync: true);

      when(
        () => voicePlayer.onPositionChanged,
      ).thenAnswer((_) => posController.stream);
      when(
        () => voicePlayer.onPlayerStateChanged,
      ).thenAnswer((_) => stateController.stream);
      when(() => voicePlayer.stop()).thenAnswer((_) async {});
      when(() => voicePlayer.dispose()).thenAnswer((_) async {});
      when(() => voicePlayer.state).thenReturn(PlayerState.playing);

      when(() => sfxPlayer.stop()).thenAnswer((_) async {});
      when(() => sfxPlayer.play(any())).thenAnswer((_) async {});
      when(() => sfxPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await posController.close();
      await stateController.close();
    });

    test(
      'persists voice, sfx, and haptics preferences across instances',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final first = YasserAudioCoordinator(
          prefs: prefs,
          voicePlayer: voicePlayer,
          sfxPlayer: sfxPlayer,
          observeAppLifecycle: false,
        );

        await first.setVoiceEnabled(false);
        await first.setSfxEnabled(false);
        await first.setHapticsEnabled(false);
        await first.dispose();

        final second = YasserAudioCoordinator(
          prefs: prefs,
          voicePlayer: voicePlayer,
          sfxPlayer: sfxPlayer,
          enablePlatformAudio: false,
          observeAppLifecycle: false,
        );
        expect(second.voiceEnabled, isFalse);
        expect(second.sfxEnabled, isFalse);
        expect(second.hapticsEnabled, isFalse);
        await second.dispose();
      },
    );

    test(
      'enforces strict mutual exclusion with active recording and pauses on app background',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final coordinator = YasserAudioCoordinator(
          prefs: prefs,
          voicePlayer: voicePlayer,
          sfxPlayer: sfxPlayer,
          observeAppLifecycle: false,
        );

        when(() => voicePlayer.play(any())).thenAnswer((_) async {
          stateController.add(PlayerState.playing);
        });

        final prompt = YasserPrompt.byWordId['word_kora']!;
        final started = await coordinator.playWordPrompt(prompt);
        expect(started, isTrue);
        expect(coordinator.isPlayingVoice, isTrue);

        posController.add(const Duration(milliseconds: 225));
        expect(coordinator.visemeNotifier.value, equals(YasserViseme.rounded));

        // Entering recording stops voice immediately and blocks further prompt playback
        await coordinator.enterRecordingSession();
        expect(coordinator.isPlayingVoice, isFalse);
        expect(coordinator.visemeNotifier.value, equals(YasserViseme.rest));
        expect(await coordinator.playWordPrompt(prompt), isFalse);

        coordinator.exitRecordingSession();
        expect(await coordinator.playWordPrompt(prompt), isTrue);

        // App backgrounding stops playback and resets viseme
        coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.isPlayingVoice, isFalse);
        expect(coordinator.visemeNotifier.value, equals(YasserViseme.rest));

        await coordinator.dispose();
      },
    );
  });
}
