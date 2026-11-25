import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/audio_recorder_service.dart';
import 'package:liqaa_app/core/ai/models/pronunciation_assessment.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/ai/pronunciation_repository.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_viseme.dart';
import 'package:liqaa_app/features/pronunciation_game/cubits/pronunciation_game_cubit.dart';
import 'package:liqaa_app/features/pronunciation_game/cubits/pronunciation_game_state.dart';
import 'package:mocktail/mocktail.dart';

class _Player extends Mock implements AudioPlayer {}

class _Recorder extends Mock implements AudioRecorderService {}

class _Repository extends Mock implements PronunciationRepository {}

void main() {
  const word = VocabularyWord(
    id: 'word_kora',
    wordArabic: '\u0643\u0648\u0631\u0629',
    wordTransliteration: 'Koora',
    meaningEn: 'Ball',
    targetPhoneme: 'k',
    targetPhonemeIpa: 'k',
    phonemeCategory: '',
    difficultyLevel: 1,
    expectedPhonemes: ['k'],
    expectedArabicPhonemes: [],
    yasserTip: '',
  );
  late _Player player;
  late _Recorder recorder;
  late _Repository repository;
  late StreamController<Duration> positions;
  late StreamController<PlayerState> playback;
  late PronunciationGameCubit cubit;
  late Uint8List recording;

  setUpAll(() => registerFallbackValue(AssetSource('fallback.wav')));

  setUp(() async {
    player = _Player();
    recorder = _Recorder();
    repository = _Repository();
    positions = StreamController<Duration>(sync: true);
    playback = StreamController<PlayerState>(sync: true);
    recording = Uint8List.fromList([1, 2, 3]);
    when(() => player.onPositionChanged).thenAnswer((_) => positions.stream);
    when(() => player.onPlayerStateChanged).thenAnswer((_) => playback.stream);
    when(() => player.dispose()).thenAnswer((_) async {});
    when(() => player.state).thenReturn(PlayerState.playing);
    when(
      () => recorder.amplitudeStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => recorder.startRecording()).thenAnswer((_) async {});
    when(() => recorder.stopRecording()).thenAnswer((_) async => recording);
    when(() => repository.recorder).thenReturn(recorder);
    when(() => repository.initialize()).thenAnswer((_) async {});
    when(() => repository.vocabulary).thenReturn([word]);
    cubit = PronunciationGameCubit(repository, audioPlayer: player);
    await cubit.initializeGame();
  });

  tearDown(() async {
    await cubit.close();
    await positions.close();
    await playback.close();
  });

  test(
    'holds the talking state until completion and uses player position',
    () async {
      when(() => player.play(any())).thenAnswer((_) async {
        playback.add(PlayerState.playing);
      });

      await cubit.playYasserAudioPrompt();
      expect(cubit.state.isPlayingAudioPrompt, isTrue);
      final source =
          verify(() => player.play(captureAny())).captured.single
              as AssetSource;
      expect(source.path, 'pronunciation/prompts/kora.wav');

      positions.add(const Duration(milliseconds: 235));
      expect(cubit.state.promptViseme, YasserViseme.rounded);
      positions.add(const Duration(milliseconds: 350));
      expect(cubit.state.promptViseme, YasserViseme.open);
      await cubit.startListening();
      verifyNever(() => recorder.startRecording());

      playback.add(PlayerState.completed);
      expect(cubit.state.isPlayingAudioPrompt, isFalse);
      expect(cubit.state.promptViseme, YasserViseme.rest);
      positions.add(const Duration(milliseconds: 235));
      expect(cubit.state.promptViseme, YasserViseme.rest);
    },
  );

  test('recovers when audio playback cannot start', () async {
    when(() => player.play(any())).thenThrow(StateError('Audio unavailable'));
    await cubit.playYasserAudioPrompt();
    expect(cubit.state.isPlayingAudioPrompt, isFalse);
    await cubit.startListening();
    expect(cubit.state.isListening, isTrue);
  });

  PronunciationAssessment assessment(
    AssessmentErrorType type, {
    required bool passed,
  }) => PronunciationAssessment(
    targetWord: 'Koora',
    targetWordArabic: word.wordArabic,
    recognizedTranscript: '',
    overallScore: passed ? 100 : 0,
    stars: passed ? 3 : 0,
    errorType: type,
    alignments: const [],
    recognizedPhonemes: const [],
    yasserFeedbackMessage: 'Feedback',
    yasserPose: passed ? 'celebrating' : 'thinking',
    passed: passed,
  );

  test(
    'a new silent attempt clears the previous successful assessment',
    () async {
      when(
        () => repository.evaluateAudio(
          rawAudioBytes: recording,
          targetWord: word,
        ),
      ).thenAnswer(
        (_) async => assessment(AssessmentErrorType.correct, passed: true),
      );
      await cubit.startListening();
      await cubit.stopListeningAndEvaluate();
      expect(cubit.state.status, GameStatus.successCelebration);
      expect(cubit.state.totalStarsEarned, 3);

      recording = Uint8List(0);
      await cubit.startListening();
      await cubit.stopListeningAndEvaluate();
      expect(cubit.state.yasserPose, 'thinking');
      expect(cubit.state.lastAssessment, isNull);
      expect(cubit.state.totalStarsEarned, 3);
    },
  );

  test('uncertain audio gets a retry hint without rewards', () async {
    when(
      () =>
          repository.evaluateAudio(rawAudioBytes: recording, targetWord: word),
    ).thenAnswer(
      (_) async => assessment(AssessmentErrorType.uncertain, passed: false),
    );
    await cubit.startListening();
    await cubit.stopListeningAndEvaluate();
    expect(cubit.state.status, GameStatus.supportiveHint);
    expect(cubit.state.yasserPose, 'thinking');
    expect(cubit.state.totalStarsEarned, 0);
  });
}
