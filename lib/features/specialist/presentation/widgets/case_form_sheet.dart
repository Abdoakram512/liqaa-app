import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../../data/models/specialist_models.dart';

/// Available target Arabic phonemes supported by the Egyptian Arabic training deck.
const List<String> kSupportedTargetPhonemes = [
  'ر',
  'س',
  'ك',
  'ق',
  'ل',
  'ش',
  'ج',
  'ز',
  'ف',
  'ت',
  'د',
  'ب',
  'م',
  'ن',
  'ط',
  'ص',
  'ض',
  'خ',
  'ع',
  'ح',
];

class CaseFormResult {
  final String childName;
  final int ageYears;
  final String? guardianPhone;
  final List<String> targetPhonemes;
  final String clinicalNotes;
  final CaseStatus status;

  const CaseFormResult({
    required this.childName,
    required this.ageYears,
    this.guardianPhone,
    required this.targetPhonemes,
    required this.clinicalNotes,
    required this.status,
  });
}

Future<CaseFormResult?> showCaseFormSheet(
  BuildContext context, {
  SpecialistCase? existingCase,
}) {
  return showModalBottomSheet<CaseFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _CaseFormSheet(existingCase: existingCase),
  );
}

class _CaseFormSheet extends StatefulWidget {
  final SpecialistCase? existingCase;

  const _CaseFormSheet({this.existingCase});

  @override
  State<_CaseFormSheet> createState() => _CaseFormSheetState();
}

class _CaseFormSheetState extends State<_CaseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;

  late int _ageYears;
  late CaseStatus _status;
  late final Set<String> _selectedPhonemes;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCase;
    _nameController = TextEditingController(text: existing?.childName ?? '');
    _phoneController = TextEditingController(
      text: existing?.guardianPhone ?? '',
    );
    _notesController = TextEditingController(
      text: existing?.clinicalNotes ?? '',
    );
    _ageYears = existing?.ageYears ?? 6;
    _status = existing?.status ?? CaseStatus.active;
    _selectedPhonemes = Set<String>.from(
      existing?.targetPhonemes ?? const ['ر', 'س'],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CaseFormResult(
        childName: _nameController.text.trim(),
        ageYears: _ageYears,
        guardianPhone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        targetPhonemes: _selectedPhonemes.toList(),
        clinicalNotes: _notesController.text.trim(),
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existingCase != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: AppColors.background,
          shape: YasserShapes.squircle(
            AppSpacing.radiusXL,
            side: const BorderSide(color: AppColors.borderSoft, width: 1.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    isEdit ? 'تعديل ملف الحالة' : 'إضافة حالة طفل جديدة',
                    style: AppTextStyles.headlineMedium,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'سجّل بيانات الطفل والأصوات المستهدفة لمتابعة الجلسات والمحاولات محلياً.',
                    style: AppTextStyles.bodySmall,
                  ),
                  SizedBox(height: 16.h),

                  YasserTextField(
                    controller: _nameController,
                    variant: YasserFieldVariant.specialistCase,
                    label: 'اسم الطفل *',
                    hint: 'مثال: عمر محمد علي',
                    prefixIcon: const Icon(Icons.child_care_rounded),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'يرجى إدخال اسم الطفل (حرفين على الأقل)';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 14.h),

                  // Age selector strip
                  Text('العمر (بالسنوات)', style: AppTextStyles.labelLarge),
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      for (int age = 3; age <= 12; age++)
                        ChoiceChip(
                          label: Text('$age سنوات'),
                          selected: _ageYears == age,
                          selectedColor: AppColors.primarySoft,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            color: _ageYears == age
                                ? AppColors.primaryDeep
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) => setState(() => _ageYears = age),
                        ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  YasserTextField(
                    controller: _phoneController,
                    variant: YasserFieldVariant.phone,
                    label: 'رقم تواصل ولي الأمر (اختياري)',
                    hint: '01012345678',
                  ),
                  SizedBox(height: 14.h),

                  // Target Phonemes Multi-select
                  Text(
                    'الأصوات المستهدفة للتدريب',
                    style: AppTextStyles.labelLarge,
                  ),
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 7.w,
                    runSpacing: 7.h,
                    children: [
                      for (final ph in kSupportedTargetPhonemes)
                        FilterChip(
                          label: Text(ph),
                          selected: _selectedPhonemes.contains(ph),
                          selectedColor: AppColors.secondarySoft,
                          checkmarkColor: AppColors.secondaryDark,
                          labelStyle: AppTextStyles.titleSmall.copyWith(
                            color: _selectedPhonemes.contains(ph)
                                ? AppColors.secondaryDark
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedPhonemes.add(ph);
                              } else {
                                _selectedPhonemes.remove(ph);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  // Case Status
                  Text('حالة المتابعة', style: AppTextStyles.labelLarge),
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 8.w,
                    children: [
                      for (final st in CaseStatus.values)
                        ChoiceChip(
                          label: Text(st.arabicLabel),
                          selected: _status == st,
                          selectedColor: AppColors.primarySoft,
                          onSelected: (_) => setState(() => _status = st),
                        ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  if (!isEdit) ...[
                    YasserTextField(
                      controller: _notesController,
                      variant: YasserFieldVariant.multilineNotes,
                      label: 'ملاحظات أولية للأخصائي (اختياري)',
                      hint:
                          'ملاحظات حول مخارج الحروف المستهدفة أو خطة التدريب...',
                    ),
                    SizedBox(height: 18.h),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'إلغاء',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: isEdit ? 'حفظ التعديلات' : 'إنشاء ملف الحالة',
                          icon: const Icon(Icons.check_rounded),
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
