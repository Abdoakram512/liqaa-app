import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/world_painters/world_map_painter.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../data/models/world_models.dart';
import '../../data/world_catalog.dart';
import '../cubits/child_world_cubit.dart';

/// Tab 2 (`مغامرتي`): Illustrated Adventure World Map connecting all 6 locations
/// with responsive landmarks, curved golden paths, and an accessible list view toggle.
class WorldMapView extends StatefulWidget {
  const WorldMapView({super.key});

  @override
  State<WorldMapView> createState() => _WorldMapViewState();
}

class _WorldMapViewState extends State<WorldMapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  bool _accessibleListMode = false;
  WorldRegionId _focusedRegion = WorldRegionId.soundGarden;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _openRegionAdventure(BuildContext context, WorldRegionId region) {
    setState(() => _focusedRegion = region);
    context.read<ChildWorldCubit>().setActiveDestination(region);
    context.push('/adventure/${region.id}');
  }

  @override
  Widget build(BuildContext context) {
    final reduced = YasserMotion.isReducedMotion(context);

    return SafeArea(
      bottom: false,
      child: BlocBuilder<ChildWorldCubit, ChildWorldCubitState>(
        builder: (context, cubitState) {
          final completedRegions = cubitState.worldState.completedAdventureIds
              .map(
                (advId) => WorldCatalog.adventures
                    .where((a) => a.id == advId)
                    .map((a) => a.regionId.id),
              )
              .expand((e) => e)
              .toSet();

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'خريطة عالم ياسر',
                            style: AppTextStyles.headlineMedium,
                          ),
                          Text(
                            'اختار أي مكان تحب تزوره النهاردة (كل المناطق مفتوحة للعب)',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Semantics(
                      button: true,
                      label: _accessibleListMode
                          ? 'التبديل للخريطة المصورة'
                          : 'التبديل لقائمة سهلة القراءة',
                      child: ActionChip(
                        avatar: Icon(
                          _accessibleListMode
                              ? Icons.map_rounded
                              : Icons.format_list_bulleted_rounded,
                          size: 18,
                          color: AppColors.primaryDeep,
                        ),
                        label: Text(
                          _accessibleListMode ? 'خريطة' : 'قائمة',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryDeep,
                          ),
                        ),
                        backgroundColor: AppColors.primaryContainer,
                        onPressed: () => setState(
                          () => _accessibleListMode = !_accessibleListMode,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _accessibleListMode
                    ? _buildAccessibleList(
                        context,
                        completedRegions,
                        cubitState.worldState,
                      )
                    : Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final h = constraints.maxHeight;

                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _shimmerController,
                                      builder: (context, _) {
                                        return RepaintBoundary(
                                          child: CustomPaint(
                                            painter: WorldMapTerrainPainter(
                                              shimmerPhase: reduced
                                                  ? 0.0
                                                  : _shimmerController.value,
                                              completedRegions:
                                                  completedRegions,
                                              selectedRegionId:
                                                  _focusedRegion.id,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  ...kWorldMapAnchors.map((anchor) {
                                    final region = WorldRegionId.fromId(
                                      anchor.regionId,
                                    );
                                    final adv = WorldCatalog.adventureForRegion(
                                      region,
                                    );
                                    final doneSteps = adv.steps
                                        .where(
                                          (s) => cubitState
                                              .worldState
                                              .completedActivityIds
                                              .contains(s.id),
                                        )
                                        .length;
                                    final isFocused = _focusedRegion == region;
                                    final left = (anchor.normalized.dx * w - 58)
                                        .clamp(6.0, w - 122);
                                    final top = (anchor.normalized.dy * h - 34)
                                        .clamp(8.0, h - 76);

                                    return Positioned(
                                      left: left,
                                      top: top,
                                      child: Semantics(
                                        button: true,
                                        label: '${region.titleAr} - اضغط للفتح',
                                        child: InkWell(
                                          onTap: () => _openRegionAdventure(
                                            context,
                                            region,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: AnimatedScale(
                                            duration: YasserMotion.effective(
                                              context,
                                              const Duration(milliseconds: 200),
                                            ),
                                            scale: isFocused ? 1.06 : 1.0,
                                            child: Container(
                                              width: 118,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 7,
                                                  ),
                                              decoration: ShapeDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.96,
                                                ),
                                                shape: YasserShapes.squircle(
                                                  18,
                                                  side: BorderSide(
                                                    color: isFocused
                                                        ? region.accentColor
                                                        : AppColors.borderSoft,
                                                    width: isFocused
                                                        ? 2.4
                                                        : 1.4,
                                                  ),
                                                ),
                                                shadows: const [
                                                  BoxShadow(
                                                    color: AppColors.shadowWarm,
                                                    blurRadius: 10,
                                                    offset: Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        region.icon,
                                                        size: 18,
                                                        color:
                                                            region.accentColor,
                                                      ),
                                                      if (completedRegions
                                                          .contains(
                                                            region.id,
                                                          )) ...[
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        const Icon(
                                                          Icons
                                                              .check_circle_rounded,
                                                          size: 15,
                                                          color:
                                                              AppColors.success,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    region.titleAr,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTextStyles
                                                        .labelSmall
                                                        .copyWith(
                                                          color: AppColors
                                                              .textPrimary,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                  Text(
                                                    '$doneSteps / ${adv.steps.length}',
                                                    style: AppTextStyles
                                                        .labelSmall
                                                        .copyWith(
                                                          color:
                                                              region.deepColor,
                                                          fontSize: 10,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccessibleList(
    BuildContext context,
    Set<String> completedRegions,
    ChildWorldState worldState,
  ) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 24.h),
      itemCount: WorldRegionId.values.length,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final region = WorldRegionId.values[index];
        final adv = WorldCatalog.adventureForRegion(region);
        final done = adv.steps
            .where((s) => worldState.completedActivityIds.contains(s.id))
            .length;
        return YasserSurfaceCard(
          borderColor: region.accentColor.withValues(alpha: 0.45),
          padding: EdgeInsets.all(14.w),
          onTap: () => _openRegionAdventure(context, region),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: ShapeDecoration(
                  color: region.softColor,
                  shape: YasserShapes.squircle(16),
                ),
                child: Icon(region.icon, color: region.accentColor, size: 28),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(region.titleAr, style: AppTextStyles.titleMedium),
                    Text(region.subtitleAr, style: AppTextStyles.bodySmall),
                    SizedBox(height: 4.h),
                    Text(
                      '${adv.titleAr} ($done / ${adv.steps.length})',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: region.deepColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                completedRegions.contains(region.id)
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: completedRegions.contains(region.id)
                    ? AppColors.success
                    : region.accentColor,
              ),
            ],
          ),
        );
      },
    );
  }
}
