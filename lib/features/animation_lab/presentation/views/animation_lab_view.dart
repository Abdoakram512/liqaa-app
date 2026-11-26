import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/animation/yasser/yasser_animation_capabilities.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/animation/yasser/yasser_rive_controller.dart';
import '../../../../core/animation/yasser/yasser_viseme.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_text_field.dart';
import '../../../pronunciation_game/models/yasser_prompt.dart';

/// Mandatory Developer Bench: Yasser Animation & Rig QA Lab.
///
/// Provides independent auditing, skeletal/IK joint inspection, 9-viseme + WAV
/// lip-sync playback, continuous gaze driving, rapid interruption stress
/// testing, and live `ViewModel1` single-owner diagnostics.
class AnimationLabView extends StatefulWidget {
  const AnimationLabView({super.key});

  @override
  State<AnimationLabView> createState() => _AnimationLabViewState();
}

class _AnimationLabViewState extends State<AnimationLabView>
    with SingleTickerProviderStateMixin {
  late YasserController _controller;
  late TabController _tabController;

  double _characterScale = 1.0;
  double _playbackSpeed = 1.0;
  bool _isPaused = false;
  bool _showRigOverlay = false;
  bool _reducedMotion = false;

  double _eyeX = 0.0;
  double _eyeY = 0.0;
  int? _directMouthShape;
  YasserViseme _activeViseme = YasserViseme.rest;

  bool _stressTestRunning = false;
  Timer? _stressTimer;
  Timer? _lipSyncTimer;
  Timer? _telemetryTimer;

  YasserRigDebugSnapshot? _rigSnapshot;
  YasserAudioCoordinator? _audioCoordinator;

  final _simNameController = TextEditingController();
  final _simPasswordController = TextEditingController();
  final _customWordController = TextEditingController(text: 'فراولة');

  @override
  void initState() {
    super.initState();
    _controller = YasserController();
    _tabController = TabController(length: 4, vsync: this);
    _simNameController.addListener(_handleNameTyping);

    if (sl.isRegistered<YasserAudioCoordinator>()) {
      _audioCoordinator = sl<YasserAudioCoordinator>();
      _audioCoordinator!.visemeNotifier.addListener(_onAudioVisemeChanged);
    }

    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      final snap = _controller.readRigSnapshot();
      if (snap != null || _showRigOverlay) {
        setState(() => _rigSnapshot = snap);
      }
    });
  }

  @override
  void dispose() {
    _stressTimer?.cancel();
    _lipSyncTimer?.cancel();
    _telemetryTimer?.cancel();
    _audioCoordinator?.visemeNotifier.removeListener(_onAudioVisemeChanged);
    _simNameController.removeListener(_handleNameTyping);
    _controller.dispose();
    _tabController.dispose();
    _simNameController.dispose();
    _simPasswordController.dispose();
    _customWordController.dispose();
    super.dispose();
  }

  void _onAudioVisemeChanged() {
    final vis = _audioCoordinator?.visemeNotifier.value ?? YasserViseme.rest;
    if (!mounted) return;
    setState(() {
      _activeViseme = vis;
      _directMouthShape = null;
    });
    _controller.setDirectMouthShape(null);
  }

  void _handleNameTyping() {
    final sel = _simNameController.selection;
    final offset = sel.isValid
        ? sel.extentOffset
        : _simNameController.text.length;
    _controller.followCaret(
      offset,
      textLength: _simNameController.text.length,
      rightToLeft: true,
    );
  }

  void _setPlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _controller.riveController?.playbackSpeed = speed;
  }

  void _togglePause() {
    final next = !_isPaused;
    setState(() => _isPaused = next);
    _controller.riveController?.isPaused = next;
  }

  void _stepOneFrame() {
    if (!_isPaused) {
      setState(() => _isPaused = true);
      _controller.riveController?.isPaused = true;
    }
    _controller.riveController?.stepOneFrame();
    setState(() => _rigSnapshot = _controller.readRigSnapshot());
  }

  void _toggleReducedMotion() {
    final next = !_reducedMotion;
    setState(() => _reducedMotion = next);
    final riveCtrl = _controller.riveController;
    if (riveCtrl != null) {
      riveCtrl.reducedMotion = next;
      riveCtrl.applyMapping(_controller.currentMapping);
    }
  }

  Future<void> _playPromptLipSync(String wordId, String arabicLabel) async {
    _lipSyncTimer?.cancel();
    _controller.setDirectMouthShape(null);
    _controller.engine.triggerState(
      YasserAnimationState.talking,
      reason: 'Lab WAV Lip-Sync: $arabicLabel',
    );
    final prompt = YasserPrompt.byWordId[wordId];
    if (prompt == null) return;

    var startedRealAudio = false;
    if (_audioCoordinator != null) {
      startedRealAudio = await _audioCoordinator!.playWordPrompt(prompt);
    }
    if (!startedRealAudio) {
      _previewCueSheet(
        YasserPrompt.cuesForWord(wordId: wordId, arabicWord: arabicLabel),
      );
    }
  }

  void _previewCustomWordLipSync() {
    _lipSyncTimer?.cancel();
    _controller.setDirectMouthShape(null);
    final word = _customWordController.text.trim();
    if (word.isEmpty) return;
    _controller.engine.triggerState(
      YasserAnimationState.talking,
      reason: 'Lab Custom Word Lip-Sync: $word',
    );
    _previewCueSheet(YasserPrompt.cuesForWord(arabicWord: word));
  }

  void _previewCueSheet(List<YasserVisemeCue> cues) {
    _lipSyncTimer?.cancel();
    if (cues.isEmpty) return;
    var elapsed = 0;
    const tickMs = 40;
    final totalMs = cues.last.startMs + 160;
    _lipSyncTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      var nextPose = YasserViseme.rest;
      for (var i = cues.length - 1; i >= 0; i--) {
        if (elapsed >= cues[i].startMs) {
          nextPose = cues[i].pose;
          break;
        }
      }
      setState(() => _activeViseme = nextPose);
      _controller.riveController?.viseme = nextPose;
      elapsed += tickMs;
      if (elapsed > totalMs) {
        t.cancel();
        setState(() => _activeViseme = YasserViseme.rest);
        _controller.riveController?.viseme = YasserViseme.rest;
        _controller.returnToIdle();
      }
    });
  }

  void _runStressTest() {
    if (_stressTestRunning) {
      _stressTimer?.cancel();
      setState(() => _stressTestRunning = false);
      _controller.returnToIdle();
      return;
    }

    setState(() => _stressTestRunning = true);
    const testStates = [
      YasserAnimationState.coveringEyes,
      YasserAnimationState.peeking,
      YasserAnimationState.returningToIdle,
      YasserAnimationState.waving,
      YasserAnimationState.celebrating,
      YasserAnimationState.listening,
      YasserAnimationState.thinking,
      YasserAnimationState.gentleRetry,
      YasserAnimationState.encouraging,
      YasserAnimationState.followingInput,
      YasserAnimationState.idle,
    ];

    int step = 0;
    _stressTimer = Timer.periodic(const Duration(milliseconds: 220), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final s = testStates[step % testStates.length];
      _controller.engine.triggerState(
        s,
        customHoldDuration: const Duration(milliseconds: 180),
        reason: 'Stress Interruption #$step (${s.name})',
      );
      step++;
      if (step > 44) {
        timer.cancel();
        setState(() => _stressTestRunning = false);
        _controller.returnToIdle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'مختبر أنيميشن ياسر (Yasser Lab)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'فحص Rive المباشر',
            onPressed: () => context.push(AppRoutes.riveDiagnostic),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.accessibility_new), text: 'الحالات وفحص اليد'),
            Tab(icon: Icon(Icons.remove_red_eye), text: 'الدخول والنظر'),
            Tab(
              icon: Icon(Icons.record_voice_over),
              text: 'الفم ومزامنة الصوت',
            ),
            Tab(icon: Icon(Icons.analytics), text: 'التشخيص والإجهاد'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStageHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActionButtonsTab(),
                _buildAuthAndGazeTab(),
                _buildMouthAndLipSyncTab(),
                _buildDiagnosticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader() {
    const double stageWidth = 175;
    const double stageHeight = 205;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Live Rive Stage + Optional Skeletal / IK Overlay
              Expanded(
                child: SizedBox(
                  height: stageHeight,
                  child: ClipRect(
                    child: Center(
                      child: Transform.scale(
                        scale: _characterScale,
                        child: SizedBox(
                          width: stageWidth,
                          height: stageHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              YasserCharacter(
                                controller: _controller,
                                viseme: _activeViseme,
                                width: stageWidth,
                                height: stageHeight,
                              ),
                              if (_showRigOverlay && _rigSnapshot != null)
                                IgnorePointer(
                                  child: CustomPaint(
                                    painter: _YasserRigOverlayPainter(
                                      _rigSnapshot!,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Live Telemetry Column
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusChip(
                          _controller.currentState.name,
                          AppColors.primary,
                        ),
                        const SizedBox(height: 5),
                        _buildStatusChip(
                          _controller.engine.currentPriority.name,
                          Colors.indigo,
                        ),
                        const SizedBox(height: 5),
                        _buildStatusChip(
                          _controller.isRiveInitialized
                              ? 'Rive Single-Owner'
                              : '2.5D Fallback',
                          _controller.isRiveInitialized
                              ? AppColors.success
                              : Colors.amber.shade800,
                        ),
                        const SizedBox(height: 5),
                        _buildStatusChip(
                          'Mouth: ${_directMouthShape ?? _activeViseme.mouthShapeIndex}',
                          Colors.teal.shade700,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Zoom, Speed, Frame Step & Overlay Transport Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final z in const [0.8, 1.0, 1.35, 1.7])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(
                        '${z}x',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: (_characterScale - z).abs() < 0.05,
                      onSelected: (_) => setState(() => _characterScale = z),
                    ),
                  ),
                const VerticalDivider(width: 12),
                for (final s in const [0.25, 0.5, 1.0])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(
                        '${s}x spd',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: (_playbackSpeed - s).abs() < 0.05,
                      onSelected: (_) => _setPlaybackSpeed(s),
                    ),
                  ),
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  tooltip: _isPaused ? 'تشغيل' : 'إيقاف مؤقت',
                  onPressed: _togglePause,
                ),
                TextButton(
                  onPressed: _stepOneFrame,
                  child: const Text('+1 Frame', style: TextStyle(fontSize: 11)),
                ),
                FilterChip(
                  label: const Text(
                    'Skeletal QA',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: _showRigOverlay,
                  onSelected: (v) {
                    setState(() {
                      _showRigOverlay = v;
                      _rigSnapshot = _controller.readRigSnapshot();
                    });
                  },
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('Reduced', style: TextStyle(fontSize: 11)),
                  selected: _reducedMotion,
                  onSelected: (_) => _toggleReducedMotion(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButtonsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildSectionHeader('فحص اليدين والخصوصية (Hand & Privacy Rig QA)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTriggerButton(
              'Cover Eyes',
              Icons.visibility_off,
              Colors.purple,
              _controller.coverEyes,
            ),
            _buildTriggerButton(
              'Peek Fingers',
              Icons.remove_red_eye,
              Colors.deepPurple,
              _controller.peek,
            ),
            _buildTriggerButton(
              'Uncover',
              Icons.pan_tool,
              Colors.blueGrey,
              _controller.uncoverEyes,
            ),
            _buildTriggerButton(
              'Wave Open Palm',
              Icons.waving_hand,
              Colors.amber.shade800,
              _controller.wave,
            ),
            _buildTriggerButton(
              'Idle Rest',
              Icons.self_improvement,
              Colors.blue,
              _controller.returnToIdle,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('مشاعر وتدريب النطق (Speech & Celebration)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTriggerButton(
              'Listening',
              Icons.hearing,
              Colors.teal,
              () => _controller.engine.triggerState(
                YasserAnimationState.listening,
              ),
            ),
            _buildTriggerButton(
              'Thinking',
              Icons.lightbulb_outline,
              Colors.orange.shade800,
              _controller.think,
            ),
            _buildTriggerButton(
              'Speaking',
              Icons.record_voice_over,
              Colors.indigo,
              () =>
                  _controller.engine.triggerState(YasserAnimationState.talking),
            ),
            _buildTriggerButton(
              'Encourage',
              Icons.thumb_up_alt_outlined,
              AppColors.success,
              _controller.encourage,
            ),
            _buildTriggerButton(
              'Gentle Retry',
              Icons.support_agent,
              Colors.pink.shade400,
              _controller.gentleRetry,
            ),
            _buildTriggerButton(
              'Celebrate',
              Icons.celebration,
              Colors.green.shade700,
              _controller.celebrate,
            ),
            _buildTriggerButton(
              'Session Complete',
              Icons.emoji_events,
              Colors.deepOrange,
              _controller.sessionComplete,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('فصول الترحيب والانطلاق (Onboarding Chapters)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTriggerButton(
              'Onboarding 1: Welcome',
              Icons.looks_one,
              AppColors.primary,
              () => _controller.setOnboardingScene(1),
            ),
            _buildTriggerButton(
              'Onboarding 2: Discovery',
              Icons.looks_two,
              AppColors.secondary,
              () => _controller.setOnboardingScene(2),
            ),
            _buildTriggerButton(
              'Onboarding 3: Ready',
              Icons.looks_3,
              AppColors.success,
              () => _controller.setOnboardingScene(3),
            ),
          ],
        ),
        if (_rigSnapshot != null) ...[
          const SizedBox(height: 16),
          _buildSectionHeader('إحداثيات أهداف IK الحية (486x695 Artboard)'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _rigSnapshot!.targets.entries
                .map(
                  (e) => Chip(
                    label: Text(
                      '${e.key.replaceFirst('P1_', '')}: (${e.value.dx.toStringAsFixed(1)}, ${e.value.dy.toStringAsFixed(1)})',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAuthAndGazeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('محاكاة حقول الدخول وحماية الخصوصية'),
        YasserTextField(
          label: 'الاسم أو البريد الإلكتروني',
          hint: 'اكتب لمتابعة حركة العين مع مؤشر الكتابة',
          controller: _simNameController,
          prefixIcon: const Icon(Icons.person_outline),
          onFocusChanged: (hasFocus) {
            if (hasFocus) {
              _handleNameTyping();
            } else {
              _controller.returnToIdle();
            }
          },
        ),
        const SizedBox(height: 14),
        YasserTextField(
          label: 'كلمة المرور السرية',
          hint: 'التركيز يغطي العينين وإظهار النص يكشف بإصبع',
          controller: _simPasswordController,
          isPassword: true,
          prefixIcon: const Icon(Icons.lock_outline),
          onFocusChanged: (hasFocus) {
            if (hasFocus) {
              _controller.coverEyes();
            } else {
              _controller.uncoverEyes();
            }
          },
          onPasswordVisibilityChanged: (isVisible) {
            if (isVisible) {
              _controller.peek();
            } else {
              _controller.coverEyes();
            }
          },
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('توجيه النظر التفاعلي (Continuous lookX / lookY)'),
        Center(
          child: GestureDetector(
            onPanUpdate: (details) =>
                _updateGazeFromLocal(details.localPosition),
            onTapDown: (details) => _updateGazeFromLocal(details.localPosition),
            child: Container(
              width: 150,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: CustomPaint(painter: _GazePadPainter(_eyeX, _eyeY)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('lookX: ${_eyeX.toStringAsFixed(2)}'),
        Slider(
          value: _eyeX,
          min: -1.0,
          max: 1.0,
          activeColor: AppColors.primary,
          onChanged: (v) {
            setState(() => _eyeX = v);
            _controller.lookAtInput(normalizedX: _eyeX, normalizedY: _eyeY);
          },
        ),
        Text('lookY: ${_eyeY.toStringAsFixed(2)}'),
        Slider(
          value: _eyeY,
          min: -1.0,
          max: 1.0,
          activeColor: AppColors.primary,
          onChanged: (v) {
            setState(() => _eyeY = v);
            _controller.lookAtInput(normalizedX: _eyeX, normalizedY: _eyeY);
          },
        ),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _eyeX = 0.0;
                _eyeY = 0.0;
              });
              _controller.returnToIdle();
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('إعادة ضبط النظر للمنتصف'),
          ),
        ),
      ],
    );
  }

  void _updateGazeFromLocal(Offset local) {
    final nx = ((local.dx / 150.0) * 2.0 - 1.0).clamp(-1.0, 1.0);
    final ny = ((local.dy / 110.0) * 2.0 - 1.0).clamp(-1.0, 1.0);
    setState(() {
      _eyeX = nx;
      _eyeY = ny;
    });
    _controller.lookAtInput(normalizedX: nx, normalizedY: ny);
  }

  Widget _buildMouthAndLipSyncTab() {
    final shapes = [
      (0, YasserViseme.rest),
      (1, YasserViseme.wideOpen),
      (2, YasserViseme.midOpen),
      (3, YasserViseme.closed),
      (4, YasserViseme.rounded),
      (5, YasserViseme.labiodental),
      (6, YasserViseme.teeth),
      (7, YasserViseme.consonant),
      (8, YasserViseme.calmClosed),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('أوضاع الفم التسعة (Yasser_Mouth_Rig 0..8)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (idx, vis) in shapes)
              ChoiceChip(
                label: Text('$idx: ${vis.arabicLabel}'),
                selected: _directMouthShape == idx,
                onSelected: (_) {
                  _lipSyncTimer?.cancel();
                  setState(() {
                    _directMouthShape = idx;
                    _activeViseme = vis;
                  });
                  _controller.setDirectMouthShape(idx);
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        _buildSectionHeader('تشغيل ومزامنة الصوت الفعلي (Real WAV Lip-Sync)'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildTriggerButton(
              'نطق "سمكة" (WAV Sync)',
              Icons.volume_up,
              AppColors.primary,
              () => _playPromptLipSync('word_samaka', 'سمكة'),
            ),
            _buildTriggerButton(
              'نطق "كرة" (WAV Sync)',
              Icons.volume_up,
              AppColors.secondary,
              () => _playPromptLipSync('word_kora', 'كرة'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildSectionHeader('معاينة تقطيع الكلمات العربية تلقائياً'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customWordController,
                decoration: const InputDecoration(
                  labelText: 'أدخل كلمة عربية',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _previewCustomWordLipSync,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('معاينة'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnosticsTab() {
    final vmValues = _controller.liveRiveViewModelValues;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          'اختبار التحمل والتقاطع السريع (Interruption Stress)',
        ),
        PrimaryButton(
          label: _stressTestRunning
              ? 'إيقاف اختبار التحمل'
              : 'تشغيل اختبار التداخل السريع (44 انتقال)',
          icon: Icon(
            _stressTestRunning ? Icons.stop : Icons.flash_on,
            color: Colors.white,
          ),
          backgroundColor: _stressTestRunning ? Colors.red : Colors.deepOrange,
          onPressed: _runStressTest,
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملكية التحريك (Single-Owner Rive Authority)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rive State Machine 1 + ViewModel1 يتحكم بالكامل في العظام والأذرع والرمش والنظرات والفم بدون أي كتابة إجرائية من Flutter.',
                  style: TextStyle(fontSize: 11.5),
                ),
                if (vmValues.isNotEmpty) ...[
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: vmValues.entries
                        .map(
                          (e) => Text(
                            '${e.key}=${e.value}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('سجل أحداث المحرك الفوري (Event Log)'),
        Container(
          height: 165,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            itemCount: _controller.eventHistory.length,
            itemBuilder: (context, index) {
              final log = _controller
                  .eventHistory[_controller.eventHistory.length - 1 - index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '[${log.timestamp.second}s] ${log.state.name} (${log.priority.name}): ${log.description}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('مصفوفة إمكانيات الإنتاج (Verified Capabilities)'),
        ...YasserAnimationCapabilities.matrix.map((cap) {
          final color = cap.tier == RiveSupportTier.verified
              ? Colors.green
              : Colors.amber.shade800;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Icon(Icons.check_circle, color: color, size: 22),
              title: Text(
                cap.featureName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                '${cap.riveIdentifier}\n${cap.description}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildTriggerButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _YasserRigOverlayPainter extends CustomPainter {
  final YasserRigDebugSnapshot snapshot;

  const _YasserRigOverlayPainter(this.snapshot);

  Offset _toWidget(Offset artboardPt, Size size) {
    final scale =
        (size.width / snapshot.artboardWidth) <
            (size.height / snapshot.artboardHeight)
        ? size.width / snapshot.artboardWidth
        : size.height / snapshot.artboardHeight;
    final dx = (size.width - snapshot.artboardWidth * scale) / 2;
    final dy = (size.height - snapshot.artboardHeight * scale) / 2;
    return Offset(dx + artboardPt.dx * scale, dy + artboardPt.dy * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bonePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final jointPaint = Paint()..color = Colors.amberAccent;
    final targetPaint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final seg in snapshot.bones) {
      final a = _toWidget(seg.start, size);
      final b = _toWidget(seg.end, size);
      canvas.drawLine(a, b, bonePaint);
      canvas.drawCircle(a, 3.0, jointPaint);
      canvas.drawCircle(b, 3.0, jointPaint);
    }

    for (final target in snapshot.targets.values) {
      final p = _toWidget(target, size);
      canvas.drawCircle(p, 5.0, targetPaint);
      canvas.drawLine(
        p + const Offset(-7, 0),
        p + const Offset(7, 0),
        targetPaint,
      );
      canvas.drawLine(
        p + const Offset(0, -7),
        p + const Offset(0, 7),
        targetPaint,
      );
    }

    final facePaint = Paint()..color = Colors.lightGreenAccent;
    for (final anchor in snapshot.facialAnchors.values) {
      canvas.drawCircle(_toWidget(anchor, size), 2.5, facePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _YasserRigOverlayPainter oldDelegate) => true;
}

class _GazePadPainter extends CustomPainter {
  final double lookX;
  final double lookY;

  const _GazePadPainter(this.lookX, this.lookY);

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      guidePaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      guidePaint,
    );

    final pt = Offset(
      ((lookX + 1) / 2) * size.width,
      ((lookY + 1) / 2) * size.height,
    );
    canvas.drawCircle(pt, 9, Paint()..color = AppColors.primary);
    canvas.drawCircle(pt, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GazePadPainter oldDelegate) =>
      oldDelegate.lookX != lookX || oldDelegate.lookY != lookY;
}
