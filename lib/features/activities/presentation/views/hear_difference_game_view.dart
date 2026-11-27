import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../world/data/models/world_models.dart';
import '../../../world/data/world_catalog.dart';
import '../widgets/activity_session_scaffold.dart';

/// Game 2 — Hear the Difference (`اسمع الفرق`).
/// Uses reviewed Egyptian Arabic minimal pairs (`WorldCatalog.minimalPairs`)
/// with non-color-only choice affordances and ZERO neural model execution.
class HearDifferenceGameView extends StatefulWidget {
  final ActivityLaunchConfig config;

  const HearDifferenceGameView({super.key, required this.config});

  @override
  State<HearDifferenceGameView> createState() => _HearDifferenceGameViewState();
}

class _HearDifferenceGameViewState extends State<HearDifferenceGameView> {
  late final List<MinimalPairItem> _rounds;
  int _index = 0;
  int _correct = 0;
  bool? _selectedSame;
  bool _answered = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final pool = List<MinimalPairItem>.from(WorldCatalog.minimalPairs)
      ..shuffle(math.Random());
    _rounds = pool.take(4).toList();
  }

  Future<void> _playPairAudio(MinimalPairItem pair) async {
    if (!sl.isRegistered<YasserAudioCoordinator>()) return;
    final coord = sl<YasserAudioCoordinator>();
    await coord.playLineOrFallback(
      scriptId: '${pair.id}_a',
      arabicText: pair.wordA,
    );
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await coord.playLineOrFallback(
      scriptId: '${pair.id}_b',
      arabicText: pair.wordB,
    );
  }

  void _chooseSame(bool choseSame) {
    final pair = _rounds[_index];
    final isRight = choseSame == pair.isSame;
    setState(() {
      _selectedSame = choseSame;
      _answered = true;
      if (isRight) _correct++;
    });
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      sl<YasserAudioCoordinator>().playSfx(
        isRight ? YasserSfx.starReward : YasserSfx.retryGentle,
      );
    }
  }

  Future<void> _advance() async {
    if (_index < _rounds.length - 1) {
      setState(() {
        _index++;
        _selectedSame = null;
        _answered = false;
      });
    } else {
      await recordWorldActivitySafe(
        context,
        ActivityOutcomeRecord(
          id: 'out_${DateTime.now().microsecondsSinceEpoch}',
          activityId: widget.config.stepId ?? 'hear_difference',
          gameType: MiniGameType.hearDifference,
          regionId: widget.config.regionId,
          timestamp: DateTime.now(),
          completed: true,
          discriminationCorrect: _correct,
          discriminationTotal: _rounds.length,
          targetPhonemes: _rounds.map((r) => r.targetPhonemeA).toSet().toList(),
        ),
        config: widget.config,
        markAdventureComplete: widget.config.rewardCollectibleId != null,
      );
      if (mounted) setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pair = _rounds[_index];
    final isRight = _answered && _selectedSame == pair.isSame;
    final msg = !_answered
        ? 'اسمع الكلمتين الأول، وقولي هما زي بعض ولا مختلفين؟'
        : (isRight
              ? 'ممتاز! ودانك صاحية جداً: ${pair.hintAr}'
              : 'ملاحظة حلوة! ${pair.hintAr}');

    return ActivitySessionScaffold(
      config: widget.config,
      currentRound: _index + 1,
      totalRounds: _rounds.length,
      yasserState: !_answered
          ? YasserAnimationState.curious
          : (isRight
                ? YasserAnimationState.celebrating
                : YasserAnimationState.gentleRetry),
      yasserMessage: msg,
      onReplayInstruction: () => _playPairAudio(pair),
      completed: _completed,
      earnedSummaryText:
          'سمعت وميّزت $_correct من ${_rounds.length} أزواج صوتية!',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SoundCard(
                    label: 'الصوت الأول',
                    wordText: pair.wordA,
                    illustrationKey: pair.illustrationKeyA,
                    onTap: () =>
                        sl<YasserAudioCoordinator>().playLineOrFallback(
                          scriptId: '${pair.id}_a',
                          arabicText: pair.wordA,
                        ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _SoundCard(
                    label: 'الصوت الثاني',
                    wordText: pair.wordB,
                    illustrationKey: pair.illustrationKeyB,
                    onTap: () =>
                        sl<YasserAudioCoordinator>().playLineOrFallback(
                          scriptId: '${pair.id}_b',
                          arabicText: pair.wordB,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            OutlinedButton.icon(
              onPressed: () => _playPairAudio(pair),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('تشغيل الكلمتين معاً'),
            ),
            SizedBox(height: 18.h),
            // Non-color-only buttons (distinct icons + labels + borders)
            Row(
              children: [
                Expanded(
                  child: _DiscriminationChoiceButton(
                    icon: Icons.compare_arrows_rounded,
                    title: 'متشابهتان',
                    subtitle: 'نفس الصوت بالظبط',
                    selected: _selectedSame == true,
                    answered: _answered,
                    isCorrectOption: pair.isSame,
                    onTap: _answered ? null : () => _chooseSame(true),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _DiscriminationChoiceButton(
                    icon: Icons.call_split_rounded,
                    title: 'مختلفتان',
                    subtitle: 'صوت مختلف',
                    selected: _selectedSame == false,
                    answered: _answered,
                    isCorrectOption: !pair.isSame,
                    onTap: _answered ? null : () => _chooseSame(false),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            if (_answered)
              PrimaryButton(
                label: _index == _rounds.length - 1 ? 'إنهاء اللعبة' : 'التالي',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _advance,
              ),
          ],
        ),
      ),
    );
  }
}

class _SoundCard extends StatelessWidget {
  final String label;
  final String wordText;
  final String illustrationKey;
  final VoidCallback onTap;

  const _SoundCard({
    required this.label,
    required this.wordText,
    required this.illustrationKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return YasserSurfaceCard(
      padding: EdgeInsets.all(14.w),
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          SizedBox(height: 6.h),
          IllustratedVocabularyWidget(objectKey: illustrationKey, size: 68),
          SizedBox(height: 8.h),
          Text(wordText, style: AppTextStyles.titleLarge),
          SizedBox(height: 4.h),
          const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _DiscriminationChoiceButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool answered;
  final bool isCorrectOption;
  final VoidCallback? onTap;

  const _DiscriminationChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.answered,
    required this.isCorrectOption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.surface;
    Color border = AppColors.borderSoft;
    if (answered && isCorrectOption) {
      bg = AppColors.successSoft;
      border = AppColors.success;
    } else if (answered && selected && !isCorrectOption) {
      bg = AppColors.warningSoft;
      border = AppColors.warning;
    }

    return Semantics(
      button: true,
      selected: selected,
      label: '$title - $subtitle',
      child: YasserSurfaceCard(
        backgroundColor: bg,
        borderColor: border,
        padding: EdgeInsets.all(14.w),
        onTap: onTap,
        child: Column(
          children: [
            Icon(
              answered && isCorrectOption ? Icons.check_circle_rounded : icon,
              size: 32,
              color: answered && isCorrectOption
                  ? AppColors.successDark
                  : AppColors.primaryDark,
            ),
            SizedBox(height: 6.h),
            Text(title, style: AppTextStyles.titleSmall),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
