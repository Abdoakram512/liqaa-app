import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ModelComparisonView extends StatelessWidget {
  const ModelComparisonView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('6. مقارنة النماذج والهيكلية الفعلية'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(AppSpacing.radiusM),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مقارنة معمارية حقيقية للنماذج المثبتة في LIQAA',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'تعرض هذه الصفحة المواصفات والأدوار الحقيقية للنماذج المحملة فعلياً عبر ONNX Runtime و Sherpa-ONNX بدون أي أرقام تقديرية غير مقاسة.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.white),
              dataRowColor: WidgetStateProperty.all(Colors.white),
              border: TableBorder.all(
                color: AppColors.borderSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    'المعيار',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Wav2Vec2 eSpeak Q4F16',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Whisper Tiny INT8',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'GTCRN Simple',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Silero VAD v4',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
              rows: const [
                DataRow(
                  cells: [
                    DataCell(Text('الدور في النظام')),
                    DataCell(Text('تحليل الفونيمات الأعمى (IPA CTC)')),
                    DataCell(Text('تحويل كلام لنص (تشخيصي فقط)')),
                    DataCell(Text('عزل الضوضاء العصبي 16kHz')),
                    DataCell(Text('كشف الكلام واقتطاع الصمت')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('نوع الخرج')),
                    DataCell(Text('392 رمز IPA + احتمال فعلي')),
                    DataCell(Text('نصوص عربية BPE')),
                    DataCell(Text('موجة صوت معالجة 16kHz')),
                    DataCell(Text('مقاطع زمنية VadSegment')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('الحجم على القرص')),
                    DataCell(Text('187.8 MB')),
                    DataCell(Text('98.8 MB')),
                    DataCell(Text('0.51 MB')),
                    DataCell(Text('2.10 MB')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('منفذ التشغيل')),
                    DataCell(Text('ORT 1.28.2 FFI (MatMulNBits)')),
                    DataCell(Text('Sherpa-ONNX OfflineRecognizer')),
                    DataCell(Text('Sherpa-ONNX SpeechDenoiser')),
                    DataCell(Text('Sherpa-ONNX VAD (512 smp)')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('دقة أطفال مصريين (Pediatric)')),
                    DataCell(
                      Text(
                        'غير مُتحقق سريرياً بعد (لا توجد بيانات أطفال مسجلة)',
                      ),
                    ),
                    DataCell(
                      Text('يميل لتصحيح الأخطاء أو الهلوسة في الكلمات المفردة'),
                    ),
                    DataCell(Text('معتمد للمعالجة 16kHz')),
                    DataCell(Text('مُفعّل بتقطيع 512 عينة')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('الترخيص')),
                    DataCell(Text('Apache-2.0')),
                    DataCell(Text('MIT')),
                    DataCell(Text('MIT')),
                    DataCell(Text('MIT')),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

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
                  'ملاحظات هندسية موثقة:',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '1. تم استبدال نهج Whisper + G2P بنموذج Wav2Vec2-LV60-eSpeak الصوتي المباشر، لأن Whisper قد يهلوس أو يصحح نطق الطفل بدلاً من كشف الإبدال الفعلي مثل [ك -> ت].\n\n'
                  '2. مجلدات zipformer_v2 و zipformer_v3 تحتوي قوائم نصوص فقط ولا تحتوي ملفات ONNX، ولذلك لا يُعتمد عليها في الاستدلال.\n\n'
                  '3. تقييم دقة كلام الأطفال الحقيقي باللهجة المصرية غير مكتمل لعدم توفر مجموعة بيانات صوتية للأطفال في هذا المستودع (التحقق الحالي تم على كلام بالغين عربي + TTS + ضوضاء).',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
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
