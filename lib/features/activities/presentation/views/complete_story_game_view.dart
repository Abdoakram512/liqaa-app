import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/world_painters/reward_and_scrapbook_painters.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../world/data/models/world_models.dart';
import '../../../world/data/world_catalog.dart';
import '../widgets/activity_session_scaffold.dart';

/// Game 8 — Complete the Story (`أكمل الحكاية`).
/// Yasser narrates short illustrated stories; child chooses the missing
/// illustrated word (with optional safe single-word vocal practice CTA).
/// Executes ZERO neural sentence ASR / ZERO unapproved AI calls.
class CompleteStoryGameView extends StatefulWidget {
  final ActivityLaunchConfig config;

  const CompleteStoryGameView({super.key, required this.config});

  @override
  State<CompleteStoryGameView> createState() => _CompleteStoryGameViewState();
}

class _CompleteStoryGameViewState extends State<CompleteStoryGameView> {
  final List<StoryChallengeItem> _stories = WorldCatalog.stories;
  List<VocabularyWord> _allWords = const [];
  List<VocabularyWord> _choices = const [];
  int _round = 0;
  int _correct = 0;
  String? _pickedId;
  bool _answered = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _allWords = await loadReviewedDictionaryWords();
    _prepareChoices();
  }

  void _prepareChoices() {
    final story = _stories[_round];
    final neededIds = [story.missingWordId, ...story.distractorWordIds];
    final opts = _allWords.where((w) => neededIds.contains(w.id)).toList()
      ..shuffle(math.Random());
    setState(() {
      _choices = opts;
      _pickedId = null;
      _answered = false;
    });
  }

  Future<void> _narrateStory() async {
    final s = _stories[_round];
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      await sl<YasserAudioCoordinator>().playLineOrFallback(
        scriptId: s.id,
        arabicText: '${s.storyPrefixAr} ... ${s.storySuffixAr}',
      );
    }
  }

  void _pick(VocabularyWord w) {
    final story = _stories[_round];
    final right = w.id == story.missingWordId;
    setState(() {
      _pickedId = w.id;
      _answered = true;
      if (right) _correct++;
    });
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      sl<YasserAudioCoordinator>().playSfx(
        right ? YasserSfx.starReward : YasserSfx.retryGentle,
      );
    }
  }

  Future<void> _next() async {
    if (_round < _stories.length - 1) {
      setState(() => _round++);
      _prepareChoices();
    } else {
      await recordWorldActivitySafe(
        context,
        ActivityOutcomeRecord(
          id: 'out_${DateTime.now().microsecondsSinceEpoch}',
          activityId: widget.config.stepId ?? 'complete_the_story',
          gameType: MiniGameType.completeTheStory,
          regionId: widget.config.regionId,
          timestamp: DateTime.now(),
          completed: true,
          listeningCorrect: _correct,
          listeningTotal: _stories.length,
          targetPhonemes: _stories.map((s) => s.targetPhoneme).toSet().toList(),
        ),
        config: widget.config,
        markAdventureComplete: widget.config.rewardCollectibleId != null,
      );
      if (mounted) setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_choices.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final story = _stories[_round];
    final isRight = _answered && _pickedId == story.missingWordId;

    return ActivitySessionScaffold(
      config: widget.config,
      currentRound: _round + 1,
      totalRounds: _stories.length,
      yasserState: !_answered
          ? YasserAnimationState.talking
          : (isRight
                ? YasserAnimationState.celebrating
                : YasserAnimationState.gentleRetry),
      yasserMessage: !_answered
          ? 'اسمع حكاية "${story.titleAr}" واختار الكلمة الناقصة!'
          : (isRight
                ? 'يا سلام! القصة كملت بصورة "${story.missingWordArabic}"!'
                : 'الكلمة المناسبة للحكاية هي "${story.missingWordArabic}"!'),
      onReplayInstruction: _narrateStory,
      completed: _completed,
      earnedSummaryText:
          'كمّلت $_correct من ${_stories.length} حكايات مع ياسر!',
      body: Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: const ScrapbookPagePainter(
                  spineColor: AppColors.worldStoryAccent,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 18.h, 24.w, 18.h),
                  child: Column(
                    children: [
                      Text(story.titleAr, style: AppTextStyles.titleMedium),
                      SizedBox(height: 10.h),
                      Text(
                        '${story.storyPrefixAr}  [ ${_answered ? story.missingWordArabic : '......'} ]  ${story.storySuffixAr}',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineSmall.copyWith(
                          height: 1.6,
                        ),
                      ),
                      if (_answered) ...[
                        SizedBox(height: 10.h),
                        IllustratedVocabularyWidget(
                          objectKey: story.missingWordId,
                          size: 64,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10.w,
                  mainAxisSpacing: 10.h,
                  childAspectRatio: 1.25,
                ),
                itemCount: _choices.length,
                itemBuilder: (_, idx) {
                  final opt = _choices[idx];
                  final isTarget = opt.id == story.missingWordId;
                  final selected = _pickedId == opt.id;
                  return YasserSurfaceCard(
                    backgroundColor: _answered && isTarget
                        ? AppColors.successSoft
                        : (_answered && selected
                              ? AppColors.warningSoft
                              : AppColors.surface),
                    borderColor: _answered && isTarget
                        ? AppColors.success
                        : AppColors.borderSoft,
                    padding: EdgeInsets.all(10.w),
                    onTap: _answered ? null : () => _pick(opt),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IllustratedVocabularyWidget(
                          objectKey: '${opt.id}_${opt.meaningEn}',
                          size: 48,
                        ),
                        SizedBox(height: 4.h),
                        Text(opt.wordArabic, style: AppTextStyles.titleSmall),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_answered) ...[
              PrimaryButton(
                label: _round == _stories.length - 1
                    ? 'إتمام الحكايات'
                    : 'الحكاية التالية',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _next,
              ),
              SizedBox(height: 8.h),
              SecondaryButton(
                label: 'انطق كلمة "${story.missingWordArabic}" بصوتك',
                onPressed: () => context.push(
                  '/activity/name_the_picture?regionId=${widget.config.regionId.id}&phonemes=${story.targetPhoneme}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
