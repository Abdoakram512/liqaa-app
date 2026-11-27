import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/ai/phase0_governance_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class Phase0GovernanceView extends StatefulWidget {
  final Phase0GovernanceService? service;

  const Phase0GovernanceView({super.key, this.service});

  @override
  State<Phase0GovernanceView> createState() => _Phase0GovernanceViewState();
}

class _Phase0GovernanceViewState extends State<Phase0GovernanceView> {
  late final Future<Phase0GovernanceSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = (widget.service ?? Phase0GovernanceService())
        .loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.backgroundCream,
        appBar: AppBar(
          title: const Text('12. حوكمة المرحلة 0 ومنع التسرب'),
          backgroundColor: Colors.white,
          elevation: 1,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'النماذج والسجل'),
              Tab(text: 'البيانات والأعمى'),
              Tab(text: 'التسرب والاختبارات'),
            ],
          ),
        ),
        body: FutureBuilder<Phase0GovernanceSummary>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Text(
                    'تعذر تحميل حزمة حوكمة المرحلة 0: ${snapshot.error ?? 'بيانات غير متوفرة'}',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final data = snapshot.data!;
            return TabBarView(
              children: [
                _ModelsAndManifestTab(data: data),
                _DatasetsAndBlindTab(data: data),
                _LeakageAndChecksTab(data: data),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModelsAndManifestTab extends StatelessWidget {
  final Phase0GovernanceSummary data;

  const _ModelsAndManifestTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final recon = data.legacyManifestReconciliation;
    final int issueCount = recon['issue_count'] as int? ?? 0;
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _StatusBanner(
          title: 'تطابق AI_MODELS_MANIFEST والتراخيص',
          subtitle: issueCount == 0
              ? 'تمت مطابقة البصمات والملفات الفعلية بالكامل (0 تعارضات).'
              : 'مرصود $issueCount تعارض/ثغرة موثقة بين السجل والملفات.',
          color: issueCount == 0
              ? AppColors.accentMintDark
              : AppColors.primaryDark,
          icon: issueCount == 0
              ? Icons.verified_rounded
              : Icons.warning_amber_rounded,
        ),
        SizedBox(height: 12.h),
        ...data.modelsSummary.map((m) {
          final status = m['availability_status'] as String? ?? 'UNKNOWN';
          final bool localOk = status == 'LOCAL_BUNDLED_VERIFIED';
          final bool blindOk =
              m['supports_blind_phoneme_only'] as bool? ?? false;
          final size = m['artifact_size_mb'];
          return Card(
            color: Colors.white,
            margin: EdgeInsets.only(bottom: 10.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusM),
              side: const BorderSide(color: AppColors.borderSoft),
            ),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        localOk
                            ? Icons.check_circle_rounded
                            : Icons.cloud_off_rounded,
                        color: localOk
                            ? AppColors.accentMintDark
                            : Colors.blueGrey,
                        size: 20.r,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          m['display_name'] as String? ??
                              m['model_id'] as String,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: [
                      _ChipTag(text: status),
                      _ChipTag(text: 'License: ${m['license']}'),
                      if (size != null) _ChipTag(text: '$size MB'),
                      _ChipTag(
                        text: blindOk
                            ? 'Blind Phoneme'
                            : 'ASR / Gate / Unverified',
                      ),
                    ],
                  ),
                  if ((m['contamination_risk_notes'] as String? ?? '')
                      .isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Text(
                      m['contamination_risk_notes'] as String,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DatasetsAndBlindTab extends StatelessWidget {
  final Phase0GovernanceSummary data;

  const _DatasetsAndBlindTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final blind = data.blindTestStatus;
    final bool frozen = blind['stage_b_frozen'] as bool? ?? false;
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _StatusBanner(
          title: 'حماية الاختبار الأعمى (Stage B Blind Protection)',
          subtitle:
              'الحالة: ${frozen ? 'مقفل ومجمد' : 'غير مقفل بعد (بانتظار جمع Stage B)'} • تسميات Stage B مضمّنة بالتطبيق: ${data.blindLabelsIncluded ? 'خطأ تسرب!' : '0 (معزولة خارجياً)'} • اصطناعي مسموح في الأعمى: 0%',
          color: data.blindLabelsIncluded ? Colors.red : AppColors.accentSky,
          icon: Icons.lock_outline_rounded,
        ),
        SizedBox(height: 12.h),
        ...data.datasetsSummary.map((d) {
          final bool comm = d['commercial_use_allowed'] as bool? ?? false;
          return Card(
            color: Colors.white,
            margin: EdgeInsets.only(bottom: 10.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusM),
              side: const BorderSide(color: AppColors.borderSoft),
            ),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['display_name'] as String? ?? d['dataset_id'] as String,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: [
                      _ChipTag(
                        text: d['access_status'] as String? ?? 'UNKNOWN',
                      ),
                      _ChipTag(text: 'License: ${d['license']}'),
                      _ChipTag(
                        text: comm ? 'Commercial OK' : 'Restricted/Unknown',
                      ),
                      _ChipTag(
                        text:
                            'Local clips: ${d['local_phase0_sample_count'] ?? 0}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (data.contaminationHighlights.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Text(
            'مخاطر تداخل النماذج والبيانات المرصودة',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6.h),
          ...data.contaminationHighlights
              .take(8)
              .map(
                (c) => ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.report_problem_rounded,
                    color: Colors.deepOrange,
                  ),
                  title: Text('${c['model_id']} × ${c['dataset_id']}'),
                  subtitle: Text(
                    '${c['contamination_status']}: ${c['evidence_and_rule']}',
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _LeakageAndChecksTab extends StatelessWidget {
  final Phase0GovernanceSummary data;

  const _LeakageAndChecksTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final leak = data.leakageAuditSummary;
    final counts = Map<String, dynamic>.from(
      leak['counts'] as Map? ?? const {},
    );
    final anti = data.antiCheatingSummary;
    final tests = (anti['tests'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final drives = Map<String, dynamic>.from(
      (data.storageAudit['drives'] as Map?) ?? const {},
    );
    final cFree = (drives['C'] as Map?)?['free_gb'];
    final dFree = (drives['D'] as Map?)?['free_gb'];

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _StatusBanner(
          title: 'تخزين السحابة المحلية ومساحة الأقراص',
          subtitle:
              'C: $cFree GB متاح (حرج - محظور للكاش) | D:\\YasserML: $dFree GB متاح',
          color: Colors.amber.shade800,
          icon: Icons.storage_rounded,
        ),
        SizedBox(height: 10.h),
        _StatusBanner(
          title:
              'تدقيق التسرب على ${leak['manifest_records_scanned'] ?? 0} مقطع محلي',
          subtitle:
              'بصمة الملفات: ${leak['audio_files_hashed'] ?? 0} | قرابة صوتية: ${counts['acoustic_near_duplicates'] ?? 0} | سلسلة اشتقاق: ${counts['lineage_overlaps'] ?? 0} | تداخل متحدثين: ${counts['speaker_overlaps'] ?? 0}',
          color: Colors.indigo,
          icon: Icons.shield_rounded,
        ),
        SizedBox(height: 12.h),
        Text(
          'اختبارات النزاهة ومكافحة الغش (${anti['passed_count'] ?? 0}/${anti['total_tests'] ?? 0})',
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),
        ...tests.map((t) {
          final ok = t['passed'] as bool? ?? false;
          return Card(
            color: Colors.white,
            margin: EdgeInsets.only(bottom: 8.h),
            child: ListTile(
              leading: Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: ok ? AppColors.accentMintDark : Colors.red,
              ),
              title: Text('${t['test_id']}: ${t['title']}'),
              subtitle: Text(t['detail'] as String? ?? ''),
            ),
          );
        }),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _StatusBanner({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22.r),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipTag extends StatelessWidget {
  final String text;

  const _ChipTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.backgroundCream,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5.sp, color: AppColors.textPrimary),
      ),
    );
  }
}
