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

/// Game 7 — Sound Detective (`محقق الأصوات`).
/// Interactive illustrated scene where the child collects objects matching
/// Yasser's target phoneme into a magnifying basket (tap or drag-and-drop).
/// Executes ZERO neural AI models.
class SoundDetectiveGameView extends StatefulWidget {
  final ActivityLaunchConfig config;

  const SoundDetectiveGameView({super.key, required this.config});

  @override
  State<SoundDetectiveGameView> createState() => _SoundDetectiveGameViewState();
}

class _SoundDetectiveGameViewState extends State<SoundDetectiveGameView> {
  String _targetPhoneme = 'ك';
  List<VocabularyWord> _sceneObjects = const [];
  final Set<String> _foundIds = {};
  int _mistakes = 0;
  String? _hintMessage;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _setupScene();
  }

  Future<void> _setupScene() async {
    final all = await loadReviewedDictionaryWords();
    final requestedPhoneme = widget.config.targetPhonemes.isNotEmpty
        ? widget.config.targetPhonemes.first
        : 'ك';

    final matching = all
        .where(
          (w) =>
              w.targetPhoneme == requestedPhoneme ||
              w.wordArabic.startsWith(requestedPhoneme),
        )
        .take(3)
        .toList();

    final String effectivePhoneme = matching.isNotEmpty
        ? requestedPhoneme
        : 'ك';
    final finalMatches = matching.isNotEmpty
        ? matching
        : all.where((w) => w.wordArabic.startsWith('ك')).take(3).toList();

    final distractors = all
        .where(
          (w) =>
              !finalMatches.any((m) => m.id == w.id) &&
              !w.wordArabic.startsWith(effectivePhoneme),
        )
        .take(3)
        .toList();

    final combined = [...finalMatches, ...distractors]..shuffle();
    if (mounted) {
      setState(() {
        _targetPhoneme = effectivePhoneme;
        _sceneObjects = combined;
      });
    }
  }

  bool _isTarget(VocabularyWord w) =>
      w.targetPhoneme == _targetPhoneme ||
      w.wordArabic.startsWith(_targetPhoneme);

  Future<void> _collectWord(VocabularyWord w) async {
    if (_foundIds.contains(w.id)) return;
    if (_isTarget(w)) {
      setState(() {
        _foundIds.add(w.id);
        _hintMessage =
            'لقيتها يا محقق! "${w.wordArabic}" فيها صوت ($_targetPhoneme)!';
      });
      if (sl.isRegistered<YasserAudioCoordinator>()) {
        await sl<YasserAudioCoordinator>().playSfx(YasserSfx.starReward);
      }
      if (!mounted) return;
      final totalTargets = _sceneObjects.where(_isTarget).length;
      if (_foundIds.length == totalTargets) {
        await recordWorldActivitySafe(
          context,
          ActivityOutcomeRecord(
            id: 'out_${DateTime.now().microsecondsSinceEpoch}',
            activityId: widget.config.stepId ?? 'sound_detective',
            gameType: MiniGameType.soundDetective,
            regionId: widget.config.regionId,
            timestamp: DateTime.now(),
            completed: true,
            listeningCorrect: totalTargets,
            listeningTotal: totalTargets + _mistakes,
            targetPhonemes: [_targetPhoneme],
          ),
          config: widget.config,
          markAdventureComplete: widget.config.rewardCollectibleId != null,
        );
      }
    } else {
      setState(() {
        _mistakes++;
        _hintMessage =
            'دي "${w.wordArabic}".. مش بتبدأ بصوت ($_targetPhoneme)، دور معايا تاني!';
      });
      if (sl.isRegistered<YasserAudioCoordinator>()) {
        await sl<YasserAudioCoordinator>().playSfx(YasserSfx.retryGentle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sceneObjects.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final totalTargets = _sceneObjects.where(_isTarget).length;
    final done = _foundIds.length == totalTargets;

    return ActivitySessionScaffold(
      config: widget.config,
      currentRound: _foundIds.length.clamp(1, totalTargets),
      totalRounds: totalTargets,
      yasserState: done
          ? YasserAnimationState.celebrating
          : YasserAnimationState.curious,
      yasserMessage:
          _hintMessage ??
          'يا محقق ياسر! جمّع كل الحاجات اللي فيها صوت حرف ($_targetPhoneme) ($totalTargets حاجات).',
      completed: _completed,
      earnedSummaryText: 'لقيت كل كلمات صوت ($_targetPhoneme) بذكاء!',
      body: Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          children: [
            // Detective Basket DragTarget
            DragTarget<VocabularyWord>(
              onAcceptWithDetails: (d) => _collectWord(d.data),
              builder: (context, candidates, _) {
                return YasserSurfaceCard(
                  backgroundColor: candidates.isNotEmpty
                      ? AppColors.primaryContainer
                      : AppColors.worldGardenSoft,
                  borderColor: AppColors.worldGardenAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.worldGardenDeep,
                        size: 26,
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          'سلة المحقق لحرف "$_targetPhoneme" (${_foundIds.length} / $totalTargets)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.worldGardenDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 14.h),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 1.05,
                ),
                itemCount: _sceneObjects.length,
                itemBuilder: (context, idx) {
                  final item = _sceneObjects[idx];
                  final found = _foundIds.contains(item.id);

                  final card = YasserSurfaceCard(
                    backgroundColor: found
                        ? AppColors.successSoft
                        : AppColors.surface,
                    borderColor: found
                        ? AppColors.success
                        : AppColors.borderSoft,
                    padding: EdgeInsets.all(10.w),
                    onTap: found ? null : () => _collectWord(item),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IllustratedVocabularyWidget(
                                objectKey: '${item.id}_${item.meaningEn}',
                                semanticLabel: item.wordArabic,
                                size: 68,
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                item.wordArabic,
                                style: AppTextStyles.titleSmall,
                              ),
                            ],
                          ),
                        ),
                        if (found)
                          const Positioned(
                            top: 0,
                            left: 0,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.successDark,
                            ),
                          ),
                      ],
                    ),
                  );

                  if (found) return card;
                  return Draggable<VocabularyWord>(
                    data: item,
                    feedback: Material(
                      color: Colors.transparent,
                      child: IllustratedVocabularyWidget(
                        objectKey: '${item.id}_${item.meaningEn}',
                        size: 74,
                      ),
                    ),
                    child: card,
                  );
                },
              ),
            ),
            if (done)
              PrimaryButton(
                label: 'تم التحقيق بنجاح!',
                icon: const Icon(Icons.check_circle_rounded),
                onPressed: () => setState(() => _completed = true),
              ),
          ],
        ),
      ),
    );
  }
}
