import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../../data/models/specialist_models.dart';
import '../cubits/specialist_cubit.dart';
import '../cubits/specialist_state.dart';
import '../widgets/case_form_sheet.dart';
import '../widgets/case_progress_chart.dart';

/// Individual Child Case Profile screen displaying real progress trajectories,
/// guided training session launcher, full attempt history, and specialist notes.
class CaseDetailView extends StatefulWidget {
  final String caseId;

  const CaseDetailView({super.key, required this.caseId});

  @override
  State<CaseDetailView> createState() => _CaseDetailViewState();
}

class _CaseDetailViewState extends State<CaseDetailView> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SpecialistCubit>();
    if (cubit.state.allCases.isEmpty) {
      cubit.loadWorkspace();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleStartGuidedSession(SpecialistCase item) async {
    final session = await context.read<SpecialistCubit>().startGuidedSession(
      caseId: item.id,
      targetPhonemes: item.targetPhonemes,
    );
    if (!mounted) return;
    final uri = Uri(
      path: AppRoutes.game,
      queryParameters: {
        'caseId': item.id,
        'sessionId': session.id,
        'caseName': item.childName,
        if (item.targetPhonemes.isNotEmpty)
          'phonemes': item.targetPhonemes.join(','),
      },
    );
    await context.push(uri.toString());
    if (mounted) {
      await context.read<SpecialistCubit>().loadWorkspace();
    }
  }

  Future<void> _handleEditCase(SpecialistCase item) async {
    final result = await showCaseFormSheet(context, existingCase: item);
    if (result == null || !mounted) return;
    await context.read<SpecialistCubit>().updateCase(
      item.copyWith(
        childName: result.childName,
        ageYears: result.ageYears,
        guardianPhone: result.guardianPhone,
        targetPhonemes: result.targetPhonemes,
        status: result.status,
      ),
    );
    if (mounted) {
      showYasserSnackBar(context, message: 'تم تحديث بيانات الحالة بنجاح');
    }
  }

  Future<void> _handleDeleteCase(SpecialistCase item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف ملف الحالة؟'),
        content: Text(
          'سيتم حذف ملف "${item.childName}" وجميع الجلسات والمحاولات المرتبطة به نهائياً من هذا الجهاز.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'حذف نهائي',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SpecialistCubit>().deleteCase(item.id);
    if (mounted) {
      context.go(AppRoutes.specialistDashboard);
    }
  }

  Future<void> _handleAddNote(String caseId) async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    await context.read<SpecialistCubit>().addCaseNote(
      caseId: caseId,
      content: text,
    );
    _noteController.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      showYasserSnackBar(context, message: 'تم حفظ ملاحظة الأخصائي');
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d • $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonologicalBackground(
        variant: PhonologicalSceneVariant.calmClinical,
        child: SafeArea(
          child: BlocBuilder<SpecialistCubit, SpecialistState>(
            builder: (context, state) {
              final item = state.caseById(widget.caseId);
              if (state.isLoading && item == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (item == null) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: YasserEmptyState(
                      icon: Icons.person_off_rounded,
                      title: 'ملف الحالة غير موجود',
                      subtitle: 'ربما تم حذف هذا الملف أو لم يعد متوفراً.',
                      action: PrimaryButton(
                        label: 'العودة للوحة الأخصائي',
                        onPressed: () =>
                            context.go(AppRoutes.specialistDashboard),
                      ),
                    ),
                  ),
                );
              }

              final summary = state.summaryForCase(item.id);
              final attempts = state.attemptsForCase(item.id);
              final notes = state.notesForCase(item.id);

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeaderBar(context, item),
                        SizedBox(height: 14.h),
                        _buildProfileCard(item, summary),
                        SizedBox(height: 14.h),

                        // Guided Session CTA
                        YasserGameActionButton(
                          label: 'بدء جلسة تدريب نطق موجهة',
                          subtitle: item.targetPhonemes.isNotEmpty
                              ? 'تركيز على الأصوات: ${item.targetPhonemes.join(" ، ")}'
                              : 'جميع بطاقات التدريب الصوتي',
                          icon: Icons.mic_external_on_rounded,
                          onPressed: () => _handleStartGuidedSession(item),
                        ),

                        SizedBox(height: 20.h),

                        // Real Progress Chart
                        CaseProgressChart(
                          scoredAttempts: summary.scoredTrajectory,
                        ),

                        SizedBox(height: 20.h),

                        // Specialist Clinical Observations Section
                        Text(
                          'الملاحظات الإكلينيكية للأخصائي',
                          style: AppTextStyles.headlineSmall,
                        ),
                        SizedBox(height: 8.h),
                        YasserSurfaceCard(
                          padding: EdgeInsets.all(14.w),
                          radius: AppSpacing.radiusL,
                          lipDepth: 3.0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              YasserTextField(
                                controller: _noteController,
                                variant: YasserFieldVariant.multilineNotes,
                                hint:
                                    'أضف ملاحظة جلسة أو توصية منزلية لولي الأمر...',
                              ),
                              SizedBox(height: 10.h),
                              PrimaryButton(
                                label: 'إضافة ملاحظة للسجل',
                                height: 48,
                                icon: const Icon(Icons.note_add_rounded),
                                onPressed: () => _handleAddNote(item.id),
                              ),
                              if (notes.isNotEmpty) ...[
                                SizedBox(height: 14.h),
                                const Divider(color: AppColors.borderSoft),
                                for (final n in notes)
                                  Padding(
                                    padding: EdgeInsets.only(top: 10.h),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDate(n.createdAt),
                                          textDirection: TextDirection.ltr,
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                                color: AppColors.secondaryDark,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          n.content,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // Chronological Attempt History
                        Text(
                          'سجل المحاولات الصوتية المسجلة (${attempts.length})',
                          style: AppTextStyles.headlineSmall,
                        ),
                        SizedBox(height: 8.h),
                        if (attempts.isEmpty)
                          YasserSurfaceCard(
                            backgroundColor: AppColors.surfaceVariant,
                            padding: EdgeInsets.all(18.w),
                            radius: AppSpacing.radiusM,
                            lipDepth: 2.0,
                            child: Text(
                              'لم تُسجّل أي محاولات لهذه الحالة بعد. عند تشغيل جلسة تدريب نطق موجهة، ستُحفظ كل محاولة هنا تلقائياً.',
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...attempts.map(
                            (attempt) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _AttemptHistoryTile(
                                attempt: attempt,
                                formattedTime: _formatDate(attempt.timestamp),
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

  Widget _buildHeaderBar(BuildContext context, SpecialistCase item) {
    return Row(
      children: [
        YasserIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'رجوع',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.specialistDashboard);
            }
          },
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            'ملف الحالة التدريبي',
            style: AppTextStyles.headlineSmall,
          ),
        ),
        YasserIconButton(
          icon: Icons.edit_rounded,
          tooltip: 'تعديل البيانات',
          onPressed: () => _handleEditCase(item),
        ),
        SizedBox(width: 8.w),
        YasserIconButton(
          icon: Icons.delete_outline_rounded,
          iconColor: AppColors.error,
          tooltip: 'حذف الحالة',
          onPressed: () => _handleDeleteCase(item),
        ),
      ],
    );
  }

  Widget _buildProfileCard(SpecialistCase item, CaseProgressSummary summary) {
    return YasserSurfaceCard(
      padding: EdgeInsets.all(18.w),
      radius: AppSpacing.radiusXL,
      lipDepth: 4.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: ShapeDecoration(
                  color: AppColors.secondarySoft,
                  shape: YasserShapes.squircle(18),
                ),
                child: Center(
                  child: Text(
                    item.childName.characters.first,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.childName, style: AppTextStyles.headlineMedium),
                    Text(
                      'العمر: ${item.ageYears} سنوات • الحالة: ${item.status.arabicLabel}',
                      style: AppTextStyles.bodySmall,
                    ),
                    if (item.guardianPhone != null)
                      Text(
                        'تواصل ولي الأمر: ${item.guardianPhone}',
                        style: AppTextStyles.labelSmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (item.targetPhonemes.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                for (final ph in item.targetPhonemes)
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: AppColors.primarySoft,
                      shape: YasserShapes.squircle(10),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      child: Text(
                        'حرف ($ph)',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: 14.h),
          const Divider(color: AppColors.borderSoft),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'الجلسات',
                  value: '${summary.totalSessions}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'المحاولات',
                  value: '${summary.totalAttempts}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'مطابقة',
                  value: '${summary.passedAttemptsCount}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'المتوسط',
                  value: summary.averageScoreIndicator != null
                      ? '${summary.averageScoreIndicator!.round()}%'
                      : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

class _AttemptHistoryTile extends StatelessWidget {
  final PronunciationAttemptRecord attempt;
  final String formattedTime;

  const _AttemptHistoryTile({
    required this.attempt,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = attempt.passed
        ? AppColors.successDark
        : attempt.scoreIndicator == null
        ? AppColors.info
        : AppColors.primaryDeep;
    final Color bg = attempt.passed
        ? AppColors.successSoft
        : attempt.scoreIndicator == null
        ? AppColors.infoSoft
        : AppColors.accentGoldSoft;

    return YasserSurfaceCard(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      radius: AppSpacing.radiusM,
      lipDepth: 2.5,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: ShapeDecoration(
              color: bg,
              shape: YasserShapes.squircle(12),
            ),
            child: Center(
              child: Text(
                attempt.targetPhoneme,
                style: AppTextStyles.titleMedium.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كلمة "${attempt.wordArabic}" • ${attempt.arabicOutcomeLabel}',
                  style: AppTextStyles.titleSmall,
                ),
                Text(
                  formattedTime,
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),
          Text(
            attempt.scoreIndicator != null
                ? '${attempt.scoreIndicator!.round()}%'
                : 'غير مقاس',
            style: AppTextStyles.titleSmall.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
