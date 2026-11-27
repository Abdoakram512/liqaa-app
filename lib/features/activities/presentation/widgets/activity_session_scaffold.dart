import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/animation/yasser/yasser_companion_controller.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/confetti_overlay.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/world_painters/reward_and_scrapbook_painters.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_speech_bubble.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../world/data/models/world_models.dart';
import '../../../world/data/world_catalog.dart';
import '../../../world/presentation/cubits/child_world_cubit.dart';

/// Configuration metadata passed to any launched learning mini-game.
class ActivityLaunchConfig {
  final MiniGameType gameType;
  final WorldRegionId regionId;
  final String? adventureId;
  final String? stepId;
  final List<String> targetWordIds;
  final List<String> targetPhonemes;
  final String? rewardCollectibleId;
  final int difficultyLevel;

  const ActivityLaunchConfig({
    required this.gameType,
    this.regionId = WorldRegionId.soundGarden,
    this.adventureId,
    this.stepId,
    this.targetWordIds = const [],
    this.targetPhonemes = const [],
    this.rewardCollectibleId,
    this.difficultyLevel = 1,
  });

  factory ActivityLaunchConfig.fromQuery(
    MiniGameType gameType,
    Map<String, String> query,
  ) {
    final wordsParam = query['words'] ?? '';
    final phonemesParam = query['phonemes'] ?? '';
    return ActivityLaunchConfig(
      gameType: gameType,
      regionId: WorldRegionId.fromId(query['regionId']),
      adventureId: query['adventureId'],
      stepId: query['stepId'],
      targetWordIds: wordsParam
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .toList(),
      targetPhonemes: phonemesParam
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .toList(),
      rewardCollectibleId: query['rewardId'],
      difficultyLevel: int.tryParse(query['difficulty'] ?? '1') ?? 1,
    );
  }
}

List<VocabularyWord>? _cachedReviewedDictionary;

/// Loads reviewed Egyptian Arabic dictionary words safely from assets,
/// falling back cleanly in minimal widget tests if rootBundle is unseeded.
Future<List<VocabularyWord>> loadReviewedDictionaryWords() async {
  if (_cachedReviewedDictionary != null &&
      _cachedReviewedDictionary!.isNotEmpty) {
    return _cachedReviewedDictionary!;
  }
  try {
    final raw = await rootBundle.loadString(
      'assets/pronunciation/egyptian_arabic_dictionary.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['words'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(VocabularyWord.fromJson)
        .toList();
    if (list.isNotEmpty) {
      _cachedReviewedDictionary = list;
      return list;
    }
  } catch (_) {}

  return const [
    VocabularyWord(
      id: 'word_kora',
      wordArabic: 'كورة',
      wordTransliteration: 'Koora',
      meaningEn: 'Ball',
      targetPhoneme: 'ك',
      targetPhonemeIpa: 'k',
      phonemeCategory: 'Plosive',
      difficultyLevel: 1,
      expectedPhonemes: ['k', 'uː', 'r', 'a'],
      expectedArabicPhonemes: ['ك', 'و', 'ر', 'ة'],
      yasserTip: 'كـ كـ كورة!',
    ),
    VocabularyWord(
      id: 'word_samaka',
      wordArabic: 'سمكة',
      wordTransliteration: 'Samaka',
      meaningEn: 'Fish',
      targetPhoneme: 'س',
      targetPhonemeIpa: 's',
      phonemeCategory: 'Fricative',
      difficultyLevel: 1,
      expectedPhonemes: ['s', 'm', 'k', 'a'],
      expectedArabicPhonemes: ['س', 'م', 'ك', 'ة'],
      yasserTip: 'سـ سـ سمكة!',
    ),
    VocabularyWord(
      id: 'word_batta',
      wordArabic: 'بطة',
      wordTransliteration: 'Batta',
      meaningEn: 'Duck',
      targetPhoneme: 'ط',
      targetPhonemeIpa: 'tˤ',
      phonemeCategory: 'Plosive',
      difficultyLevel: 1,
      expectedPhonemes: ['b', 'tˤ', 'a'],
      expectedArabicPhonemes: ['ب', 'ط', 'ة'],
      yasserTip: 'بطة بصوت الطاء!',
    ),
    VocabularyWord(
      id: 'word_2etta',
      wordArabic: 'قطة',
      wordTransliteration: 'Otta',
      meaningEn: 'Cat',
      targetPhoneme: 'ط',
      targetPhonemeIpa: 'tˤ',
      phonemeCategory: 'Plosive',
      difficultyLevel: 1,
      expectedPhonemes: ['ʔ', 'tˤ', 'a'],
      expectedArabicPhonemes: ['ق', 'ط', 'ة'],
      yasserTip: 'قطة ناعمة!',
    ),
    VocabularyWord(
      id: 'word_shams',
      wordArabic: 'شمس',
      wordTransliteration: 'Shams',
      meaningEn: 'Sun',
      targetPhoneme: 'ش',
      targetPhonemeIpa: 'ʃ',
      phonemeCategory: 'Fricative',
      difficultyLevel: 1,
      expectedPhonemes: ['ʃ', 'm', 's'],
      expectedArabicPhonemes: ['ش', 'م', 'س'],
      yasserTip: 'شششمس مشرقة!',
    ),
    VocabularyWord(
      id: 'word_arnab',
      wordArabic: 'أرنب',
      wordTransliteration: 'Arnab',
      meaningEn: 'Rabbit',
      targetPhoneme: 'ر',
      targetPhonemeIpa: 'r',
      phonemeCategory: 'Trill',
      difficultyLevel: 2,
      expectedPhonemes: ['ʔ', 'r', 'n', 'b'],
      expectedArabicPhonemes: ['أ', 'ر', 'ن', 'ب'],
      yasserTip: 'ررر أرنب!',
    ),
    VocabularyWord(
      id: 'word_ketab',
      wordArabic: 'كتاب',
      wordTransliteration: 'Ketab',
      meaningEn: 'Book',
      targetPhoneme: 'ت',
      targetPhonemeIpa: 't',
      phonemeCategory: 'Plosive',
      difficultyLevel: 1,
      expectedPhonemes: ['k', 't', 'aː', 'b'],
      expectedArabicPhonemes: ['ك', 'ت', 'ا', 'ب'],
      yasserTip: 'كـ تـ ا ب!',
    ),
    VocabularyWord(
      id: 'word_kalb',
      wordArabic: 'كلب',
      wordTransliteration: 'Kalb',
      meaningEn: 'Dog',
      targetPhoneme: 'ك',
      targetPhonemeIpa: 'k',
      phonemeCategory: 'Plosive',
      difficultyLevel: 1,
      expectedPhonemes: ['k', 'a', 'l', 'b'],
      expectedArabicPhonemes: ['ك', 'ل', 'ب'],
      yasserTip: 'كـ كلب!',
    ),
  ];
}

/// Shared accessible mini-game session shell unifying top navigation, round
/// progress, Yasser companion speech bubble + sound replay, and celebratory
/// session ending without pressuring the child.
class ActivitySessionScaffold extends StatelessWidget {
  final ActivityLaunchConfig config;
  final int currentRound;
  final int totalRounds;
  final YasserAnimationState yasserState;
  final String yasserMessage;
  final VoidCallback? onReplayInstruction;
  final bool completed;
  final String? earnedSummaryText;
  final Widget body;

  const ActivitySessionScaffold({
    super.key,
    required this.config,
    required this.currentRound,
    required this.totalRounds,
    required this.yasserState,
    required this.yasserMessage,
    this.onReplayInstruction,
    this.completed = false,
    this.earnedSummaryText,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final accent = config.regionId.accentColor;

    return Scaffold(
      body: PhonologicalBackground(
        variant: PhonologicalSceneVariant.soundDiscovery,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
                child: Row(
                  children: [
                    YasserIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'خروج',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.home);
                        }
                      },
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.gameType.titleAr,
                            style: AppTextStyles.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 7,
                              value: totalRounds <= 0
                                  ? 0.0
                                  : (currentRound / totalRounds).clamp(
                                      0.08,
                                      1.0,
                                    ),
                              backgroundColor: AppColors.borderSoft,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: config.regionId.softColor,
                        shape: YasserShapes.squircle(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        child: Text(
                          '$currentRound / $totalRounds',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: config.regionId.deepColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!completed) ...[
                // Yasser Companion Instruction Row
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.h,
                  ),
                  child: Row(
                    children: [
                      YasserCharacter(
                        state: yasserState,
                        width: 64,
                        height: 86,
                        showShadow: false,
                        enableTapReaction: false,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: YasserSpeechBubble(
                          tailDirection: SpeechBubbleTailDirection.start,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  yasserMessage,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (onReplayInstruction != null)
                                IconButton(
                                  tooltip: 'إعادة السماع',
                                  onPressed: onReplayInstruction,
                                  icon: Icon(
                                    Icons.volume_up_rounded,
                                    color: accent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Expanded(
                child: completed
                    ? _AdventureSessionCompletedCard(
                        config: config,
                        summaryText:
                            earnedSummaryText ??
                            'عاش يا بطل! خلصنا النشاط سوا بكل حب ومهارة!',
                      )
                    : body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdventureSessionCompletedCard extends StatefulWidget {
  final ActivityLaunchConfig config;
  final String summaryText;

  const _AdventureSessionCompletedCard({
    required this.config,
    required this.summaryText,
  });

  @override
  State<_AdventureSessionCompletedCard> createState() =>
      _AdventureSessionCompletedCardState();
}

class _AdventureSessionCompletedCardState
    extends State<_AdventureSessionCompletedCard>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confetti;
  late final AnimationController _bloomController;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!YasserMotion.isReducedMotion(context)) {
        _confetti.play();
      }
      if (sl.isRegistered<YasserAudioCoordinator>()) {
        sl<YasserAudioCoordinator>().playSfx(YasserSfx.sessionComplete);
      }
      if (sl.isRegistered<YasserCompanionController>()) {
        sl<YasserCompanionController>().offerFarewell(widget.summaryText);
      }
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _bloomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.config.rewardCollectibleId != null
        ? WorldCatalog.collectibleById(widget.config.rewardCollectibleId!)
        : null;

    return ConfettiCelebrationOverlay(
      confettiController: _confetti,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: YasserSurfaceCard(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _bloomController,
                          builder: (_, _) => CustomPaint(
                            painter: RewardBloomPainter(
                              progress: _bloomController.value,
                              primaryColor:
                                  reward?.accentColor ?? AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      if (reward != null)
                        IllustratedVocabularyWidget(
                          objectKey: reward.illustrationKey,
                          accentColor: reward.accentColor,
                          size: 82,
                        )
                      else
                        const YasserCharacter(
                          state: YasserAnimationState.celebrating,
                          width: 96,
                          height: 126,
                          showShadow: false,
                          enableTapReaction: false,
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  reward != null
                      ? 'مبروك! فتحت: ${reward.titleAr}'
                      : 'أحسنت يا بطل!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium,
                ),
                SizedBox(height: 6.h),
                Text(
                  widget.summaryText,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                if (reward != null &&
                    reward.kind == CollectibleKind.flower) ...[
                  SizedBox(height: 8.h),
                  Text(
                    'اتزرعت الزهرة أوتوماتيك في حديقة بيتك وتقدر تزورها في أي وقت!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.worldGardenDeep,
                    ),
                  ),
                ],
                SizedBox(height: 18.h),
                PrimaryButton(
                  label: reward != null
                      ? 'العودة والاحتفال بالهدية'
                      : 'متابعة الرحلة',
                  icon: const Icon(Icons.home_rounded),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.home);
                    }
                  },
                ),
                SizedBox(height: 10.h),
                SecondaryButton(
                  label: 'استكشاف باقي الخريطة',
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Records an outcome safely if [ChildWorldCubit] exists in the context.
Future<void> recordWorldActivitySafe(
  BuildContext context,
  ActivityOutcomeRecord outcome, {
  ActivityLaunchConfig? config,
  bool markAdventureComplete = false,
}) async {
  final cubit =
      context.read<ChildWorldCubit?>() ??
      (sl.isRegistered<ChildWorldCubit>() ? sl<ChildWorldCubit>() : null);
  if (cubit == null) return;
  await cubit.recordActivityOutcome(
    outcome,
    stepIdToMarkComplete: config?.stepId,
    rewardCollectibleId: config?.rewardCollectibleId,
    markAdventureCompleteId: markAdventureComplete,
    adventureId: config?.adventureId,
  );
}
