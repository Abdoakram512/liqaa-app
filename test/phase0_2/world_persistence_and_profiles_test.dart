import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/features/specialist/data/models/specialist_models.dart';
import 'package:liqaa_app/features/specialist/data/repos/specialist_repository.dart';
import 'package:liqaa_app/features/specialist/presentation/cubits/specialist_cubit.dart';
import 'package:liqaa_app/features/world/data/child_world_repository.dart';
import 'package:liqaa_app/features/world/data/models/world_models.dart';
import 'package:liqaa_app/features/world/data/world_catalog.dart';
import 'package:liqaa_app/features/world/presentation/cubits/child_world_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 0.2 Personalized World & Multi-Profile Persistence', () {
    test(
      'multi-profile creation, switching, garden/decoration customization & isolated reload',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo1 = ChildWorldRepository(prefs);
        final cubit1 = ChildWorldCubit(repo1);

        expect(cubit1.state.profiles.length, 1);
        expect(cubit1.state.activeProfileId, 'profile_default');

        await cubit1.updateActiveProfile(
          displayName: 'عمر',
          themeId: 'sky_breeze',
        );
        await cubit1.unlockAndPlantCollectible('flower_sun_garden');
        await cubit1.unlockAndPlantCollectible('deco_star_garland');
        await cubit1.toggleHomeDecoration('deco_star_garland');
        await cubit1.markWordDiscovered('word_kora');

        // Create second isolated profile
        final secondProfile = await cubit1.createAndSwitchProfile(
          displayName: 'ليلى',
          avatarId: 'cute_cat',
          themeId: 'berry_garden',
          favoriteAnimalId: 'animal_cat',
          interests: const ['الزهور', 'الحكايات'],
        );

        expect(cubit1.state.activeProfileId, secondProfile.id);
        expect(cubit1.state.activeProfile.displayName, 'ليلى');
        expect(
          cubit1.state.worldState.discoveredWordIds,
          isEmpty,
          reason: 'Second child profile must start with clean discovery set',
        );
        expect(
          cubit1.state.worldState.plantedFlowerIds,
          contains('flower_meadow_daisy'),
        );
        expect(
          cubit1.state.worldState.plantedFlowerIds,
          isNot(contains('flower_sun_garden')),
        );
        await cubit1.close();

        // Reload from persisted SharedPreferences
        final repo2 = ChildWorldRepository(prefs);
        final cubit2 = ChildWorldCubit(repo2);
        expect(cubit2.state.profiles.length, 2);
        expect(cubit2.state.activeProfileId, secondProfile.id);
        expect(cubit2.state.activeProfile.displayName, 'ليلى');

        // Switch back to Omar and confirm flowers, decorations, and words survived
        await cubit2.switchProfile('profile_default');
        expect(cubit2.state.activeProfile.displayName, 'عمر');
        expect(cubit2.state.activeProfile.themeId, 'sky_breeze');
        expect(
          cubit2.state.worldState.plantedFlowerIds,
          containsAll(['flower_meadow_daisy', 'flower_sun_garden']),
        );
        expect(
          cubit2.state.worldState.placedHomeDecorationIds,
          contains('deco_star_garland'),
        );
        expect(
          cubit2.state.worldState.discoveredWordIds,
          contains('word_kora'),
        );
        await cubit2.close();
      },
    );

    test(
      'activity outcome counters strictly separate listening, discrimination, pronunciation, and inconclusive attempts',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cubit = ChildWorldCubit(ChildWorldRepository(prefs));

        await cubit.recordActivityOutcome(
          ActivityOutcomeRecord(
            id: 'listen_1',
            activityId: 'step_listen',
            gameType: MiniGameType.listenAndChoose,
            regionId: WorldRegionId.soundGarden,
            timestamp: DateTime(2026, 11, 27, 10),
            listeningCorrect: 3,
            listeningTotal: 4,
          ),
        );

        await cubit.recordActivityOutcome(
          ActivityOutcomeRecord(
            id: 'discrim_1',
            activityId: 'step_discrim',
            gameType: MiniGameType.hearDifference,
            regionId: WorldRegionId.animalForest,
            timestamp: DateTime(2026, 11, 27, 10, 5),
            discriminationCorrect: 4,
            discriminationTotal: 4,
          ),
        );

        await cubit.recordActivityOutcome(
          ActivityOutcomeRecord(
            id: 'pron_inconclusive_1',
            activityId: 'step_repeat',
            gameType: MiniGameType.repeatAfterYasser,
            regionId: WorldRegionId.soundGarden,
            timestamp: DateTime(2026, 11, 27, 10, 10),
            completed: true,
            pronunciationPassed: null,
            inconclusiveTechnicalCount: 2,
          ),
        );

        await cubit.recordActivityOutcome(
          ActivityOutcomeRecord(
            id: 'pron_real_1',
            activityId: 'step_name',
            gameType: MiniGameType.nameThePicture,
            regionId: WorldRegionId.wordIsland,
            timestamp: DateTime(2026, 11, 27, 10, 15),
            completed: true,
            pronunciationPassed: true,
          ),
        );

        final ws = cubit.state.worldState;
        expect(ws.listeningCorrect, 3);
        expect(ws.listeningTotal, 4);
        expect(ws.discriminationCorrect, 4);
        expect(ws.discriminationTotal, 4);
        expect(ws.pronunciationAttempts, 1);
        expect(ws.pronunciationPassedCount, 1);
        expect(ws.inconclusiveCount, 2);
        await cubit.close();
      },
    );

    test(
      'contextual daily greeting reflects unseen reward, specialist assignment, return delay, resume, and progress',
      () {
        final now = DateTime.now();
        final profile = ChildProfile(
          id: 'p1',
          displayName: 'زينة',
          createdAt: now,
          lastVisitedAt: now,
        );

        final unseenGreeting = WorldContentAdapter.buildDailyGreeting(
          profile: profile,
          worldState: const ChildWorldState(
            profileId: 'p1',
            unseenCollectibleIds: {'flower_sun_garden'},
          ),
        );
        expect(unseenGreeting, contains('زهرة الشمس الذهبية'));

        final assignment = SpecialistActivityAssignment(
          id: 'asg_1',
          caseId: 'c1',
          childProfileId: 'p1',
          title: 'تدريب السين',
          targetPhonemes: const ['س', 'ش'],
          difficultyLevel: 1,
          assignedRegionId: 'sound_garden',
          assignedGameTypes: const ['discover_word'],
          createdAt: now,
          isActive: true,
        );
        final specialistGreeting = WorldContentAdapter.buildDailyGreeting(
          profile: profile,
          worldState: const ChildWorldState(profileId: 'p1'),
          activeAssignment: assignment,
        );
        expect(specialistGreeting, contains('الأخصائي'));
        expect(specialistGreeting, contains('س'));

        final firstTimeGreeting = WorldContentAdapter.buildDailyGreeting(
          profile: profile,
          worldState: const ChildWorldState(profileId: 'p1'),
        );
        expect(firstTimeGreeting, contains('أول مغامرة'));

        final returningGreeting = WorldContentAdapter.buildDailyGreeting(
          profile: profile,
          worldState: ChildWorldState(
            profileId: 'p1',
            completedAdventureIds: const {'adv_sound_garden'},
            lastSessionAt: now.subtract(const Duration(hours: 72)),
          ),
        );
        expect(returningGreeting, contains('نورت بيتك من تاني'));

        final resumeGreeting = WorldContentAdapter.buildDailyGreeting(
          profile: profile,
          worldState: ChildWorldState(
            profileId: 'p1',
            outcomes: [
              ActivityOutcomeRecord(
                id: 'o0',
                activityId: 'sg_step_1',
                gameType: MiniGameType.discoverWord,
                regionId: WorldRegionId.soundGarden,
                timestamp: now.subtract(const Duration(hours: 2)),
              ),
            ],
            lastActiveActivityId: 'sg_step_2',
            lastSessionAt: now.subtract(const Duration(hours: 2)),
          ),
        );
        expect(resumeGreeting, contains('نكمّل رحلتنا'));
      },
    );

    test(
      'specialist personalized adventure assignment and removal persist across workspace reload',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cubit1 = SpecialistCubit(SpecialistLocalRepository(prefs));
        await cubit1.loadWorkspace();

        final c = await cubit1.createCase(
          childName: 'آدم',
          ageYears: 5,
          targetPhonemes: const ['ر', 'ك'],
        );

        final created = await cubit1.assignPersonalizedAdventure(
          caseId: c.id,
          childProfileId: 'profile_default',
          title: 'مغامرة حديقة الأصوات',
          targetPhonemes: const ['ر'],
          difficultyLevel: 2,
          assignedRegionId: 'sound_garden',
        );

        expect(cubit1.state.assignmentsForCase(c.id).length, 1);
        expect(
          cubit1.state.activeAssignmentForProfile('profile_default')?.id,
          created.id,
        );
        await cubit1.close();

        final cubit2 = SpecialistCubit(SpecialistLocalRepository(prefs));
        await cubit2.loadWorkspace();
        expect(cubit2.state.assignmentsForCase(c.id).length, 1);
        expect(
          cubit2.state.assignmentsForCase(c.id).first.targetPhonemes,
          equals(['ر']),
        );

        await cubit2.removeAssignment(created.id);
        expect(cubit2.state.assignmentsForCase(c.id), isEmpty);
        await cubit2.close();
      },
    );
  });
}
