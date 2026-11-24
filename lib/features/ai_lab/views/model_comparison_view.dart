import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class ModelComparisonView extends StatelessWidget {
  const ModelComparisonView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('6. مقارنة النماذج (Model Comparison)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // Summary Comparison Banner
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مصفوفة المقارنة المرجعية (Acoustic Benchmarks)',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'مقارنة الأداء على لهجة الأطفال المصرية وفقاً لبيانات ASMDD السريرية',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Benchmark Comparison Table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.white),
                  dataRowColor: WidgetStateProperty.all(Colors.white),
                  border: TableBorder.all(color: AppColors.borderSoft, borderRadius: BorderRadius.circular(8)),
                  columns: const [
                    DataColumn(label: Text('المعيار', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Zipformer V2', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                    DataColumn(label: Text('Zipformer V3', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                    DataColumn(label: Text('Nabra 82M', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
                    DataColumn(label: Text('Moonshine', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                  ],
                  rows: const [
                    DataRow(cells: [
                      DataCell(Text('نوع الخرج')),
                      DataCell(Text('250 فونيم')),
                      DataCell(Text('251 رمز صوتي')),
                      DataCell(Text('كلمات / Subword')),
                      DataCell(Text('كلمات BPE')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('الحجم (Disk)')),
                      DataCell(Text('65.0 MB')),
                      DataCell(Text('65.5 MB')),
                      DataCell(Text('79.3 MB')),
                      DataCell(Text('17.4 MB')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('استهلاك RAM')),
                      DataCell(Text('108 MB')),
                      DataCell(Text('114 MB')),
                      DataCell(Text('135 MB')),
                      DataCell(Text('45 MB')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('نسبة الخطأ (PER) أطفال')),
                      DataCell(Text('16.8% (الأفضل)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(Text('19.2%')),
                      DataCell(Text('غير متوفر')),
                      DataCell(Text('غير متوفر')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('دقة كشف الإبدال (Fronting)')),
                      DataCell(Text('94.2%', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(Text('89.6%')),
                      DataCell(Text('52.0% (Word)')),
                      DataCell(Text('غير مدعوم')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('معدل السرعة (RTF)')),
                      DataCell(Text('0.08x (12x أسرع)')),
                      DataCell(Text('0.09x (11x أسرع)')),
                      DataCell(Text('0.12x (8x أسرع)')),
                      DataCell(Text('0.06x (16x أسرع)')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('الترخيص')),
                      DataCell(Text('أكاديمي غير تجاري')),
                      DataCell(Text('NPL-1.3 غير ربحي')),
                      DataCell(Text('Apache-2.0')),
                      DataCell(Text('MIT')),
                    ]),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Analytical Conclusion Card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'خلاصة المقارنة الفنية والسريرية:',
                      style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '1. Zipformer Arabic V2 يتفوق في دقة التعرف على كلام الأطفال باللهجة المصرية (16.8% PER) مقارنة بـ V3 (19.2% PER)، نظراً لاشتماله على تسجيلات عامية غير مقتصرة على التلاوة القرآنية.\n\n'
                      '2. نماذج الكلمات الكاملة (Nabra 82M و Moonshine) ممتازة للنصوص العامة لكنها لا تصلح لتشخيص عيوب النطق، لأنها تتجاهل الخطأ الفونيمي الفردي أو تصححه آلياً (Auto-correction).\n\n'
                      '3. النموذج المعتمد في LIQAA هو Zipformer Streaming CTC بذاكرة 65 MB وحجم استهلاك رام آمن لا يتجاوز 120 MB.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
