import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class AiLabHubView extends StatefulWidget {
  const AiLabHubView({super.key});

  @override
  State<AiLabHubView> createState() => _AiLabHubViewState();
}

class _AiLabHubViewState extends State<AiLabHubView> {
  @override
  void initState() {
    super.initState();
    context.read<AiLabCubit>().initializeLab();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(
          'مختبر ياسر للذكاء الاصطناعي (AI Lab)',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
            tooltip: 'تصدير تقرير التشخيص',
            onPressed: () => context.read<AiLabCubit>().exportDiagnosticReport(),
          ),
        ],
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          if (state.status == AiLabStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Summary Header
                _buildSystemStatusCard(state),

                SizedBox(height: 16.h),

                // Primary Shortcut to Game
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowWarm,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 36),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'انطق مع ياسر (لعبة النطق)',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'تجربة الطفل التفاعلية مع تصحيح النطق الصوتي',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => context.push(AppRoutes.game),
                        child: const Text('ابدأ اللعبة'),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                Text(
                  'شاشات الاختبار والتشخيص (7 Developer Screens)',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                SizedBox(height: 12.h),

                // 7 Feature Test Cards
                _buildTestCard(
                  title: '1. إدارة النماذج (Model Manager)',
                  subtitle: 'حالة النماذج، التحميل للذاكرة، التحقق من التجزئة (SHA256)',
                  icon: Icons.memory_rounded,
                  color: Colors.blueAccent,
                  onTap: () => context.push(AppRoutes.aiLabModels),
                ),
                _buildTestCard(
                  title: '2. الميكروفون ومحدد الصوت (Mic & Silero VAD)',
                  subtitle: 'موجة الصوت الحية، كشف بداية ونهاية الكلام، واقتطاع الصمت',
                  icon: Icons.graphic_eq_rounded,
                  color: Colors.teal,
                  onTap: () => context.push(AppRoutes.aiLabVad),
                ),
                _buildTestCard(
                  title: '3. عزل الضوضاء (RNNoise Suppression)',
                  subtitle: 'مقارنة الصوت الخام بالمعالج، قياس نسبة الإشارة للضوضاء SNR',
                  icon: Icons.multitrack_audio_rounded,
                  color: Colors.deepPurpleAccent,
                  onTap: () => context.push(AppRoutes.aiLabNoise),
                ),
                _buildTestCard(
                  title: '4. التعرف على الفونيمات (Phoneme Recognition)',
                  subtitle: 'Zipformer CTC، تسلسل الأصوات، نسب الثقة، ومحاذاة الأخطاء',
                  icon: Icons.record_voice_over_rounded,
                  color: Colors.orangeAccent,
                  onTap: () => context.push(AppRoutes.aiLabPhonemes),
                ),
                _buildTestCard(
                  title: '5. تحويل الكلام لنص (Speech-to-Text)',
                  subtitle: 'التعرف على مستوى الجمل والكلمات، قياس معدل الوقت الحقيقي RTF',
                  icon: Icons.text_fields_rounded,
                  color: Colors.indigoAccent,
                  onTap: () => context.push(AppRoutes.aiLabStt),
                ),
                _buildTestCard(
                  title: '6. مقارنة النماذج (Model Comparison)',
                  subtitle: 'مقارنة Zipformer V2 مقابل V3 و Nabra عبر معايير اللهجة والدقة',
                  icon: Icons.compare_arrows_rounded,
                  color: Colors.pinkAccent,
                  onTap: () => context.push(AppRoutes.aiLabCompare),
                ),
                _buildTestCard(
                  title: '7. خط الأنابيب المتكامل (Full Pipeline & Export)',
                  subtitle: 'تشغيل المسار كاملاً من الميكروفون للتقييم مع تصدير JSON/CSV',
                  icon: Icons.account_tree_rounded,
                  color: Colors.green,
                  onTap: () => context.push(AppRoutes.aiLabPipeline),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSystemStatusCard(AiLabState state) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowWarm,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'حالة محرك الذكاء الاصطناعي (On-Device)',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                    SizedBox(width: 4.w),
                    Text(
                      'أوفلاين 100%',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildMetricChip(
                label: 'النماذج المسجلة',
                value: '${state.models.length}',
                icon: Icons.widgets_rounded,
              ),
              SizedBox(width: 12.w),
              _buildMetricChip(
                label: 'استهلاك RAM',
                value: '${state.totalRamUsageMb} MB',
                icon: Icons.pie_chart_rounded,
              ),
              SizedBox(width: 12.w),
              _buildMetricChip(
                label: 'كلمات القاموس',
                value: '${state.vocabulary.length}',
                icon: Icons.menu_book_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: AppColors.backgroundCream,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            SizedBox(height: 4.h),
            Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 10.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
