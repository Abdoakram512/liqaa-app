import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/pronunciation_repository.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../home/data/child_progress_service.dart';
import '../../../pronunciation_game/cubits/pronunciation_game_cubit.dart';
import '../../../pronunciation_game/cubits/pronunciation_game_state.dart';
import '../../../pronunciation_game/widgets/yasser_speech_feedback_card.dart';
import '../../../world/data/models/world_models.dart';
import '../widgets/activity_session_scaffold.dart';

/// Game 4 — Repeat After Yasser (`ردّد وراء ياسر`).
/// Demonstrates Yasser's pronunciation, enforces strict audio stop before
/// mic capture, and runs the real Phase 0.1 ONNX evaluation pipeline cleanly.
class RepeatAfterYasserGameView extends StatelessWidget {
  final ActivityLaunchConfig config;
  final PronunciationGameCubit? cubitOverride;

  const RepeatAfterYasserGameView({
    super.key,
    required this.config,
    this.cubitOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (cubitOverride != null) {
      return BlocProvider<PronunciationGameCubit>.value(
        value: cubitOverride!,
        child: _RepeatAfterYasserBody(config: config),
      );
    }

    return BlocProvider<PronunciationGameCubit>(
      create: (_) => PronunciationGameCubit(
        sl<PronunciationRepository>(),
        audioCoordinator: sl.isRegistered<YasserAudioCoordinator>()
            ? sl<YasserAudioCoordinator>()
            : null,
        progressService: sl.isRegistered<ChildProgressService>()
            ? sl<ChildProgressService>()
            : null,
        targetPhonemeFilter: config.targetPhonemes.isNotEmpty
            ? config.targetPhonemes
            : null,
      ),
      child: _RepeatAfterYasserBody(config: config),
    );
  }
}

class _RepeatAfterYasserBody extends StatefulWidget {
  final ActivityLaunchConfig config;

  const _RepeatAfterYasserBody({required this.config});

  @override
  State<_RepeatAfterYasserBody> createState() => _RepeatAfterYasserBodyState();
}

class _RepeatAfterYasserBodyState extends State<_RepeatAfterYasserBody> {
  bool _completed = false;
  int _spokenRoundsDone = 0;

  @override
  void initState() {
    super.initState();
    context.read<PronunciationGameCubit>().initializeGame();
  }

  YasserAnimationState _yasserStateFor(PronunciationGameState st) {
    if (st.isListening) return YasserAnimationState.listening;
    if (st.isPlayingAudioPrompt) return YasserAnimationState.talking;
    if (st.status == GameStatus.successCelebration) {
      return YasserAnimationState.celebrating;
    }
    if (st.status == GameStatus.supportiveHint) {
      return YasserAnimationState.gentleRetry;
    }
    return YasserAnimationState.encouraging;
  }

  RecordingOrbState _orbFor(PronunciationGameState st) {
    if (st.isListening) return RecordingOrbState.recording;
    if (st.status == GameStatus.evaluating ||
        st.status == GameStatus.preparingRecording) {
      return RecordingOrbState.processing;
    }
    if (st.isPlayingAudioPrompt || st.status == GameStatus.preparingPrompt) {
      return RecordingOrbState.disabled;
    }
    if (st.status == GameStatus.successCelebration) {
      return RecordingOrbState.completed;
    }
    return RecordingOrbState.idle;
  }

  Future<void> _finishStep(PronunciationGameState st) async {
    final word = st.currentWord;
    final assessment = st.lastAssessment;
    final bool? passed =
        assessment == null || assessment.errorType.isInconclusiveOrTechnical
        ? null
        : (assessment.passed &&
              assessment.errorType == AssessmentErrorType.correct);
    final int inconclusive =
        assessment != null && assessment.errorType.isInconclusiveOrTechnical
        ? 1
        : 0;

    await recordWorldActivitySafe(
      context,
      ActivityOutcomeRecord(
        id: 'out_${DateTime.now().microsecondsSinceEpoch}',
        activityId: widget.config.stepId ?? 'repeat_after_yasser',
        gameType: MiniGameType.repeatAfterYasser,
        regionId: widget.config.regionId,
        timestamp: DateTime.now(),
        completed: true,
        pronunciationPassed: passed,
        inconclusiveTechnicalCount: inconclusive,
        targetPhonemes: word != null ? [word.targetPhoneme] : const [],
      ),
      config: widget.config,
      markAdventureComplete: widget.config.rewardCollectibleId != null,
    );
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PronunciationGameCubit, PronunciationGameState>(
      listenWhen: (p, c) => p.status != c.status && c.lastAssessment != null,
      listener: (context, state) {
        if (state.status == GameStatus.successCelebration ||
            state.status == GameStatus.supportiveHint) {
          setState(() => _spokenRoundsDone++);
        }
      },
      builder: (context, state) {
        final cubit = context.read<PronunciationGameCubit>();
        final word = state.currentWord;

        return ActivitySessionScaffold(
          config: widget.config,
          currentRound: (_spokenRoundsDone + 1).clamp(1, 2),
          totalRounds: 2,
          yasserState: _yasserStateFor(state),
          yasserMessage: state.yasserMessage.isNotEmpty
              ? state.yasserMessage
              : 'اسمع نطق ياسر الأول، وبعدين دوس على المايك وردّد وراه!',
          onReplayInstruction: cubit.playYasserAudioPrompt,
          completed: _completed,
          earnedSummaryText: 'ردّدت وراء ياسر بشجاعة وتركيز!',
          body: word == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.all(18.w),
                  child: Column(
                    children: [
                      YasserSurfaceCard(
                        padding: EdgeInsets.all(18.w),
                        child: Column(
                          children: [
                            IllustratedVocabularyWidget(
                              objectKey: '${word.id}_${word.meaningEn}',
                              semanticLabel: word.wordArabic,
                              size: 98,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              word.wordArabic,
                              style: AppTextStyles.displayMedium,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              word.yasserTip,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall,
                            ),
                            SizedBox(height: 12.h),
                            OutlinedButton.icon(
                              onPressed: state.isListening
                                  ? null
                                  : cubit.playYasserAudioPrompt,
                              icon: Icon(
                                state.isPlayingAudioPrompt
                                    ? Icons.graphic_eq_rounded
                                    : Icons.volume_up_rounded,
                              ),
                              label: Text(
                                state.isPlayingAudioPrompt
                                    ? 'ياسر بينطق...'
                                    : 'اسمع ياسر أولاً',
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),
                      if (state.lastAssessment != null) ...[
                        YasserSpeechFeedbackCard(
                          message: state.lastAssessment!.yasserFeedbackMessage,
                          poseString: state.lastAssessment!.yasserPose,
                          isListening: state.isListening,
                          isPlayingAudioPrompt: state.isPlayingAudioPrompt,
                        ),
                        SizedBox(height: 12.h),
                      ],
                      YasserRecordingButton(
                        state: _orbFor(state),
                        statusLabel: state.isListening
                            ? 'اضغط للإيقاف بعد نطق الكلمة'
                            : (state.status == GameStatus.evaluating
                                  ? 'ياسر بيحلل صوتك...'
                                  : 'اضغط للرد بصوتك'),
                        onTap: () {
                          if (state.isListening) {
                            cubit.stopListeningAndEvaluate();
                          } else {
                            cubit.startListening();
                          }
                        },
                      ),
                      SizedBox(height: 16.h),
                      if (state.status == GameStatus.successCelebration ||
                          _spokenRoundsDone >= 1)
                        PrimaryButton(
                          label: _spokenRoundsDone >= 2
                              ? 'إتمام التمرين'
                              : 'كلمة تانية',
                          icon: const Icon(Icons.arrow_forward_rounded),
                          onPressed: _spokenRoundsDone >= 2
                              ? () => _finishStep(state)
                              : cubit.nextWord,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
