import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/ai/models/lab_task_mode.dart';
import '../../../../core/ai/rnnoise_denoiser_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class NoiseReductionView extends StatefulWidget {
  const NoiseReductionView({super.key});

  @override
  State<NoiseReductionView> createState() => _NoiseReductionViewState();
}

class _NoiseReductionViewState extends State<NoiseReductionView> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _startingPlayback = false;

  Future<void> _playWav(Uint8List bytes) async {
    if (_startingPlayback || bytes.isEmpty) return;
    _startingPlayback = true;
    try {
      await _audioPlayer.stop();
      if (!mounted) return;
      await _audioPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذّر تشغيل ملف WAV: $e')));
    } finally {
      _startingPlayback = false;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('3. عزل الضوضاء العصبي (GTCRN)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          final audio = state.lastAudioResult;

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // Denoiser Mode Selector (GTCRN Neural / DSP Wiener / Bypass)
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
                      'وضع معالجة الضوضاء (16kHz Enhancement Mode)',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SegmentedButton<DenoiserMode>(
                      segments: const [
                        ButtonSegment(
                          value: DenoiserMode.neuralGtcrn,
                          label: Text('GTCRN عصبي'),
                        ),
                        ButtonSegment(
                          value: DenoiserMode.dspWienerFallback,
                          label: Text('DSP احتياطي'),
                        ),
                        ButtonSegment(
                          value: DenoiserMode.bypass,
                          label: Text('تخطي خام'),
                        ),
                      ],
                      selected: {state.denoiserMode},
                      onSelectionChanged: (s) {
                        context.read<AiLabCubit>().setDenoiserMode(s.first);
                      },
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'GTCRN Simple (ONNX 16kHz) يحفظ أصوات الاحتكاك (س، ش، ف) بخلاف rnnoise 48kHz غير المتوافق.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Recording Action
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  children: [
                    Text(
                      'سجّل مقطع صوتي في بيئة بها ضوضاء للمقارنة',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isRecording
                            ? Colors.red
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                      ),
                      icon: Icon(
                        state.isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                      ),
                      label: Text(
                        state.isRecording
                            ? 'إيقاف التسجيل والتحليل'
                            : 'بدء تسجيل تجريبي',
                      ),
                      onPressed: () async {
                        await _audioPlayer.stop();
                        if (!context.mounted) return;
                        if (state.isRecording) {
                          context.read<AiLabCubit>().stopRecordingAndRunTask(
                            LabTaskMode.noiseReduction,
                          );
                        } else {
                          context.read<AiLabCubit>().startRecording();
                        }
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              Text(
                'نتائج المقارنة الصوتية (Raw vs Denoised)',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 12.h),

              if (audio == null)
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'قم بالتسجيل للاستماع إلى الصوت قبل وبعد عزل الضوضاء',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    // Dual comparison players (STRICTLY NO silent fallback to rawAudioBytes)
                    if (audio.errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          'خطأ المعالجة: ${audio.errorMessage}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderSoft),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.mic_none_rounded,
                                  color: Colors.orange,
                                  size: 28,
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'الأصلي (${audio.sampleRate} Hz)',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'RMS: ${audio.averageRms}\nPeak: ${audio.peakAmplitude}\nSNR: ${audio.snrDb} dB',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall,
                                ),
                                SizedBox(height: 10.h),
                                IconButton(
                                  icon: const Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.orange,
                                    size: 40,
                                  ),
                                  onPressed: audio.rawAudioBytes.isEmpty
                                      ? null
                                      : () async {
                                          await _playWav(audio.rawAudioBytes);
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepPurpleAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.auto_fix_high_rounded,
                                  color: Colors.deepPurpleAccent,
                                  size: 28,
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'المعالج (${audio.denoiserFilterType})',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  audio.denoisedAudioBytes != null
                                      ? 'RMS: ${audio.denoisedRms}\nPeak: ${audio.denoisedPeakAmplitude}\nSNR Δ: ${audio.snrImprovementDb >= 0 ? "+" : ""}${audio.snrImprovementDb} dB'
                                      : 'تعذّر التشغيل (فشل المعالجة)',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: audio.denoisedAudioBytes != null
                                        ? Colors.green.shade800
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                IconButton(
                                  icon: Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: audio.denoisedAudioBytes != null
                                        ? Colors.deepPurpleAccent
                                        : Colors.grey.shade400,
                                    size: 40,
                                  ),
                                  onPressed:
                                      audio.denoisedAudioBytes == null ||
                                          audio.denoisedAudioBytes!.isEmpty
                                      ? null
                                      : () async {
                                          await _playWav(
                                            audio.denoisedAudioBytes!,
                                          );
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // Acoustic Note Card
                    Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.amber.shade900,
                            size: 20,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'تنبيه صوتي سريري: عزل الضوضاء القوي قد يخفف أصوات الاحتكاك الضعيفة مثل السين والفاء والشين عند الأطفال. يُنصح بإلغاء التفعيل في الغرف الهادئة للحفاظ على دقة النطق.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
