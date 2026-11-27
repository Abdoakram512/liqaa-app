import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/animation/yasser/yasser_companion_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/world_painters/reward_and_scrapbook_painters.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../data/models/world_models.dart';
import '../../data/world_catalog.dart';
import '../cubits/child_world_cubit.dart';

/// Tab 4 (`كنوزي`): Personalized Adventure Book with scrapbook styling,
/// discovered illustrated vocabulary, garden/animal collectibles, badges,
/// and clearly separated progress milestones (zero clinical scores or punishment).
class AdventureBookView extends StatefulWidget {
  const AdventureBookView({super.key});

  @override
  State<AdventureBookView> createState() => _AdventureBookViewState();
}

class _AdventureBookViewState extends State<AdventureBookView> {
  int _chapterIndex = 0;

  static const _chapters = [
    'كلماتي',
    'الزهور والحيوانات',
    'ملصقات وأوسمة',
    'رحلتي',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: BlocBuilder<ChildWorldCubit, ChildWorldCubitState>(
        builder: (context, cubitState) {
          final profile = cubitState.activeProfile;
          final world = cubitState.worldState;

          return Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'كتاب مغامرة ${profile.displayName}',
                  style: AppTextStyles.headlineMedium,
                ),
                Text(
                  'كل كلمة وزهرة وملصق جمعتهم محفوظين هنا!',
                  style: AppTextStyles.bodySmall,
                ),
                SizedBox(height: 10.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_chapters.length, (i) {
                      final selected = _chapterIndex == i;
                      return Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: ChoiceChip(
                          label: Text(_chapters[i]),
                          selected: selected,
                          selectedColor: AppColors.worldStorySoft,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            color: selected
                                ? AppColors.worldStoryDeep
                                : AppColors.textPrimary,
                          ),
                          onSelected: (_) {
                            setState(() => _chapterIndex = i);
                            if (i == 2 || i == 1) {
                              context
                                  .read<ChildWorldCubit>()
                                  .markCollectiblesSeen();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(height: 10.h),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: const ScrapbookPagePainter(
                        spineColor: AppColors.worldStoryAccent,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18.w, 18.h, 24.w, 18.h),
                        child: AnimatedSwitcher(
                          duration: YasserMotion.effective(
                            context,
                            const Duration(milliseconds: 260),
                          ),
                          child: switch (_chapterIndex) {
                            0 => _buildWordsChapter(world),
                            1 => _buildNatureChapter(world),
                            2 => _buildBadgesChapter(world),
                            _ => _buildJourneyChapter(world),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static const Map<String, String> _wordArabicLabels = {
    'word_kora': 'كورة',
    'word_samaka': 'سمكة',
    'word_batta': 'بطة',
    'word_2etta': 'قطة',
    'word_shams': 'شمس',
    'word_arnab': 'أرنب',
    'word_ketab': 'كتاب',
    'word_kalb': 'كلب',
    'word_sayara': 'سيارة',
    'word_shagara': 'شجرة',
    'word_warda': 'وردة',
    'word_asfour': 'عصفور',
    'word_tuffaha': 'تفاحة',
    'word_moza': 'موزة',
    'word_bab': 'باب',
    'word_beit': 'بيت',
    'word_qamar': 'قمر',
    'word_nagma': 'نجمة',
    'word_meya': 'مية',
    'word_laban': 'لبن',
    'word_khobz': 'خبز',
    'word_gabal': 'جبل',
    'word_bahr': 'بحر',
    'word_fil': 'فيل',
    'word_asad': 'أسد',
    'word_zerafa': 'زرافة',
    'word_hodhod': 'هدهد',
    'word_farasha': 'فراشة',
  };

  Widget _buildWordsChapter(ChildWorldState world) {
    final words = world.discoveredWordIds.toList();
    if (words.isEmpty) {
      return Center(
        key: const ValueKey('words_empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IllustratedVocabularyWidget(objectKey: 'ketab', size: 72),
            SizedBox(height: 10.h),
            Text(
              'لسه ما فتحتش كلمات في ألبومك!',
              style: AppTextStyles.titleMedium,
            ),
            SizedBox(height: 4.h),
            Text(
              'العب "اكتشف الكلمة" في حديقة الأصوات عشان تظهر كلماتك هنا.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      key: const ValueKey('words_grid'),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 1.05,
      ),
      itemCount: words.length,
      itemBuilder: (context, idx) {
        final wId = words[idx];
        final cleanSlug = wId.replaceFirst('word_', '');
        final arabicLabel = _wordArabicLabels[wId] ?? cleanSlug;
        return YasserSurfaceCard(
          padding: EdgeInsets.all(10.w),
          onTap: () {
            if (sl.isRegistered<YasserCompanionController>()) {
              sl<YasserCompanionController>().speakLine(
                scriptId: wId,
                arabicText: arabicLabel,
                bundledAssetPath: 'assets/pronunciation/prompts/$cleanSlug.wav',
              );
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IllustratedVocabularyWidget(objectKey: wId, size: 54),
              SizedBox(height: 6.h),
              Text(
                arabicLabel,
                style: AppTextStyles.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNatureChapter(ChildWorldState world) {
    final items = WorldCatalog.collectibles
        .where(
          (c) =>
              (c.kind == CollectibleKind.flower ||
                  c.kind == CollectibleKind.animal) &&
              world.unlockedCollectibleIds.contains(c.id),
        )
        .toList();

    return ListView.separated(
      key: const ValueKey('nature_list'),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: 10.h),
      itemBuilder: (_, idx) {
        final item = items[idx];
        final planted = world.plantedFlowerIds.contains(item.id);
        return YasserSurfaceCard(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              IllustratedVocabularyWidget(
                objectKey: item.illustrationKey,
                accentColor: item.accentColor,
                size: 46,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titleAr, style: AppTextStyles.titleSmall),
                    Text(item.descriptionAr, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (item.kind == CollectibleKind.flower)
                Chip(
                  label: Text(planted ? 'مزروعة في الحديقة' : 'جاهزة للزراعة'),
                  backgroundColor: planted
                      ? AppColors.worldGardenSoft
                      : AppColors.surfaceSubtle,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgesChapter(ChildWorldState world) {
    final items = WorldCatalog.collectibles
        .where(
          (c) =>
              c.kind != CollectibleKind.flower &&
              c.kind != CollectibleKind.animal &&
              world.unlockedCollectibleIds.contains(c.id),
        )
        .toList();

    return ListView.separated(
      key: const ValueKey('badges_list'),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: 10.h),
      itemBuilder: (_, idx) {
        final item = items[idx];
        return YasserSurfaceCard(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              IllustratedVocabularyWidget(
                objectKey: item.illustrationKey,
                accentColor: item.accentColor,
                size: 44,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titleAr, style: AppTextStyles.titleSmall),
                    Text(item.descriptionAr, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJourneyChapter(ChildWorldState world) {
    return ListView(
      key: const ValueKey('journey_summary'),
      children: [
        _JourneyMetricTile(
          icon: Icons.touch_app_rounded,
          color: AppColors.primary,
          title: 'مشاركات ومغامرات مكتملة',
          value:
              '${world.completedActivityIds.length} نشاط • ${world.completedAdventureIds.length} مغامرة',
        ),
        SizedBox(height: 10.h),
        _JourneyMetricTile(
          icon: Icons.hearing_rounded,
          color: AppColors.worldGardenAccent,
          title: 'ألعاب الاستماع والتمييز',
          value:
              '${world.listeningCorrect + world.discriminationCorrect} من ${world.listeningTotal + world.discriminationTotal} محاولة استماع',
        ),
        SizedBox(height: 10.h),
        _JourneyMetricTile(
          icon: Icons.record_voice_over_rounded,
          color: AppColors.worldIslandAccent,
          title: 'محاولات النطق مع ياسر',
          value:
              '${world.pronunciationPassedCount} نجاح من ${world.pronunciationAttempts} جولة',
        ),
        if (world.inconclusiveCount > 0) ...[
          SizedBox(height: 10.h),
          _JourneyMetricTile(
            icon: Icons.mic_off_rounded,
            color: AppColors.textMuted,
            title: 'تسجيلات غير واضحة (لم تُحسب كخطأ)',
            value: '${world.inconclusiveCount}',
          ),
        ],
      ],
    );
  }
}

class _JourneyMetricTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _JourneyMetricTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return YasserSurfaceCard(
      padding: EdgeInsets.all(14.w),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: color.withValues(alpha: 0.14),
              shape: YasserShapes.squircle(14),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                Text(value, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
