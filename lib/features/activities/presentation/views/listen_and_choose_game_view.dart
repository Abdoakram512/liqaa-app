import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../world/data/models/world_models.dart';
import '../widgets/activity_session_scaffold.dart';

/// Game 3 — Listen and Choose (`اسمع واختار`).
/// Randomizes picture positions on every round (never reveals answers by color
/// or fixed slot) and executes ZERO neural AI models.
class ListenAndChooseGameView extends StatefulWidget {
  final ActivityLaunchConfig config;

  const ListenAndChooseGameView({super.key, required this.config});

  @override
  State<ListenAndChooseGameView> createState() =>
      _ListenAndChooseGameViewState();
}

class _ListenAndChooseGameViewState extends State<ListenAndChooseGameView> {
  final math.Random _rng = math.Random();
  List<VocabularyWord> _allWords = const [];
  List<VocabularyWord> _targets = const [];
  List<VocabularyWord> _options = const [];

  int _round = 0;
  int _correctCount = 0;
  String? _selectedWordId;
  bool _answered = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _initRounds();
  }

  Future<void> _initRounds() async {
    final all = await loadReviewedDictionaryWords();
    final preferred = widget.config.targetWordIds.isNotEmpty
        ? all.where((w) => widget.config.targetWordIds.contains(w.id)).toList()
        : all.take(4).toList();
    final targets = (preferred.isNotEmpty ? preferred : all.take(4).toList())
      ..shuffle(_rng);
    _allWords = all;
    _targets = targets.take(4).toList();
    _prepareOptions();
  }

  void _prepareOptions() {
    final target = _targets[_round];
    final distractors = _allWords.where((w) => w.id != target.id).toList()
      ..shuffle(_rng);
    final options = [target, ...distractors.take(3)]..shuffle(_rng);
    setState(() {
      _options = options;
      _selectedWordId = null;
      _answered = false;
    });
  }

  Future<void> _playPrompt() async {
    final target = _targets[_round];
    if (!sl.isRegistered<YasserAudioCoordinator>()) return;
    await sl<YasserAudioCoordinator>().playLineOrFallback(
      scriptId: target.id,
      arabicText: target.wordArabic,
      assetPath:
          'assets/pronunciation/prompts/${target.wordTransliteration.toLowerCase()}.wav',
    );
  }

  void _pick(VocabularyWord choice) {
    final target = _targets[_round];
    final isRight = choice.id == target.id;
    setState(() {
      _selectedWordId = choice.id;
      _answered = true;
      if (isRight) _correctCount++;
    });
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      sl<YasserAudioCoordinator>().playSfx(
        isRight ? YasserSfx.starReward : YasserSfx.retryGentle,
      );
    }
  }

  Future<void> _next() async {
    if (_round < _targets.length - 1) {
      setState(() => _round++);
      _prepareOptions();
    } else {
      await recordWorldActivitySafe(
        context,
        ActivityOutcomeRecord(
          id: 'out_${DateTime.now().microsecondsSinceEpoch}',
          activityId: widget.config.stepId ?? 'listen_and_choose',
          gameType: MiniGameType.listenAndChoose,
          regionId: widget.config.regionId,
          timestamp: DateTime.now(),
          completed: true,
          listeningCorrect: _correctCount,
          listeningTotal: _targets.length,
          targetPhonemes: _targets.map((w) => w.targetPhoneme).toSet().toList(),
        ),
        config: widget.config,
        markAdventureComplete: widget.config.rewardCollectibleId != null,
      );
      if (mounted) setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targets.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final target = _targets[_round];
    final isRight = _answered && _selectedWordId == target.id;

    return ActivitySessionScaffold(
      config: widget.config,
      currentRound: _round + 1,
      totalRounds: _targets.length,
      yasserState: !_answered
          ? YasserAnimationState.talking
          : (isRight
                ? YasserAnimationState.celebrating
                : YasserAnimationState.gentleRetry),
      yasserMessage: !_answered
          ? 'فين صورة "${target.wordArabic}"؟ اسمع واختار!'
          : (isRight
                ? 'شاطر يا بطل! لقيت "${target.wordArabic}"!'
                : 'قريبة! الصورة الصح هي "${target.wordArabic}".'),
      onReplayInstruction: _playPrompt,
      completed: _completed,
      earnedSummaryText:
          'اخترت $_correctCount من ${_targets.length} صور بتركيز ممتاز!',
      body: Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: _playPrompt,
              icon: const Icon(Icons.volume_up_rounded),
              label: Text('اسمع الكلمة: "${target.wordArabic}"'),
            ),
            SizedBox(height: 14.h),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 0.95,
                ),
                itemCount: _options.length,
                itemBuilder: (context, idx) {
                  final opt = _options[idx];
                  final isSelected = _selectedWordId == opt.id;
                  final isTarget = opt.id == target.id;

                  Color bg = AppColors.surface;
                  Color border = AppColors.borderSoft;
                  IconData? badgeIcon;
                  if (_answered && isTarget) {
                    bg = AppColors.successSoft;
                    border = AppColors.success;
                    badgeIcon = Icons.check_circle_rounded;
                  } else if (_answered && isSelected && !isTarget) {
                    bg = AppColors.warningSoft;
                    border = AppColors.warning;
                    badgeIcon = Icons.refresh_rounded;
                  }

                  return Semantics(
                    button: true,
                    label: opt.wordArabic,
                    child: YasserSurfaceCard(
                      backgroundColor: bg,
                      borderColor: border,
                      padding: EdgeInsets.all(12.w),
                      onTap: _answered ? null : () => _pick(opt),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IllustratedVocabularyWidget(
                                  objectKey: '${opt.id}_${opt.meaningEn}',
                                  semanticLabel: opt.wordArabic,
                                  size: 86,
                                ),
                                if (_answered) ...[
                                  SizedBox(height: 8.h),
                                  Text(
                                    opt.wordArabic,
                                    style: AppTextStyles.titleSmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (badgeIcon != null)
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Icon(
                                badgeIcon,
                                color: isTarget
                                    ? AppColors.successDark
                                    : AppColors.warningDark,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_answered)
              PrimaryButton(
                label: _round == _targets.length - 1
                    ? 'إنهاء اللعبة'
                    : 'التالي',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _next,
              ),
          ],
        ),
      ),
    );
  }
}
