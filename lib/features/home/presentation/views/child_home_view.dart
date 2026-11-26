import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/yasser_audio_settings_sheet.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_speech_bubble.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../authentication/data/models/user_model.dart';
import '../../../authentication/data/repos/auth_repo.dart';
import '../../../onboarding/data/repos/onboarding_repo.dart';
import '../../data/child_progress_service.dart';

/// Child & Parent World Hub — warm, playful, story-driven home launchpad
/// anchored by Yasser with real persisted stars & adventure sound islands.
class ChildHomeView extends StatefulWidget {
  const ChildHomeView({super.key});

  @override
  State<ChildHomeView> createState() => _ChildHomeViewState();
}

class _ChildHomeViewState extends State<ChildHomeView> {
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (!sl.isRegistered<AuthRepo>()) return;
    final user = await sl<AuthRepo>().getCurrentUser();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  void _launchTraining({String? category}) {
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      sl<YasserAudioCoordinator>().playSfx(YasserSfx.activitySelect);
    }
    final uri = Uri(
      path: AppRoutes.game,
      queryParameters: category != null ? {'category': category} : null,
    );
    context.push(uri.toString());
  }

  Future<void> _handleLogout() async {
    if (sl.isRegistered<AuthRepo>()) {
      await sl<AuthRepo>().logout();
    }
    if (mounted) {
      context.go(AppRoutes.auth);
    }
  }

  Future<void> _handleReplayOnboarding() async {
    if (sl.isRegistered<OnboardingRepo>()) {
      await sl<OnboardingRepo>().resetOnboarding();
    }
    if (mounted) {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = YasserMotion.isReducedMotion(context);
    final progressService = sl.isRegistered<ChildProgressService>()
        ? sl<ChildProgressService>()
        : null;

    return Scaffold(
      body: PhonologicalBackground(
        variant: PhonologicalSceneVariant.playfulHills,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: progressService ?? ChangeNotifier(),
            builder: (context, _) {
              final snapshot =
                  progressService?.snapshot ?? const ChildProgressSnapshot();
              final heroName = (_currentUser?.name.trim().isNotEmpty ?? false)
                  ? _currentUser!.name.trim()
                  : 'بطل لقاء';
              final isParent = _currentUser?.role == UserRole.parent;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildTopHeader(context, heroName, isParent, snapshot),
                        SizedBox(height: 18.h),
                        _buildHeroCompanionStage(
                          context,
                          heroName,
                          snapshot,
                          reduced,
                        ),
                        SizedBox(height: 18.h),
                        _buildPrimaryTrainingCard(context, snapshot),
                        SizedBox(height: 22.h),
                        Row(
                          children: [
                            const Icon(
                              Icons.explore_rounded,
                              color: AppColors.primaryDark,
                              size: 22,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'جزر الأصوات الممتعة',
                              style: AppTextStyles.headlineMedium,
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'اختر مجموعة الأصوات التي تريد التدرّب عليها اليوم مع ياسر',
                          style: AppTextStyles.bodySmall,
                        ),
                        SizedBox(height: 14.h),
                        _buildSoundIslandsGrid(context),
                        if (kDebugMode) ...[
                          SizedBox(height: 20.h),
                          _buildDeveloperDiagnosticsFooter(context),
                        ],
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    String heroName,
    bool isParent,
    ChildProgressSnapshot snapshot,
  ) {
    return Row(
      children: [
        // Hero Greeting Chip
        Expanded(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: ShapeDecoration(
                  gradient: AppColors.primaryCtaGradient,
                  shape: YasserShapes.squircle(16),
                  shadows: const [
                    BoxShadow(
                      color: AppColors.shadowPrimary,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isParent ? Icons.family_restroom_rounded : Icons.face_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isParent ? 'وضع ولي الأمر' : 'عالم ياسر الصوتي',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'أهلاً يا $heroName!',
                      style: AppTextStyles.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Earned Stars Pill
        DecoratedBox(
          decoration: ShapeDecoration(
            color: AppColors.accentGoldSoft,
            shape: YasserShapes.squircle(
              14,
              side: const BorderSide(color: AppColors.accentGold, width: 1.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AppColors.primaryDark,
                  size: 21,
                ),
                SizedBox(width: 4.w),
                Text(
                  '${snapshot.totalStars}',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: 10.w),

        // Audio & Account Settings Button
        YasserIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'الإعدادات والصوت',
          onPressed: () {
            if (!sl.isRegistered<YasserAudioCoordinator>()) return;
            showYasserAudioSettingsSheet(
              context,
              coordinator: sl<YasserAudioCoordinator>(),
              onReplayOnboarding: _handleReplayOnboarding,
              onLogout: _handleLogout,
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeroCompanionStage(
    BuildContext context,
    String heroName,
    ChildProgressSnapshot snapshot,
    bool reduced,
  ) {
    final String speechText = snapshot.masteredCount == 0
        ? 'أنا ياسر صاحبك! اضغط على الزر البرتقالي ويلا ننطق أول كلمة سوا!'
        : 'برافو يا بطل! أتقنت ${snapshot.masteredCount} كلمات حتى الآن. يلا نجمع نجوم جديدة!';

    return SizedBox(
      height: 208.h.clamp(186.0, 236.0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _HomeCompanionMeadowPainter()),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'yasser_primary_stage_hero',
                  child: YasserCharacter(
                    state: YasserAnimationState.greeting,
                    width: 128.w.clamp(112.0, 146.0),
                    height: 184.h.clamp(164.0, 208.0),
                    enableTapReaction: true,
                    onTap: () {
                      if (sl.isRegistered<YasserAudioCoordinator>()) {
                        sl<YasserAudioCoordinator>().playSfx(
                          YasserSfx.buttonTap,
                        );
                      }
                    },
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      YasserSpeechBubble(
                            tailDirection: SpeechBubbleTailDirection.start,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.h,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      'رسالة ياسر اليوم',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5.h),
                                Text(
                                  speechText,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate(target: reduced ? 0 : 1)
                          .fadeIn(duration: 360.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryTrainingCard(
    BuildContext context,
    ChildProgressSnapshot snapshot,
  ) {
    const int totalDictionaryWords = 28;
    final double progress = (snapshot.masteredCount / totalDictionaryWords)
        .clamp(0.0, 1.0);

    return YasserSurfaceCard(
      padding: EdgeInsets.all(20.w),
      radius: AppSpacing.radiusXL,
      lipDepth: 5.0,
      lipColor: AppColors.primaryLight,
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: ShapeDecoration(
                  color: AppColors.primarySoft,
                  shape: YasserShapes.squircle(16),
                ),
                child: const Icon(
                  Icons.mic_external_on_rounded,
                  color: AppColors.primaryDark,
                  size: 28,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'استوديو النطق التفاعلي',
                      style: AppTextStyles.headlineSmall,
                    ),
                    Text(
                      'انطق الكلمات بصوتك واستمع لتوجيهات ياسر الفورية',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Honest Progress Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: ShapeDecoration(
              color: AppColors.surfaceVariant,
              shape: YasserShapes.squircle(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الكلمات المتقنة',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${snapshot.masteredCount} / $totalDictionaryWords كلمة',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: AppColors.borderSoft,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          YasserGameActionButton(
            label: 'ابدأ رحلة النطق الآن',
            subtitle: snapshot.lastPracticedWordArabic != null
                ? 'آخر تدريب: كلمة "${snapshot.lastPracticedWordArabic}"'
                : '28 بطاقة مصورة بالعامية المصرية',
            icon: Icons.play_arrow_rounded,
            onPressed: () => _launchTraining(),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundIslandsGrid(BuildContext context) {
    final islands = [
      (
        title: 'أصوات الشفاه واللسان',
        letters: 'ب • م • ت • ل • ر',
        subtitle: 'كلمات سهلة ومحبوبة للبداية',
        icon: Icons.record_voice_over_rounded,
        accent: AppColors.primary,
        tint: AppColors.primarySoft,
        category: 'front_oral',
      ),
      (
        title: 'أصوات الصفير والهمس',
        letters: 'س • ز • ش • ف',
        subtitle: 'تدريب مخارج الهواء بوضوح',
        icon: Icons.air_rounded,
        accent: AppColors.teal,
        tint: AppColors.tealSoft,
        category: 'fricatives',
      ),
      (
        title: 'الأصوات القوية والعميقة',
        letters: 'ك • ق • ج • ع • خ',
        subtitle: 'تحدي الأبطال للأصوات الخلفية',
        icon: Icons.graphic_eq_rounded,
        accent: AppColors.secondary,
        tint: AppColors.secondarySoft,
        category: 'back_emphatic',
      ),
      (
        title: 'التحدي الشامل',
        letters: 'كل البطاقات (28)',
        subtitle: 'جولة منوّعة في جميع الأصوات',
        icon: Icons.workspace_premium_rounded,
        accent: AppColors.accentCoral,
        tint: AppColors.accentCoralSoft,
        category: null,
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < islands.length; i++) ...[
          if (i > 0) SizedBox(height: 12.h),
          _SoundIslandCard(
            title: islands[i].title,
            letters: islands[i].letters,
            subtitle: islands[i].subtitle,
            icon: islands[i].icon,
            accent: islands[i].accent,
            tint: islands[i].tint,
            onTap: () => _launchTraining(category: islands[i].category),
          ),
        ],
      ],
    );
  }

  Widget _buildDeveloperDiagnosticsFooter(BuildContext context) {
    return YasserSurfaceCard(
      backgroundColor: AppColors.surfaceVariant,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      radius: AppSpacing.radiusM,
      lipDepth: 2.0,
      child: Row(
        children: [
          const Icon(
            Icons.developer_mode_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'أدوات المطور (Debug فقط)',
              style: AppTextStyles.labelSmall,
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.aiLab),
            child: const Text('مختبر AI'),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.animationLab),
            child: const Text('مختبر Rive'),
          ),
        ],
      ),
    );
  }
}

class _SoundIslandCard extends StatelessWidget {
  final String title;
  final String letters;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;

  const _SoundIslandCard({
    required this.title,
    required this.letters,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return YasserSurfaceCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      radius: AppSpacing.radiusL,
      lipDepth: 4.0,
      borderColor: accent.withValues(alpha: 0.28),
      lipColor: accent.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: ShapeDecoration(
              color: tint,
              shape: YasserShapes.squircle(16),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  letters,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(subtitle, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: ShapeDecoration(
              color: tint,
              shape: YasserShapes.squircle(11),
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCompanionMeadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final RRect card = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(28),
    );

    canvas.drawRRect(
      card,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.primaryContainer.withValues(alpha: 0.90),
            AppColors.surface.withValues(alpha: 0.92),
          ],
        ).createShader(bounds),
    );

    // Soft organic hill wave along bottom
    final Path hill = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.64,
        size.width * 0.72,
        size.height * 0.80,
      )
      ..quadraticBezierTo(
        size.width * 0.90,
        size.height * 0.86,
        size.width,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipRRect(card);
    canvas.drawPath(
      hill,
      Paint()..color = AppColors.primaryLight.withValues(alpha: 0.42),
    );
    canvas.restore();

    canvas.drawRRect(
      card,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
