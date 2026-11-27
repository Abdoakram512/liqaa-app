import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/world_clippers.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../world/data/models/world_models.dart';
import '../widgets/activity_session_scaffold.dart';

/// Game 6 — Mystery Sound Boxes (`صناديق الأصوات السرية`).
/// Tactile gift boxes clipped with [TreasureLidClipper]; supports BOTH
/// tap-to-match accessible interaction AND drag-and-drop onto open boxes.
/// Executes ZERO neural AI models.
class MysterySoundBoxesGameView extends StatefulWidget {
  final ActivityLaunchConfig config;

  const MysterySoundBoxesGameView({super.key, required this.config});

  @override
  State<MysterySoundBoxesGameView> createState() =>
      _MysterySoundBoxesGameViewState();
}

class _MysterySoundBoxesGameViewState extends State<MysterySoundBoxesGameView> {
  List<VocabularyWord> _boxes = const [];
  List<VocabularyWord> _pictureCards = const [];
  int? _openedBoxIndex;
  final Set<String> _matchedWordIds = {};
  String _feedback = 'افتح صندوق سري واسمع الصوت، وبعدها وصّله بالصورة الصح!';
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await loadReviewedDictionaryWords();
    final selected =
        (widget.config.targetWordIds.isNotEmpty
                ? all
                      .where((w) => widget.config.targetWordIds.contains(w.id))
                      .toList()
                : all.take(3).toList())
            .take(3)
            .toList();
    final cards = List<VocabularyWord>.from(selected)..shuffle(math.Random());
    if (mounted) {
      setState(() {
        _boxes = selected;
        _pictureCards = cards;
      });
    }
  }

  Future<void> _openBox(int index) async {
    final word = _boxes[index];
    setState(() {
      _openedBoxIndex = index;
      _feedback = 'الصندوق قال "${word.wordArabic}"! فين الصورة بتاعته؟';
    });
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      await sl<YasserAudioCoordinator>().playLineOrFallback(
        scriptId: word.id,
        arabicText: word.wordArabic,
        assetPath:
            'assets/pronunciation/prompts/${word.wordTransliteration.toLowerCase()}.wav',
      );
    }
  }

  Future<void> _tryMatchWordToOpenedBox(
    VocabularyWord card, {
    int? targetBoxIndex,
  }) async {
    final idx = targetBoxIndex ?? _openedBoxIndex;
    if (idx == null) {
      setState(() => _feedback = 'افتح صندوق من فوق الأول علشان تسمع صوته!');
      return;
    }
    final targetWord = _boxes[idx];
    if (_matchedWordIds.contains(targetWord.id)) return;

    if (card.id == targetWord.id) {
      setState(() {
        _matchedWordIds.add(targetWord.id);
        _openedBoxIndex = null;
        _feedback = 'برافو! وصّلت "${card.wordArabic}" بالصندوق الصح!';
      });
      if (sl.isRegistered<YasserAudioCoordinator>()) {
        await sl<YasserAudioCoordinator>().playSfx(YasserSfx.starReward);
      }
      if (!mounted) return;
      if (_matchedWordIds.length == _boxes.length) {
        await recordWorldActivitySafe(
          context,
          ActivityOutcomeRecord(
            id: 'out_${DateTime.now().microsecondsSinceEpoch}',
            activityId: widget.config.stepId ?? 'mystery_sound_boxes',
            gameType: MiniGameType.mysterySoundBoxes,
            regionId: widget.config.regionId,
            timestamp: DateTime.now(),
            completed: true,
            listeningCorrect: _matchedWordIds.length,
            listeningTotal: _boxes.length,
            targetPhonemes: _boxes.map((w) => w.targetPhoneme).toSet().toList(),
          ),
          config: widget.config,
          markAdventureComplete: widget.config.rewardCollectibleId != null,
        );
      }
    } else {
      setState(
        () => _feedback =
            'دي "${card.wordArabic}".. جرّب صورة تانية أو اسمع الصندوق تاني!',
      );
      if (sl.isRegistered<YasserAudioCoordinator>()) {
        await sl<YasserAudioCoordinator>().playSfx(YasserSfx.retryGentle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_boxes.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final allMatched = _matchedWordIds.length == _boxes.length;

    return ActivitySessionScaffold(
      config: widget.config,
      currentRound: _matchedWordIds.length.clamp(1, _boxes.length),
      totalRounds: _boxes.length,
      yasserState: allMatched
          ? YasserAnimationState.celebrating
          : YasserAnimationState.curious,
      yasserMessage: _feedback,
      onReplayInstruction: _openedBoxIndex != null
          ? () => _openBox(_openedBoxIndex!)
          : null,
      completed: _completed,
      earnedSummaryText: 'فتحت كل الصناديق السرية ووصلت الأصوات صح!',
      body: Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          children: [
            Text(
              '١. المس الصندوق لتفتحه وتسمع الصوت',
              style: AppTextStyles.titleSmall,
            ),
            SizedBox(height: 10.h),
            Row(
              children: List.generate(_boxes.length, (i) {
                final word = _boxes[i];
                final matched = _matchedWordIds.contains(word.id);
                final isOpen = _openedBoxIndex == i;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5.w),
                    child: DragTarget<VocabularyWord>(
                      onAcceptWithDetails: (details) =>
                          _tryMatchWordToOpenedBox(
                            details.data,
                            targetBoxIndex: i,
                          ),
                      builder: (context, candidates, _) {
                        final highlighted = candidates.isNotEmpty || isOpen;
                        return Semantics(
                          button: true,
                          label: 'صندوق سري رقم ${i + 1}',
                          child: InkWell(
                            onTap: matched ? null : () => _openBox(i),
                            borderRadius: BorderRadius.circular(18),
                            child: Column(
                              children: [
                                AnimatedSlide(
                                  duration: YasserMotion.effective(
                                    context,
                                    const Duration(milliseconds: 220),
                                  ),
                                  offset: Offset(
                                    0,
                                    (isOpen || matched) ? -0.18 : 0.0,
                                  ),
                                  child: ClipPath(
                                    clipper: const TreasureLidClipper(),
                                    child: Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: matched
                                            ? AppColors.success
                                            : (highlighted
                                                  ? AppColors.primary
                                                  : AppColors.primaryDark),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 92,
                                  width: double.infinity,
                                  decoration: ShapeDecoration(
                                    color: matched
                                        ? AppColors.successSoft
                                        : (highlighted
                                              ? AppColors.primaryContainer
                                              : AppColors.surface),
                                    shape: YasserShapes.squircle(
                                      16,
                                      side: BorderSide(
                                        color: matched
                                            ? AppColors.success
                                            : (highlighted
                                                  ? AppColors.primary
                                                  : AppColors.borderSoft),
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: matched
                                        ? IllustratedVocabularyWidget(
                                            objectKey:
                                                '${word.id}_${word.meaningEn}',
                                            size: 56,
                                          )
                                        : Icon(
                                            isOpen
                                                ? Icons.volume_up_rounded
                                                : Icons.card_giftcard_rounded,
                                            size: 36,
                                            color: AppColors.primary,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 22.h),
            Text(
              '٢. اختار أو اسحب الصورة للصندوق المفتوح',
              style: AppTextStyles.titleSmall,
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10.w,
                  mainAxisSpacing: 10.h,
                  childAspectRatio: 0.85,
                ),
                itemCount: _pictureCards.length,
                itemBuilder: (context, idx) {
                  final card = _pictureCards[idx];
                  final alreadyMatched = _matchedWordIds.contains(card.id);
                  final tile = Opacity(
                    opacity: alreadyMatched ? 0.35 : 1.0,
                    child: YasserSurfaceCard(
                      padding: EdgeInsets.all(10.w),
                      onTap: alreadyMatched
                          ? null
                          : () => _tryMatchWordToOpenedBox(card),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IllustratedVocabularyWidget(
                            objectKey: '${card.id}_${card.meaningEn}',
                            size: 56,
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            card.wordArabic,
                            style: AppTextStyles.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );

                  if (alreadyMatched) return tile;
                  return Draggable<VocabularyWord>(
                    data: card,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: IllustratedVocabularyWidget(
                          objectKey: '${card.id}_${card.meaningEn}',
                          size: 72,
                        ),
                      ),
                    ),
                    child: tile,
                  );
                },
              ),
            ),
            if (allMatched)
              PrimaryButton(
                label: 'افتح هديتك!',
                icon: const Icon(Icons.celebration_rounded),
                onPressed: () => setState(() => _completed = true),
              ),
          ],
        ),
      ),
    );
  }
}
