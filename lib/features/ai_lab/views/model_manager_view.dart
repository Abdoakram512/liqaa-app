import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class ModelManagerView extends StatelessWidget {
  const ModelManagerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('1. إدارة النماذج (Model Manager)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // Memory Overview Card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'استهلاك ذاكرة الوصول العشوائي (RAM)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${state.totalRamUsageMb} MB / 250 MB (الحد الآمن)',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: state.totalRamUsageMb > 180 ? Colors.red : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.pie_chart_rounded, color: AppColors.primary, size: 36),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              Text(
                'النماذج المثبتة محلياً (${state.models.length})',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 10.h),

              // Model items
              ...state.models.map((model) {
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.only(bottom: 12.h),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              model.name,
                              style: AppTextStyles.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: model.status == 'ready'
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                model.status.toUpperCase(),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: model.status == 'ready' ? Colors.green.shade800 : Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          model.description,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 12.w,
                          children: [
                            _buildInfoPill('الصيغة: ${model.format}'),
                            _buildInfoPill('الحجم: ${model.sizeMb} MB'),
                            _buildInfoPill('التردد: ${model.sampleRate} Hz'),
                            _buildInfoPill('الترخيص: ${model.license}'),
                            _buildInfoPill('في الذاكرة: ${model.isLoadedInMemory ? "نعم" : "لا"}'),
                          ],
                        ),
                        if (model.error != null && model.error!.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              'خطأ التهيئة: ${model.error}',
                              style: TextStyle(fontSize: 11.sp, color: Colors.red.shade900),
                            ),
                          ),
                        ],
                        SizedBox(height: 12.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: model.isLoadedInMemory ? Colors.red.shade50 : AppColors.primaryLight,
                                foregroundColor: model.isLoadedInMemory ? Colors.red.shade800 : AppColors.primaryDark,
                                elevation: 0,
                                minimumSize: Size(0, 36.h),
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              ),
                              icon: Icon(
                                model.isLoadedInMemory ? Icons.eject_rounded : Icons.play_arrow_rounded,
                                size: 16,
                              ),
                              label: Text(model.isLoadedInMemory ? 'تفريغ من RAM' : 'تحميل إلى RAM'),
                              onPressed: () => context.read<AiLabCubit>().toggleModelMemory(model.key),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(0, 36.h),
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              ),
                              icon: const Icon(Icons.verified_rounded, size: 16),
                              label: const Text('فحص Smoke Test'),
                              onPressed: () async {
                                final passed = await context.read<AiLabCubit>().smokeTestModel(model.key);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        passed
                                            ? 'اجتاز ${model.name} اختبار الاستدلال الحقيقي بنجاح!'
                                            : 'فشل ${model.name} في اختبار Smoke Test!',
                                      ),
                                      backgroundColor: passed ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoPill(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: AppColors.backgroundCream,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.sp, color: AppColors.textPrimary),
      ),
    );
  }
}
