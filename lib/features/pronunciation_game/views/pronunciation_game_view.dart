import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependency_injection/service_locator.dart';
import '../../../core/ai/models/pronunciation_assessment.dart';
import '../../../core/ai/models/vocabulary_word.dart';
import '../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../core/audio/yasser_audio_coordinator.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/yasser_design_tokens.dart';
import '../../../core/widgets/phonological_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/yasser_audio_settings_sheet.dart';
import '../../../core/widgets/yasser_buttons.dart';
import '../../../core/widgets/yasser_character.dart';
import '../../../core/widgets/yasser_surface_card.dart';
import '../cubits/pronunciation_game_cubit.dart';
import '../cubits/pronunciation_game_state.dart';
import '../models/yasser_prompt.dart';
import '../widgets/phonetic_breakdown_pill.dart';
import '../widgets/sound_waveform_wave.dart';
import '../widgets/vocabulary_illustration_badge.dart';
import '../widgets/yasser_speech_feedback_card.dart';

class PronunciationGameView extends StatefulWidget {
  const PronunciationGameView({super.key});

  @override
  State<PronunciationGameView> createState() => _PronunciationGameViewState();
}

class _PronunciationGameViewState extends State<PronunciationGameView> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1400),
    );
    context.read<PronunciationGameCubit>().initializeGame();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _handleExit(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  RecordingOrbState _orbStateFor(PronunciationGameState state) {
    if (state.isListening) return RecordingOrbState.recording;
    if (state.status == GameStatus.evaluating ||
        state.status == GameStatus.preparingRecording) {
      return RecordingOrbState.processing;
    }
    if (state.isPlayingAudioPrompt ||
        state.status == GameStatus.preparingPrompt) {
      return RecordingOrbState.disabled;
    }
    if (state.status == GameStatus.successCelebration) {
      return RecordingOrbState.completed;
    }
    return RecordingOrbState.idle;
  }

  String _micStatusLabel(PronunciationGameState state) {
    if (state.status == GameStatus.preparingRecording) {
      return 'جاري تجهيز الميكروفون...';
    }
    if (state.status == GameStatus.evaluating) {
      return 'ياسر بيحلل صوتك دلوقتي...';
    }
    if (state.isListening) {
      return 'اضغط لإيقاف التسجيل بعد نطق الكلمة';
    }
    if (state.isPlayingAudioPrompt ||
        state.status == GameStatus.preparingPrompt) {
      return 'استمع أولاً لنطق ياسر...';
    }
    if (state.status == GameStatus.successCelebration) {
      return 'نطق رائع! اضغط للتدريب مرة أخرى';
    }
    if (state.status == GameStatus.error) {
      return 'اضغط للمحاولة من جديد';
    }
    return 'اضغط على المايك وانطق الكلمة';
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = YasserMotion.isReducedMotion(context);

    return Scaffold(
      body: PhonologicalBackground(
        variant: PhonologicalSceneVariant.soundDiscovery,
        child: SafeArea(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              BlocConsumer<PronunciationGameCubit, PronunciationGameState>(
                listenWhen: (prev, curr) => prev.status != curr.status,
                listener: (context, state) {
                  if (!reduced &&
                      (state.status == GameStatus.successCelebration ||
                          state.status == GameStatus.sessionCompleted)) {
                    _confettiController.play();
                  }
                },
                builder: (context, state) {
                  if (state.status == GameStatus.loading) {
                    return _buildLoadingView();
                  }

                  if (state.status == GameStatus.sessionCompleted) {
                    return _buildSessionCompletedView(context, state);
                  }

                  final word = state.currentWord;
                  final assessment = state.lastAssessment;

                  return Column(
                    children: [
                      _buildHeader(context, state),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AppSpacing.maxCardWidth,
                              ),
                              child: Column(
                                children: [
                                  if (state.activeCaseName != null) ...[
                                    _buildSpecialistSessionBanner(
                                      state.activeCaseName!,
                                    ),
                                    SizedBox(height: 10.h),
                                  ],
                                  SizedBox(height: 6.h),

                                  // Target Illustrated Word Card
                                  if (word != null)
                                    _buildWordCard(context, state, word),

                                  SizedBox(height: 14.h),

                                  // Honest System Notice or Assessment Result Banner
                                  if (state.status == GameStatus.error &&
                                      state.errorMessage != null &&
                                      assessment == null)
                                    _buildSystemErrorBanner(
                                      context,
                                      state.errorMessage!,
                                    )
                                  else if (assessment != null)
                                    _buildAssessmentBanner(
                                      assessment,
                                      passed:
                                          state.status ==
                                          GameStatus.successCelebration,
                                    ),

                                  SizedBox(height: 14.h),

                                  // Prominent Yasser & Speech Bubble
                                  YasserSpeechFeedbackCard(
                                    message: state.yasserMessage,
                                    poseString: state.yasserPose,
                                    isListening: state.isListening,
                                    isPlayingAudioPrompt:
                                        state.isPlayingAudioPrompt,
                                    promptViseme: state.promptViseme,
                                  ),

                                  SizedBox(height: 12.h),

                                  // Live Harmonic Microphone Activity Wave
                                  SoundWaveformWave(
                                    amplitude: state.liveAmplitude,
                                    isListening: state.isListening,
                                  ),

                                  SizedBox(height: 12.h),

                                  // Tactile Squircle Recording Orb
                                  YasserRecordingButton(
                                    state: _orbStateFor(state),
                                    liveAmplitude: state.liveAmplitude,
                                    statusLabel: _micStatusLabel(state),
                                    onTap:
                                        state.status == GameStatus.evaluating ||
                                            state.status ==
                                                GameStatus.preparingRecording ||
                                            state.isPlayingAudioPrompt ||
                                            state.status ==
                                                GameStatus.preparingPrompt
                                        ? null
                                        : () {
                                            final cubit = context
                                                .read<PronunciationGameCubit>();
                                            if (state.isListening) {
                                              cubit.stopListeningAndEvaluate();
                                            } else {
                                              cubit.startListening();
                                            }
                                          },
                                  ),

                                  SizedBox(height: 18.h),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildBottomNavigation(context, state),
                    ],
                  );
                },
              ),

              if (!reduced)
                IgnorePointer(
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    numberOfParticles: 18,
                    gravity: 0.25,
                    colors: const [
                      AppColors.primary,
                      AppColors.secondary,
                      AppColors.accentMint,
                      AppColors.accentGold,
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.4,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'جاري تجهيز بطاقات الأصوات مع ياسر...',
            style: AppTextStyles.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialistSessionBanner(String caseName) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.secondarySoft,
        shape: YasserShapes.squircle(
          14,
          side: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.35),
            width: 1.3,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        child: Row(
          children: [
            const Icon(
              Icons.medical_information_rounded,
              size: 18,
              color: AppColors.secondaryDark,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'جلسة تدريب موجهة للحالة: $caseName (تُحفظ المحاولات تلقائياً)',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PronunciationGameState state) {
    final double deckProgress = state.words.isEmpty
        ? 0.0
        : ((state.currentWordIndex + 1) / state.words.length).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 6.h),
      child: Column(
        children: [
          Row(
            children: [
              YasserIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'رجوع',
                onPressed: () => _handleExit(context),
              ),
              SizedBox(width: 10.w),

              // Stars & Mastered Badges
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8.w,
                  runSpacing: 4.h,
                  children: [
                    _RewardCounterBadge(
                      icon: Icons.star_rounded,
                      value: '${state.totalStarsEarned}',
                      label: 'نجمة',
                      tint: AppColors.accentGoldSoft,
                      border: AppColors.accentGold,
                      fg: AppColors.primaryDeep,
                    ),
                    _RewardCounterBadge(
                      icon: Icons.workspace_premium_rounded,
                      value: '${state.wordsMasteredCount}',
                      label: 'متقنة',
                      tint: AppColors.successSoft,
                      border: AppColors.success,
                      fg: AppColors.successDark,
                    ),
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              // Audio settings or finish session
              YasserIconButton(
                icon: Icons.flag_rounded,
                iconColor: AppColors.primaryDark,
                tooltip: 'إنهاء الجلسة وعرض الملخص',
                onPressed: state.isBusyWithAudio
                    ? null
                    : () => context
                          .read<PronunciationGameCubit>()
                          .finishSession(),
              ),
              if (sl.isRegistered<YasserAudioCoordinator>()) ...[
                SizedBox(width: 6.w),
                YasserIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'إعدادات الصوت',
                  onPressed: () => showYasserAudioSettingsSheet(
                    context,
                    coordinator: sl<YasserAudioCoordinator>(),
                  ),
                ),
              ],
              if (kDebugMode) ...[
                SizedBox(width: 6.w),
                YasserIconButton(
                  icon: Icons.psychology_alt_rounded,
                  iconColor: AppColors.secondary,
                  tooltip: 'مختبر الذكاء الاصطناعي (Debug)',
                  onPressed: () => context.push(AppRoutes.aiLab),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: deckProgress,
              minHeight: 7,
              backgroundColor: AppColors.borderSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(
    BuildContext context,
    PronunciationGameState state,
    VocabularyWord word,
  ) {
    final bool hasBundledPrompt = YasserPrompt.byWordId.containsKey(word.id);
    final assessment = state.lastAssessment;

    return YasserSurfaceCard(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      radius: AppSpacing.radiusXL,
      lipDepth: 5.0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Target Phoneme Badge (Child-friendly Arabic without raw IPA clutter)
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: AppColors.primarySoft,
                  shape: YasserShapes.squircle(
                    12,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 5.h,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        'صوت حرف (${word.targetPhoneme})',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Difficulty stars indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(word.difficultyLevel.clamp(1, 3), (i) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1.5),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: AppColors.primary,
                    ),
                  );
                }),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // Custom Vector Vocabulary Illustration + Giant Clear Arabic Word
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              VocabularyIllustrationBadge(word: word),
              SizedBox(width: 18.w),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.wordArabic,
                      style: AppTextStyles.displayMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 34.sp,
                      ),
                    ),
                    if (word.yasserTip.isNotEmpty)
                      Text(
                        word.yasserTip,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Tactile Arabic Letter Breakdown Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(word.expectedPhonemes.length, (index) {
                final String ph = word.expectedPhonemes[index];
                final String ar = index < word.expectedArabicPhonemes.length
                    ? word.expectedArabicPhonemes[index]
                    : ph;
                final bool isTarget =
                    ar == word.targetPhoneme || ph == word.targetPhonemeIpa;

                bool isMatched = false;
                bool isErrored = false;
                if (assessment != null &&
                    index < assessment.alignments.length &&
                    !assessment.errorType.isSystemFailure &&
                    assessment.errorType != AssessmentErrorType.noSpeech) {
                  isMatched = assessment.alignments[index].isMatch;
                  isErrored = !isMatched && isTarget;
                }

                return PhoneticBreakdownPill(
                  letter: ar,
                  ipa: ph,
                  isTarget: isTarget,
                  isAccurate: isMatched && assessment?.passed == true,
                  isError: isErrored,
                  showIpa: state.activeCaseName != null,
                );
              }),
            ),
          ),

          if (hasBundledPrompt) ...[
            SizedBox(height: 16.h),
            YasserOutlineButton(
              label: state.isPlayingAudioPrompt
                  ? 'ياسر ينطق الكلمة الآن...'
                  : 'اسمع نطق ياسر للكلمة',
              icon: Icon(
                state.isPlayingAudioPrompt
                    ? Icons.volume_up_rounded
                    : Icons.play_circle_fill_rounded,
                color: AppColors.primaryDark,
              ),
              onPressed: state.isBusyWithAudio
                  ? null
                  : context
                        .read<PronunciationGameCubit>()
                        .playYasserAudioPrompt,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemErrorBanner(BuildContext context, String detail) {
    return YasserSurfaceCard(
      backgroundColor: AppColors.infoSoft,
      borderColor: AppColors.info.withValues(alpha: 0.4),
      lipColor: AppColors.info.withValues(alpha: 0.35),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      radius: AppSpacing.radiusM,
      lipDepth: 3.0,
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.info,
            size: 26,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه خدمة الصوت',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentBanner(
    PronunciationAssessment assessment, {
    required bool passed,
  }) {
    final bool isSilence = assessment.errorType == AssessmentErrorType.noSpeech;
    final bool isNoise =
        assessment.errorType == AssessmentErrorType.poorAudioQuality;
    final bool hasIndicator =
        !assessment.errorType.isSystemFailure &&
        !const {
          AssessmentErrorType.noSpeech,
          AssessmentErrorType.poorAudioQuality,
          AssessmentErrorType.uncertain,
          AssessmentErrorType.unrecognized,
        }.contains(assessment.errorType);

    final (
      Color bg,
      Color border,
      IconData icon,
      Color accent,
      String title,
    ) = passed
        ? (
            AppColors.successSoft,
            AppColors.success,
            Icons.celebration_rounded,
            AppColors.successDark,
            'نطق ممتاز يا بطل!',
          )
        : isSilence
        ? (
            AppColors.infoSoft,
            AppColors.info,
            Icons.mic_none_rounded,
            AppColors.info,
            'لم نلتقط صوتاً واضحاً',
          )
        : isNoise
        ? (
            AppColors.warningSoft,
            AppColors.warning,
            Icons.hearing_disabled_rounded,
            AppColors.primaryDeep,
            'المكان حولك صاخب قليلاً',
          )
        : (
            AppColors.accentGoldSoft,
            AppColors.primary,
            Icons.lightbulb_rounded,
            AppColors.primaryDeep,
            'محاولة جميلة! يلا نجرّب تاني',
          );

    return YasserSurfaceCard(
      backgroundColor: bg,
      borderColor: border,
      lipColor: border.withValues(alpha: 0.55),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      radius: AppSpacing.radiusM,
      lipDepth: 3.0,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              shape: YasserShapes.squircle(13),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (hasIndicator)
                  Text(
                    'مؤشر وضوح النطق: ${assessment.overallScore.round()}%',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    'المحاولة غير محتسبة — خذ نفساً وجرّب بهدوء',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (hasIndicator)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final bool lit = passed && i < assessment.stars;
                return Icon(
                  lit ? Icons.star_rounded : Icons.star_border_rounded,
                  color: lit ? AppColors.primary : AppColors.borderStrong,
                  size: 24,
                );
              }),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).scale(begin: const Offset(0.97, 0.97));
  }

  Widget _buildBottomNavigation(
    BuildContext context,
    PronunciationGameState state,
  ) {
    final cubit = context.read<PronunciationGameCubit>();
    final bool canSwitch = state.canChooseWord && state.words.isNotEmpty;
    final bool isLastCard =
        state.words.isNotEmpty &&
        state.currentWordIndex == state.words.length - 1;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'السابقة',
                height: 48,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                onPressed: canSwitch ? cubit.previousWord : null,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Text(
                '${state.currentWordIndex + 1} / ${state.words.length}',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: PrimaryButton(
                label: isLastCard ? 'إنهاء الجلسة' : 'التالية',
                height: 48,
                icon: Icon(
                  isLastCard
                      ? Icons.emoji_events_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                ),
                onPressed: canSwitch
                    ? (isLastCard ? cubit.finishSession : cubit.nextWord)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCompletedView(
    BuildContext context,
    PronunciationGameState state,
  ) {
    final cubit = context.read<PronunciationGameCubit>();

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxFormWidth),
          child: YasserSurfaceCard(
            padding: EdgeInsets.all(24.w),
            radius: AppSpacing.radiusXL,
            lipDepth: 6.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                YasserCharacter(
                  state: YasserAnimationState.celebrating,
                  width: 170.w,
                  height: 220.h,
                  enableTapReaction: true,
                ),
                SizedBox(height: 12.h),
                Text(
                  'أحسنت يا بطل الأصوات!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displaySmall.copyWith(
                    color: AppColors.primaryDeep,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  state.yasserMessage,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: _SessionMetricBox(
                        icon: Icons.star_rounded,
                        label: 'النجوم المكتسبة',
                        value: '${state.totalStarsEarned}',
                        accent: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _SessionMetricBox(
                        icon: Icons.check_circle_rounded,
                        label: 'كلمات متقنة',
                        value: '${state.wordsMasteredCount}',
                        accent: AppColors.success,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _SessionMetricBox(
                        icon: Icons.mic_rounded,
                        label: 'المحاولات',
                        value: '${state.attemptsCount}',
                        accent: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                PrimaryButton(
                  label: state.activeCaseName != null
                      ? 'حفظ والعودة لملف الحالة'
                      : 'العودة لعالم ياسر',
                  icon: const Icon(Icons.home_rounded),
                  onPressed: () => _handleExit(context),
                ),
                SizedBox(height: 10.h),
                SecondaryButton(
                  label: 'جولة تدريب جديدة',
                  icon: const Icon(Icons.replay_rounded),
                  onPressed: cubit.restartSession,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardCounterBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color tint;
  final Color border;
  final Color fg;

  const _RewardCounterBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
    required this.border,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tint,
        shape: YasserShapes.squircle(
          13,
          side: BorderSide(color: border, width: 1.4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            SizedBox(width: 4.w),
            Text(
              value,
              style: AppTextStyles.titleSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 3.w),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionMetricBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _SessionMetricBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: accent.withValues(alpha: 0.10),
        shape: YasserShapes.squircle(
          16,
          side: BorderSide(color: accent.withValues(alpha: 0.28)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 24),
            SizedBox(height: 4.h),
            Text(
              value,
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
