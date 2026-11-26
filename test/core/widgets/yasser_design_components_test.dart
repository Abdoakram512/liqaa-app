import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/theme/app_colors.dart';
import 'package:liqaa_app/core/theme/app_theme.dart';
import 'package:liqaa_app/core/widgets/primary_button.dart';
import 'package:liqaa_app/core/widgets/yasser_buttons.dart';
import 'package:liqaa_app/core/widgets/yasser_otp_field.dart';
import 'package:liqaa_app/core/widgets/yasser_tactile_surface.dart';
import 'package:liqaa_app/core/widgets/yasser_text_field.dart';
import 'package:liqaa_app/features/onboarding/presentation/widgets/onboarding_navigation_bar.dart';

Widget _wrapRtlApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, inner) =>
          Directionality(textDirection: TextDirection.rtl, child: inner!),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('Tactile Buttons & Duplicate-Submit Prevention', () {
    testWidgets('PrimaryButton blocks taps while isLoading is true', (
      tester,
    ) async {
      int tapCount = 0;
      await tester.pumpWidget(
        _wrapRtlApp(
          PrimaryButton(
            label: 'متابعة',
            isLoading: true,
            onPressed: () => tapCount++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(tapCount, equals(0));
    });

    testWidgets('YasserRecordingButton blocks taps during processing state', (
      tester,
    ) async {
      int recordTaps = 0;
      await tester.pumpWidget(
        _wrapRtlApp(
          YasserRecordingButton(
            state: RecordingOrbState.processing,
            statusLabel: 'جاري التحليل...',
            onTap: () => recordTaps++,
          ),
        ),
      );

      await tester.tap(find.byType(YasserRecordingButton));
      await tester.pump();
      expect(recordTaps, equals(0));
    });

    testWidgets(
      'OnboardingNavigationBar maintains consistent brand orange CTA on all pages',
      (tester) async {
        for (int page = 0; page < 3; page++) {
          await tester.pumpWidget(
            _wrapRtlApp(
              OnboardingNavigationBar(
                currentIndex: page,
                totalPages: 3,
                isFirstPage: page == 0,
                isLastPage: page == 2,
                activeColor:
                    AppColors.accentCoral, // Even if legacy caller passes coral
                onNext: () {},
                onPrevious: () {},
              ),
            ),
          );
          await tester.pump();

          final surfaces = tester
              .widgetList<YasserTactileButtonSurface>(
                find.byType(YasserTactileButtonSurface),
              )
              .toList();
          expect(surfaces.last.fillColor, equals(AppColors.primary));
          expect(surfaces.last.lipColor, equals(AppColors.primaryDark));
        }
      },
    );
  });

  group('YasserTextField & YasserOtpField Behaviour', () {
    testWidgets(
      'email and phone fields enforce LTR text direction inside RTL layout',
      (tester) async {
        await tester.pumpWidget(
          _wrapRtlApp(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                YasserTextField(
                  variant: YasserFieldVariant.name,
                  hint: 'الاسم بالعربية',
                ),
                YasserTextField(
                  variant: YasserFieldVariant.email,
                  hint: 'hero@liqaa.app',
                ),
                YasserTextField(
                  variant: YasserFieldVariant.phone,
                  hint: '01012345678',
                ),
              ],
            ),
          ),
        );

        final editableTexts = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .toList();
        expect(editableTexts[0].textDirection, equals(TextDirection.rtl));
        expect(editableTexts[1].textDirection, equals(TextDirection.ltr));
        expect(editableTexts[2].textDirection, equals(TextDirection.ltr));
      },
    );

    testWidgets(
      'validation renders clean inline error message below field without overflow',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrapRtlApp(
            Form(
              key: formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: YasserTextField(
                  variant: YasserFieldVariant.email,
                  label: 'البريد الإلكتروني',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'هذا الحقل مطلوب' : null,
                ),
              ),
            ),
          ),
        );

        expect(formKey.currentState!.validate(), isFalse);
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('هذا الحقل مطلوب'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('YasserOtpField fires onCompleted when 4 digits are entered', (
      tester,
    ) async {
      String? completedCode;
      await tester.pumpWidget(
        _wrapRtlApp(
          YasserOtpField(
            length: 4,
            onCompleted: (code) => completedCode = code,
          ),
        ),
      );

      final inputs = find.byType(TextField);
      expect(inputs, findsNWidgets(4));

      await tester.enterText(inputs.at(0), '1');
      await tester.pump();
      await tester.enterText(inputs.at(1), '2');
      await tester.pump();
      await tester.enterText(inputs.at(2), '3');
      await tester.pump();
      await tester.enterText(inputs.at(3), '4');
      await tester.pump();

      expect(completedCode, equals('1234'));
    });
  });
}
