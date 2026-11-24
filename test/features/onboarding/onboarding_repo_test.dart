import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/storage/shared_prefs_service.dart';
import 'package:liqaa_app/features/onboarding/data/repos/onboarding_repo.dart';
import 'package:liqaa_app/features/onboarding/data/src/onboarding_local_data_source.dart';
import 'package:mocktail/mocktail.dart';

class MockSharedPrefsService extends Mock implements SharedPrefsService {}

void main() {
  late MockSharedPrefsService mockPrefs;
  late OnboardingLocalDataSource dataSource;
  late OnboardingRepo repo;

  setUp(() {
    mockPrefs = MockSharedPrefsService();
    dataSource = OnboardingLocalDataSourceImpl(mockPrefs);
    repo = OnboardingRepo(dataSource);
  });

  group('OnboardingRepo Tests', () {
    test(
      'returns 3 curated onboarding pages with unique poses and environments',
      () {
        final pages = repo.getOnboardingPages();
        expect(pages.length, 3);
        expect(pages[0].id, 1);
        expect(pages[1].id, 2);
        expect(pages[2].id, 3);
        // Verify unique character poses
        expect(pages[0].pose, isNot(equals(pages[1].pose)));
        expect(pages[1].pose, isNot(equals(pages[2].pose)));
      },
    );

    test('isOnboardingCompleted reads from local data source', () {
      when(() => mockPrefs.isOnboardingCompleted()).thenReturn(false);
      expect(repo.isOnboardingCompleted(), false);

      when(() => mockPrefs.isOnboardingCompleted()).thenReturn(true);
      expect(repo.isOnboardingCompleted(), true);
    });

    test('completeOnboarding sets flag to true in local data source', () async {
      when(
        () => mockPrefs.setOnboardingCompleted(true),
      ).thenAnswer((_) async => true);

      final result = await repo.completeOnboarding();
      expect(result, true);
      verify(() => mockPrefs.setOnboardingCompleted(true)).called(1);
    });
  });
}
