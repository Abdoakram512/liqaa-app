import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/animation/yasser/yasser_animation_capabilities.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_text_field.dart';

/// Mandatory Developer Bench: Yasser Animation Lab
///
/// Provides deep independent auditing, stress-testing, continuous input
/// driving, and runtime diagnostics for the Yasser Rive character.
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
  double _eyeX = 0.0;
  double _eyeY = 0.0;
  bool _stressTestRunning = false;
  Timer? _stressTimer;

  // Simulation form controllers
  final _simNameController = TextEditingController();
  final _simPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = YasserController();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _stressTimer?.cancel();
    _controller.dispose();
    _tabController.dispose();
    _simNameController.dispose();
    _simPasswordController.dispose();
    super.dispose();
  }

  void _runStressTest() {
    if (_stressTestRunning) {
      _stressTimer?.cancel();
      setState(() => _stressTestRunning = false);
      _controller.returnToIdle();
      return;
    }

    setState(() => _stressTestRunning = true);
    final testStates = [
      YasserAnimationState.waving,
      YasserAnimationState.coveringEyes,
      YasserAnimationState.peeking,
      YasserAnimationState.happy,
      YasserAnimationState.thinking,
      YasserAnimationState.celebrating,
      YasserAnimationState.lookingLeft,
      YasserAnimationState.lookingRight,
      YasserAnimationState.confused,
      YasserAnimationState.idle,
    ];

    int step = 0;
    _stressTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final s = testStates[step % testStates.length];
      _controller.engine.triggerState(
        s,
        customHoldDuration: const Duration(milliseconds: 200),
        reason: 'Stress Test rapid transition #$step',
      );
      step++;
      if (step > 40) {
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.touch_app), text: 'الحالات والأفعال'),
            Tab(icon: Icon(Icons.remove_red_eye), text: 'محاكاة الدخول'),
            Tab(icon: Icon(Icons.tune), text: 'تحكم المدخلات'),
            Tab(icon: Icon(Icons.analytics), text: 'التشخيص والذاكرة'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Live Character Preview Stage
          _buildStageHeader(),

          // Lab Controls Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActionButtonsTab(),
                _buildAuthSimulationTab(),
                _buildContinuousInputsTab(),
                _buildDiagnosticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Character Stage
              Expanded(
                child: Center(
                  child: Transform.scale(
                    scale: _characterScale,
                    child: YasserCharacter(
                      controller: _controller,
                      width: 170,
                      height: 210,
                    ),
                  ),
                ),
              ),

              // Status Summary Badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(
                    'الحالة: ${_controller.currentState.name}',
                    AppColors.primary,
                  ),
                  const SizedBox(height: 6),
                  _buildStatusChip(
                    'الأولوية: ${_controller.engine.currentPriority.name}',
                    Colors.indigo,
                  ),
                  const SizedBox(height: 6),
                  _buildStatusChip(
                    _controller.isRiveInitialized ? 'Rive Native شغال' : 'نمط 2.5D Fallback',
                    _controller.isRiveInitialized ? AppColors.success : Colors.amber.shade800,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Zoom Slider
          Row(
            children: [
              const Icon(Icons.zoom_out, size: 18, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: _characterScale,
                  min: 0.7,
                  max: 1.4,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _characterScale = v),
                ),
              ),
              const Icon(Icons.zoom_in, size: 18, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButtonsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('الأمان والخصوصية (Authentication Privacy)'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildTriggerButton(
              'تغطية العينين (Cover Eyes)',
              Icons.visibility_off,
              Colors.purple,
              () => _controller.coverEyes(),
            ),
            _buildTriggerButton(
              'استراق النظر (Peek)',
              Icons.remove_red_eye,
              Colors.deepPurple,
              () => _controller.peek(),
            ),
            _buildTriggerButton(
              'إنزال اليدين (Uncover)',
              Icons.pan_tool,
              Colors.blueGrey,
              () => _controller.uncoverEyes(),
            ),
          ],
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('التفاعل الاجتماعي والمقدمة (Social & Onboarding)'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildTriggerButton(
              'تحية ولوح (Wave)',
              Icons.waving_hand,
              Colors.amber.shade800,
              () => _controller.wave(),
            ),
            _buildTriggerButton(
              'احتفال وفرح (Celebrate)',
              Icons.celebration,
              Colors.green.shade700,
              () => _controller.celebrate(),
            ),
            _buildTriggerButton(
              'تفكير وذكاء (Think)',
              Icons.lightbulb_outline,
              Colors.orange.shade800,
              () => _controller.think(),
            ),
            _buildTriggerButton(
              'سكون طبيعي (Idle)',
              Icons.self_improvement,
              Colors.blue,
              () => _controller.returnToIdle(),
            ),
          ],
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('ردود فعل التحقق التعليمي (Validation Feedback)'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildTriggerButton(
              'إجابة صحيحة (Valid)',
              Icons.check_circle_outline,
              AppColors.success,
              () => _controller.reactToValidation(true),
            ),
            _buildTriggerButton(
              'حيرة لطيفة (Invalid / Confused)',
              Icons.help_outline,
              Colors.redAccent,
              () => _controller.reactToValidation(false),
            ),
          ],
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('اختبار التحمل والسرعة (Stress Testing)'),
        PrimaryButton(
          label: _stressTestRunning ? 'إيقاف اختبار التحمل' : 'بدء اختبار التحمل السريع (Rapid Stress Test)',
          icon: Icon(_stressTestRunning ? Icons.stop : Icons.flash_on, color: Colors.white),
          backgroundColor: _stressTestRunning ? Colors.red : Colors.deepOrange,
          onPressed: _runStressTest,
        ),
      ],
    );
  }

  Widget _buildAuthSimulationTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'محاكاة تفاعل ياسر مع حقول الدخول الحية:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),

        // Simulated Name / Email Field
        YasserTextField(
          label: 'اسم المستخدم أو البريد',
          hint: 'اكتب ولاحظ تركيز ياسر وانتباهه',
          controller: _simNameController,
          prefixIcon: const Icon(Icons.person_outline),
          onFocusChanged: (hasFocus) {
            if (hasFocus) {
              _controller.lookAtInput(normalizedX: 0.0, normalizedY: 0.3);
            } else {
              _controller.returnToIdle();
            }
          },
        ),

        const SizedBox(height: 20),

        // Simulated Password Field
        YasserTextField(
          label: 'كلمة المرور السرية',
          hint: 'لاحظ تغطية العينين واستراق النظر',
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

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'محاكاة نجاح الدخول',
                icon: const Icon(Icons.check, color: Colors.white),
                backgroundColor: Colors.green.shade600,
                onPressed: () => _controller.celebrate(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'محاكاة خطأ الدخول',
                icon: const Icon(Icons.close, color: Colors.white),
                backgroundColor: Colors.red.shade600,
                onPressed: () => _controller.reactToValidation(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContinuousInputsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'التحكم المستمر في النظر والرأس (Gaze & Attention):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 20),

        Text('الاتجاه الأفقي للعينين (X-Axis): ${_eyeX.toStringAsFixed(2)}'),
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

        const SizedBox(height: 16),

        Text('الاتجاه الرأسي للعينين (Y-Axis): ${_eyeY.toStringAsFixed(2)}'),
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

        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
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

  Widget _buildDiagnosticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('سجل أحداث المحرك الفوري (Event Log)'),
        Container(
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            itemCount: _controller.eventHistory.length,
            itemBuilder: (context, index) {
              final log = _controller.eventHistory[_controller.eventHistory.length - 1 - index];
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

        const SizedBox(height: 20),
        _buildSectionHeader('مصفوفة إمكانيات ريف المكتشفة (Capability Matrix)'),
        ...YasserAnimationCapabilities.matrix.map((cap) {
          Color tierColor = Colors.grey;
          switch (cap.tier) {
            case RiveSupportTier.verified:
              tierColor = Colors.green;
              break;
            case RiveSupportTier.availableRequiresTesting:
              tierColor = Colors.teal;
              break;
            case RiveSupportTier.partiallySupported:
              tierColor = Colors.amber.shade800;
              break;
            case RiveSupportTier.requiresPhase2Authoring:
              tierColor = Colors.deepOrange;
              break;
            case RiveSupportTier.unsupported:
              tierColor = Colors.red;
              break;
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.check_circle, color: tierColor, size: 24),
              title: Text(
                cap.featureName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'المعرف: ${cap.riveIdentifier ?? "غير محدد"}\n${cap.description}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cap.tier.name,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
