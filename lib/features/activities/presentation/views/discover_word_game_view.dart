import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../world/data/models/world_models.dart';
import '../../../world/data/world_catalog.dart';
import '../../../world/presentation/cubits/child_world_cubit.dart';
import '../widgets/activity_session_scaffold.dart';

/// Game 1 — Discover the Word (`اكتشف الكلمة`).
/// Non-evaluative exploration game executing ZERO AI inference.
class DiscoverWordGameView extends StatefulWidget {
  final ActivityLaunchConfig config;

  const DiscoverWordGameView({super.key, required this.config});

  @override
  State<DiscoverWordGameView> createState() => _DiscoverWordGameViewState();
}

class _DiscoverWordGameViewState extends State<DiscoverWordGameView> {
  List<VocabularyWord> _words = const [];
  int _index = 0;
  bool _exploredCurrent = false;
  bool _completed = false;
  double _bouncePhase = 0.0;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final all = await loadReviewedDictionaryWords();
    final targeted = widget.config.targetWordIds.isNotEmpty
        ? all.where((w) => widget.config.targetWordIds.contains(w.id)).toList()
        : WorldContentAdapter.selectWords(
            dictionary: all,
            targetPhonemes: widget.config.targetPhonemes,
            maxDifficulty: widget.config.difficultyLevel,
            limit: 4,
          );
    if (mounted) {
      setState(
        () => _words = targeted.isNotEmpty ? targeted : all.take(4).toList(),
      );
    }
  }

  Future<void> _exploreWord(VocabularyWord word) async {
    setState(() {
      _exploredCurrent = true;
      _bouncePhase += 1.0;
    });
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      await sl<YasserAudioCoordinator>().playLineOrFallback(
        scriptId: word.id,
        arabicText: word.wordArabic,
        assetPath:
            'assets/pronunciation/prompts/${word.wordTransliteration.toLowerCase()}.wav',
      );
    }
    final worldCubit = sl.isRegistered<ChildWorldCubit>()
        ? sl<ChildWorldCubit>()
        : (mounted ? context.read<ChildWorldCubit?>() : null);
    await worldCubit?.markWordDiscovered(word.id);
  }

  Future<void> _next() async {
    if (_index < _words.length - 1) {
      setState(() {
        _index++;
        _exploredCurrent = false;
      });
    } else {
      await recordWorldActivitySafe(
        context,
        ActivityOutcomeRecord(
          id: 'out_${DateTime.now().microsecondsSinceEpoch}',
          activityId: widget.config.stepId ?? 'discover_word',
          gameType: MiniGameType.discoverWord,
          regionId: widget.config.regionId,
          timestamp: DateTime.now(),
          completed: true,
          targetPhonemes: _words.map((w) => w.targetPhoneme).toSet().toList(),
        ),
        config: widget.config,
        markAdventureComplete: widget.config.rewardCollectibleId != null,
      );
      if (mounted) setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_words.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final word = _words[_index];
    final yasserMsg = _exploredCurrent
        ? word.yasserTip
        : 'المس صورة "${word.wordArabic}" واسمع صوتها مع ياسر!';

    return ActivitySessionScaffold(
      config: widget.config,
      currentRound: _index + 1,
      totalRounds: _words.length,
      yasserState: _exploredCurrent
          ? YasserAnimationState.happy
          : YasserAnimationState.pointing,
      yasserMessage: yasserMsg,
      onReplayInstruction: () => _exploreWord(word),
      completed: _completed,
      earnedSummaryText:
          'اكتشفت ${_words.length} كلمات جديدة وأضفتهم لكتاب مغامرتك!',
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Semantics(
                    button: true,
                    label: 'استكشاف كلمة ${word.wordArabic}',
                    child: GestureDetector(
                      onTap: () => _exploreWord(word),
                      child: YasserSurfaceCard(
                        padding: EdgeInsets.all(22.w),
                        borderColor: _exploredCurrent
                            ? AppColors.primary
                            : AppColors.borderSoft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              duration: YasserMotion.effective(
                                context,
                                const Duration(milliseconds: 240),
                              ),
                              scale: _exploredCurrent ? 1.08 : 1.0,
                              child: IllustratedVocabularyWidget(
                                objectKey: '${word.id}_${word.meaningEn}',
                                semanticLabel: word.wordArabic,
                                size: 124,
                                bounceValue: _bouncePhase,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            Text(
                              word.wordArabic,
                              style: AppTextStyles.displayMedium,
                            ),
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8.w,
                              children: word.expectedArabicPhonemes.map((ch) {
                                final isTarget = ch == word.targetPhoneme;
                                return Chip(
                                  label: Text(
                                    ch,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: isTarget
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  backgroundColor: isTarget
                                      ? AppColors.primary
                                      : AppColors.surfaceSubtle,
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _exploredCurrent
                                  ? 'تمت إضافة الكلمة لألبومك!'
                                  : 'اضغط على الصورة للاستماع',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: _exploredCurrent
                                    ? AppColors.successDark
                                    : AppColors.primaryDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PrimaryButton(
              label: _index == _words.length - 1
                  ? 'إنهاء الاستكشاف'
                  : 'الكلمة التالية',
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: _exploredCurrent ? _next : () => _exploreWord(word),
            ),
          ],
        ),
      ),
    );
  }
}
