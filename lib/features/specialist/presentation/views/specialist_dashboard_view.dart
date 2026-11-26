import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_audio_settings_sheet.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../../../authentication/data/models/user_model.dart';
import '../../../authentication/data/repos/auth_repo.dart';
import '../../data/models/specialist_models.dart';
import '../cubits/specialist_cubit.dart';
import '../cubits/specialist_state.dart';
import '../widgets/case_form_sheet.dart';

/// Calm, professional, structured Specialist Workspace for managing speech
/// training cases, launching guided pronunciation sessions, and reviewing
/// honest per-case attempt histories.
class SpecialistDashboardView extends StatefulWidget {
  const SpecialistDashboardView({super.key});

  @override
  State<SpecialistDashboardView> createState() =>
      _SpecialistDashboardViewState();
}

class _SpecialistDashboardViewState extends State<SpecialistDashboardView> {
  final TextEditingController _searchController = TextEditingController();
  UserModel? _specialistUser;

  @override
  void initState() {
    super.initState();
    context.read<SpecialistCubit>().loadWorkspace();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (!sl.isRegistered<AuthRepo>()) return;
    final user = await sl<AuthRepo>().getCurrentUser();
    if (mounted) {
      setState(() => _specialistUser = user);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateCase() async {
    final result = await showCaseFormSheet(context);
    if (result == null || !mounted) return;
    final created = await context.read<SpecialistCubit>().createCase(
      childName: result.childName,
      ageYears: result.ageYears,
      guardianPhone: result.guardianPhone,
      targetPhonemes: result.targetPhonemes,
      clinicalNotes: result.clinicalNotes,
      status: result.status,
    );
    if (mounted) {
      showYasserSnackBar(
        context,
        message: 'تم إنشاء ملف الحالة "${created.childName}" بنجاح',
      );
    }
  }

  Future<void> _handleLogout() async {
    if (sl.isRegistered<AuthRepo>()) {
      await sl<AuthRepo>().logout();
    }
    if (mounted) {
      context.go(AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonologicalBackground(
        variant: PhonologicalSceneVariant.calmClinical,
        child: SafeArea(
          child: BlocBuilder<SpecialistCubit, SpecialistState>(
            builder: (context, state) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 32.h),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildTopBar(context),
                        SizedBox(height: 16.h),
                        _buildClinicalNoticeBanner(),
                        SizedBox(height: 16.h),
                        _buildKpiRow(state),
                        SizedBox(height: 18.h),

                        // Quick Actions Row
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                label: 'إضافة حالة جديدة',
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                ),
                                onPressed: _handleCreateCase,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: YasserOutlineButton(
                                label: 'استوديو حر',
                                height: AppSpacing.buttonHeight.h.clamp(
                                  52.0,
                                  62.0,
                                ),
                                icon: const Icon(
                                  Icons.mic_rounded,
                                  color: AppColors.primaryDark,
                                ),
                                onPressed: () => context.push(AppRoutes.game),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),

                        // Search & Filter Controls
                        YasserTextField(
                          controller: _searchController,
                          variant: YasserFieldVariant.search,
                          hint:
                              'ابحث باسم الطفل أو الصوت المستهدف (ر، س، ك)...',
                          onChanged: context
                              .read<SpecialistCubit>()
                              .setSearchQuery,
                        ),
                        SizedBox(height: 10.h),
                        _buildStatusFilterChips(context, state),
                        SizedBox(height: 16.h),

                        if (state.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.allCases.isEmpty)
                          YasserEmptyState(
                            icon: Icons.folder_shared_rounded,
                            title: 'ابدأ بإضافة أول حالة تدريبية',
                            subtitle:
                                'أنشئ ملفات للأطفال لتنظيم الجلسات الصوتية ومتابعة سجل المحاولات الفعلي والملاحظات الإكلينيكية في مكان واحد.',
                            action: PrimaryButton(
                              label: 'إنشاء أول ملف حالة',
                              icon: const Icon(Icons.add_rounded),
                              onPressed: _handleCreateCase,
                            ),
                          )
                        else if (state.filteredCases.isEmpty)
                          YasserEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'لا توجد نتائج مطابقة للبحث',
                            subtitle:
                                'جرّب تغيير كلمة البحث أو عرض جميع حالات المتابعة.',
                            action: YasserOutlineButton(
                              label: 'إعادة ضبط الفلتر',
                              onPressed: () {
                                _searchController.clear();
                                final cubit = context.read<SpecialistCubit>();
                                cubit.setSearchQuery('');
                                cubit.setStatusFilter(null);
                              },
                            ),
                          )
                        else
                          ...state.filteredCases.map(
                            (item) => Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _CaseSummaryCard(
                                item: item,
                                summary: state.summaryForCase(item.id),
                                onTap: () => context.push(
                                  AppRoutes.specialistCasePath(item.id),
                                ),
                              ),
                            ),
                          ),
                      ]),
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

  Widget _buildTopBar(BuildContext context) {
    final name = (_specialistUser?.name.trim().isNotEmpty ?? false)
        ? _specialistUser!.name.trim()
        : 'أخصائي التخاطب';
    final org = _specialistUser?.organization;

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: ShapeDecoration(
            color: AppColors.secondarySoft,
            shape: YasserShapes.squircle(
              16,
              side: BorderSide(
                color: AppColors.secondary.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: const Icon(
            Icons.medical_services_rounded,
            color: AppColors.secondaryDark,
            size: 25,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                org != null && org.isNotEmpty
                    ? 'مساحة الأخصائي • $org'
                    : 'مساحة أخصائي التخاطب',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'مرحباً، $name',
                style: AppTextStyles.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        YasserIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'الإعدادات وتسجيل الخروج',
          onPressed: () {
            if (!sl.isRegistered<YasserAudioCoordinator>()) return;
            showYasserAudioSettingsSheet(
              context,
              coordinator: sl<YasserAudioCoordinator>(),
              onLogout: _handleLogout,
            );
          },
        ),
      ],
    );
  }

  Widget _buildClinicalNoticeBanner() {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: YasserShapes.squircle(
          16,
          side: const BorderSide(color: AppColors.borderSoft, width: 1.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: AppColors.teal,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'تُحفظ ملفات الحالات والجلسات محلياً على هذا الجهاز. المؤشرات الصوتية الآلية هي أدوات تدريب مساعدة ولا تُعد تشخيصاً طبياً.',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(SpecialistState state) {
    return Row(
      children: [
        Expanded(
          child: _SpecialistKpiCard(
            label: 'إجمالي الحالات',
            value: '${state.allCases.length}',
            icon: Icons.groups_rounded,
            accent: AppColors.secondary,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _SpecialistKpiCard(
            label: 'الجلسات المنفذة',
            value: '${state.allSessions.length}',
            icon: Icons.event_available_rounded,
            accent: AppColors.primary,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _SpecialistKpiCard(
            label: 'المحاولات المسجلة',
            value: '${state.allAttempts.length}',
            icon: Icons.graphic_eq_rounded,
            accent: AppColors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChips(BuildContext context, SpecialistState state) {
    final cubit = context.read<SpecialistCubit>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('الكل'),
            selected: state.statusFilter == null,
            selectedColor: AppColors.primarySoft,
            onSelected: (_) => cubit.setStatusFilter(null),
          ),
          for (final st in CaseStatus.values) ...[
            SizedBox(width: 8.w),
            ChoiceChip(
              label: Text(st.arabicLabel),
              selected: state.statusFilter == st,
              selectedColor: AppColors.primarySoft,
              onSelected: (_) => cubit.setStatusFilter(st),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpecialistKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _SpecialistKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return YasserSurfaceCard(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      radius: AppSpacing.radiusM,
      lipDepth: 3.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: ShapeDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: YasserShapes.squircle(10),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CaseSummaryCard extends StatelessWidget {
  final SpecialistCase item;
  final CaseProgressSummary summary;
  final VoidCallback onTap;

  const _CaseSummaryCard({
    required this.item,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (Color statusBg, Color statusFg) = switch (item.status) {
      CaseStatus.active => (AppColors.successSoft, AppColors.successDark),
      CaseStatus.followUp => (AppColors.primarySoft, AppColors.primaryDeep),
      CaseStatus.completed => (
        AppColors.secondarySoft,
        AppColors.secondaryDark,
      ),
      CaseStatus.archived => (
        AppColors.surfaceVariant,
        AppColors.textSecondary,
      ),
    };

    return YasserSurfaceCard(
      onTap: onTap,
      padding: EdgeInsets.all(16.w),
      radius: AppSpacing.radiusL,
      lipDepth: 3.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: AppColors.primarySoft,
                  shape: YasserShapes.squircle(14),
                ),
                child: Center(
                  child: Text(
                    item.childName.characters.first,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.childName, style: AppTextStyles.titleMedium),
                    Text(
                      'العمر: ${item.ageYears} سنوات • ${summary.totalSessions} جلسات • ${summary.totalAttempts} محاولات',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: statusBg,
                  shape: YasserShapes.squircle(10),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  child: Text(
                    item.status.arabicLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: statusFg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (item.targetPhonemes.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                Text(
                  'الأصوات المستهدفة:',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final ph in item.targetPhonemes)
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: AppColors.secondarySoft,
                      shape: YasserShapes.squircle(8),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      child: Text(
                        ph,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.secondaryDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (summary.averageScoreIndicator != null) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  size: 16,
                  color: AppColors.teal,
                ),
                SizedBox(width: 6.w),
                Flexible(
                  child: Text(
                    'متوسط مؤشر التدريب المسجل: ${summary.averageScoreIndicator!.round()}%',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
