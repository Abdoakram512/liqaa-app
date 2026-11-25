import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../cubits/pronunciation_game_cubit.dart';
import '../cubits/pronunciation_game_state.dart';
import '../widgets/phonetic_breakdown_pill.dart';
import '../widgets/sound_waveform_wave.dart';
import '../widgets/yasser_speech_feedback_card.dart';

class PronunciationGameView extends StatefulWidget {
  const PronunciationGameView({super.key});

  @override
  State<PronunciationGameView> createState() => _PronunciationGameViewState();
}

class _PronunciationGameViewState extends State<PronunciationGameView> {
  @override
  void initState() {
    super.initState();
    context.read<PronunciationGameCubit>().initializeGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonologicalBackground(
        child: SafeArea(
          child: BlocBuilder<PronunciationGameCubit, PronunciationGameState>(
            builder: (context, state) {
              if (state.status == GameStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              final word = state.currentWord;
              final assessment = state.lastAssessment;

              return Column(
                children: [
                  // Game Header
                  _buildHeader(context, state),

                  // Main Interactive Game Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        children: [
                          SizedBox(height: 12.h),

                          // Target Word Flashcard
                          if (word != null) _buildWordCard(context, state, word),

                          SizedBox(height: 16.h),

                          // Assessment Feedback Banner
                          if (assessment != null) _buildAssessmentBanner(assessment),

                          SizedBox(height: 16.h),

                          // Yasser Avatar & Speech Bubble
                          YasserSpeechFeedbackCard(
                            message: state.yasserMessage,
                            poseString: state.yasserPose,
                            isListening: state.isListening,
                          ),

                          SizedBox(height: 12.h),

                          // Live Waveform while listening
                          SoundWaveformWave(
                            amplitude: state.liveAmplitude,
                            isListening: state.isListening,
                          ),

                          SizedBox(height: 16.h),

                          // Main Mic Control Button
                          _buildMicButton(context, state),

                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Word Navigation Bar
                  _buildBottomNavigation(context, state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PronunciationGameState state) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          Row(
            children: [
              // Stars Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 4.w),
                    Text(
                      '${state.totalStarsEarned}',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              // Mastered Words Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.green, size: 18),
                    SizedBox(width: 4.w),
                    Text(
                      '${state.wordsMasteredCount}',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.psychology_alt_rounded, color: AppColors.primary),
            tooltip: 'مختبر الذكاء الاصطناعي',
            onPressed: () => context.push(AppRoutes.aiLab),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(
    BuildContext context,
    PronunciationGameState state,
    dynamic word,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowWarm,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Target Phoneme Tag
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'صوت حرف [ ${word.targetPhoneme} ] - ${word.targetPhonemeIpa}',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SizedBox(height: 12.h),

          // Main Word Heading
          Text(
            word.wordArabic,
            style: AppTextStyles.displaySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),

          SizedBox(height: 6.h),

          Text(
            '${word.wordTransliteration} (${word.meaningEn})',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: 14.h),

          // Phonemes Breakdown Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(word.expectedPhonemes.length, (index) {
                final String ph = word.expectedPhonemes[index];
                final String ar = index < word.expectedArabicPhonemes.length
                    ? word.expectedArabicPhonemes[index]
                    : ph;
                final bool isTarget = ar == word.targetPhoneme || ph == word.targetPhonemeIpa;

                return PhoneticBreakdownPill(
                  letter: ar,
                  ipa: ph,
                  isTarget: isTarget,
                );
              }),
            ),
          ),

          SizedBox(height: 12.h),

          // Listen to Yasser Prompt Button
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
            icon: Icon(
              state.isPlayingAudioPrompt ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
              size: 20,
            ),
            label: Text(
              'اسمع نطق ياسر للكلمة',
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              context.read<PronunciationGameCubit>().playYasserAudioPrompt();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentBanner(dynamic assessment) {
    final bool passed = assessment.passed;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: passed ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        border: Border.all(
          color: passed ? Colors.green.shade400 : Colors.amber.shade400,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
                color: passed ? Colors.green.shade700 : Colors.amber.shade800,
                size: 28,
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    passed ? 'نطق ممتاز يا بطل!' : 'محاولة حلوة.. يلا نركز!',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: passed ? Colors.green.shade900 : Colors.amber.shade900,
                    ),
                  ),
                  Text(
                    'درجة الدقة: ${assessment.overallScore}%',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: List.generate(3, (i) {
              return Icon(
                i < assessment.stars ? Icons.star_rounded : Icons.star_border_rounded,
                color: Colors.amber,
                size: 24,
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildMicButton(BuildContext context, PronunciationGameState state) {
    final bool isListening = state.isListening;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (isListening) {
              context.read<PronunciationGameCubit>().stopListeningAndEvaluate();
            } else {
              context.read<PronunciationGameCubit>().startListening();
            }
          },
          child: Container(
            width: 84.w,
            height: 84.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isListening
                    ? [Colors.redAccent, Colors.red.shade700]
                    : [AppColors.primary, AppColors.primaryDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isListening ? Colors.red : AppColors.primary).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          isListening ? 'دوس هنا لما تخلص كلام' : 'اضغط على المايك وانطق الكلمة',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: isListening ? Colors.red.shade800 : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation(BuildContext context, PronunciationGameState state) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, 40.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('الكلمة السابقة'),
            onPressed: () => context.read<PronunciationGameCubit>().previousWord(),
          ),
          Text(
            '${state.currentWordIndex + 1} / ${state.words.length}',
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size(0, 40.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
            label: const Text('الكلمة التالية'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            onPressed: () => context.read<PronunciationGameCubit>().nextWord(),
          ),
        ],
      ),
    );
  }
}
