import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../../data/world_catalog.dart';
import '../cubits/child_world_cubit.dart';

/// Privacy-conscious, optional, playful personalization & multi-profile screen.
/// Collects ONLY an optional display nickname & visual theme preferences (zero PII/photos).
class ProfileSetupView extends StatefulWidget {
  const ProfileSetupView({super.key});

  @override
  State<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<ProfileSetupView> {
  late TextEditingController _nameController;
  late String _selectedAvatarId;
  late String _selectedThemeId;
  late String _selectedAnimalId;
  late List<String> _selectedInterests;
  bool _creatingNewProfile = false;

  static const List<String> _interestOptions = [
    'الحيوانات',
    'الكورة',
    'الحكايات',
    'الطيارات',
    'الزهور',
    'الرسم',
  ];

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ChildWorldCubit>();
    final p = cubit.state.activeProfile;
    _nameController = TextEditingController(text: p.displayName);
    _selectedAvatarId = p.avatarId;
    _selectedThemeId = p.themeId;
    _selectedAnimalId = p.favoriteAnimalId;
    _selectedInterests = List<String>.from(p.interests);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncFromProfile() {
    final p = context.read<ChildWorldCubit>().state.activeProfile;
    setState(() {
      _creatingNewProfile = false;
      _nameController.text = p.displayName;
      _selectedAvatarId = p.avatarId;
      _selectedThemeId = p.themeId;
      _selectedAnimalId = p.favoriteAnimalId;
      _selectedInterests = List<String>.from(p.interests);
    });
  }

  Future<void> _save() async {
    final cubit = context.read<ChildWorldCubit>();
    if (_creatingNewProfile) {
      await cubit.createAndSwitchProfile(
        displayName: _nameController.text,
        avatarId: _selectedAvatarId,
        themeId: _selectedThemeId,
        favoriteAnimalId: _selectedAnimalId,
        interests: _selectedInterests,
      );
    } else {
      await cubit.updateActiveProfile(
        displayName: _nameController.text,
        avatarId: _selectedAvatarId,
        themeId: _selectedThemeId,
        favoriteAnimalId: _selectedAnimalId,
        interests: _selectedInterests,
      );
    }
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      sl<YasserAudioCoordinator>().playSfx(YasserSfx.starReward);
    }
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final animals = WorldCatalog.collectibles
        .where((c) => c.kind.name == 'animal')
        .toList();

    return Scaffold(
      body: PhonologicalBackground(
        variant: PhonologicalSceneVariant.playfulHills,
        child: SafeArea(
          child: BlocBuilder<ChildWorldCubit, ChildWorldCubitState>(
            builder: (context, worldState) {
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
                    child: Row(
                      children: [
                        YasserIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'رجوع',
                          onPressed: () => context.pop(),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'بطاقة البطل وعالمه',
                                style: AppTextStyles.headlineMedium,
                              ),
                              Text(
                                'تخصيص اختياري وآمن بدون أي بيانات شخصية حساسة',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 24.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Profile Switcher / Multi-child isolation
                          YasserSurfaceCard(
                            padding: EdgeInsets.all(14.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'ملفات الأبطال (${worldState.profiles.length})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.titleMedium,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _creatingNewProfile = true;
                                          _nameController.text = '';
                                        });
                                      },
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('بطل جديد'),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Wrap(
                                  spacing: 8.w,
                                  runSpacing: 8.h,
                                  children: worldState.profiles.map((p) {
                                    final isSelected =
                                        !_creatingNewProfile &&
                                        p.id == worldState.activeProfileId;
                                    return ChoiceChip(
                                      label: Text(p.displayName),
                                      selected: isSelected,
                                      selectedColor: AppColors.primaryContainer,
                                      onSelected: (_) async {
                                        await context
                                            .read<ChildWorldCubit>()
                                            .switchProfile(p.id);
                                        _syncFromProfile();
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // Yasser Greeting Preview + Nickname
                          YasserSurfaceCard(
                            padding: EdgeInsets.all(16.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const YasserCharacter(
                                      state: YasserAnimationState.happy,
                                      width: 78,
                                      height: 108,
                                      showShadow: false,
                                      enableTapReaction: false,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        _creatingNewProfile
                                            ? 'أهلاً بصاحب جديد! تحب ياسر يناديلك بإيه؟'
                                            : 'تقدر تغيّر اسمك اللطيف وألوان بيتك في أي وقت!',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                YasserTextField(
                                  controller: _nameController,
                                  variant: YasserFieldVariant.name,
                                  label: 'الاسم المستعار (اختياري)',
                                  hint: 'مثال: بطل النجوم أو يحيى',
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // Avatar Picker
                          Text(
                            'اختار صورتك الكرتونية',
                            style: AppTextStyles.titleMedium,
                          ),
                          SizedBox(height: 8.h),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            crossAxisSpacing: 10.w,
                            mainAxisSpacing: 10.h,
                            childAspectRatio: 0.92,
                            children: WorldCatalog.avatars.map((av) {
                              final selected = _selectedAvatarId == av.id;
                              return InkWell(
                                onTap: () =>
                                    setState(() => _selectedAvatarId = av.id),
                                borderRadius: BorderRadius.circular(18),
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: selected
                                        ? AppColors.primaryContainer
                                        : AppColors.surface,
                                    shape: YasserShapes.squircle(
                                      18,
                                      side: BorderSide(
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.borderSoft,
                                        width: selected ? 2.2 : 1.3,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IllustratedVocabularyWidget(
                                        objectKey: av.illustrationKey,
                                        semanticLabel: av.labelAr,
                                        size: 48,
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        av.labelAr,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 16.h),

                          // World Theme Colors
                          Text(
                            'لون وسماء بيتك',
                            style: AppTextStyles.titleMedium,
                          ),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 10.w,
                            runSpacing: 10.h,
                            children: WorldCatalog.themes.map((t) {
                              final selected = _selectedThemeId == t.id;
                              return InkWell(
                                onTap: () =>
                                    setState(() => _selectedThemeId = t.id),
                                borderRadius: BorderRadius.circular(16),
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: t.sky,
                                    shape: YasserShapes.squircle(
                                      16,
                                      side: BorderSide(
                                        color: selected
                                            ? t.accent
                                            : AppColors.borderSoft,
                                        width: selected ? 2.4 : 1.2,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 10.h,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: t.accent,
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          t.labelAr,
                                          style: AppTextStyles.labelLarge
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 16.h),

                          // Favorite Animal Companion
                          Text(
                            'صديقك الحيوان في الحديقة',
                            style: AppTextStyles.titleMedium,
                          ),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 10.w,
                            runSpacing: 10.h,
                            children: animals.map((an) {
                              final selected = _selectedAnimalId == an.id;
                              return FilterChip(
                                selected: selected,
                                label: Text(an.titleAr),
                                avatar: IllustratedVocabularyWidget(
                                  objectKey: an.illustrationKey,
                                  size: 22,
                                ),
                                selectedColor: AppColors.primaryContainer,
                                onSelected: (_) =>
                                    setState(() => _selectedAnimalId = an.id),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 16.h),

                          // Interests
                          Text(
                            'الحاجات اللي بتحبها',
                            style: AppTextStyles.titleMedium,
                          ),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: _interestOptions.map((item) {
                              final selected = _selectedInterests.contains(
                                item,
                              );
                              return FilterChip(
                                label: Text(item),
                                selected: selected,
                                selectedColor: AppColors.secondaryContainer,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedInterests.add(item);
                                    } else if (_selectedInterests.length > 1) {
                                      _selectedInterests.remove(item);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 22.h),

                          PrimaryButton(
                            label: _creatingNewProfile
                                ? 'إنشاء وبدء المغامرة'
                                : 'حفظ التغييرات',
                            icon: const Icon(Icons.check_circle_rounded),
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
