import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';

class YasserWorldNavDestination {
  final String labelAr;
  final IconData icon;
  final IconData activeIcon;
  final Color accent;

  const YasserWorldNavDestination({
    required this.labelAr,
    required this.icon,
    required this.activeIcon,
    required this.accent,
  });
}

/// Custom handcrafted world navigation bar (`عالمي` / `مغامرتي` / `ألعابي` / `كنوزي`)
/// with comfortable touch targets (>= 48dp), clean SafeArea support, and subtle selection motion.
class YasserWorldNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unseenTreasuresCount;

  const YasserWorldNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unseenTreasuresCount = 0,
  });

  static const List<YasserWorldNavDestination> destinations = [
    YasserWorldNavDestination(
      labelAr: 'عالمي',
      icon: Icons.cottage_outlined,
      activeIcon: Icons.cottage_rounded,
      accent: AppColors.worldHomeAccent,
    ),
    YasserWorldNavDestination(
      labelAr: 'مغامرتي',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      accent: AppColors.worldGardenAccent,
    ),
    YasserWorldNavDestination(
      labelAr: 'ألعابي',
      icon: Icons.extension_outlined,
      activeIcon: Icons.extension_rounded,
      accent: AppColors.worldIslandAccent,
    ),
    YasserWorldNavDestination(
      labelAr: 'كنوزي',
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
      accent: AppColors.worldStoryAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final duration = YasserMotion.effective(
      context,
      const Duration(milliseconds: 220),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 10.h),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            shape: YasserShapes.squircle(
              24,
              side: const BorderSide(color: AppColors.borderSoft, width: 1.5),
            ),
            shadows: const [
              BoxShadow(
                color: AppColors.shadowWarm,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
            child: Row(
              children: List.generate(destinations.length, (i) {
                final d = destinations[i];
                final isSelected = i == selectedIndex;
                final showBadge = i == 3 && unseenTreasuresCount > 0;

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: d.labelAr,
                    child: InkWell(
                      onTap: () => onSelected(i),
                      borderRadius: BorderRadius.circular(18),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: AnimatedContainer(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 6.h,
                          ),
                          decoration: ShapeDecoration(
                            color: isSelected
                                ? d.accent.withValues(alpha: 0.14)
                                : Colors.transparent,
                            shape: YasserShapes.squircle(18),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    isSelected ? d.activeIcon : d.icon,
                                    color: isSelected
                                        ? d.accent
                                        : AppColors.textMuted,
                                    size: isSelected ? 24 : 22,
                                  ),
                                  if (showBadge)
                                    Positioned(
                                      top: -3,
                                      right: -6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: AppColors.accentCoral,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$unseenTreasuresCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                d.labelAr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: isSelected
                                      ? d.accent
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 11.sp,
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
            ),
          ),
        ),
      ),
    );
  }
}
