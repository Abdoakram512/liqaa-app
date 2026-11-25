import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rive/rive.dart' as rive;

import '../../../../core/animation/yasser/yasser_animation_capabilities.dart';
import '../../../../core/animation/yasser/yasser_animation_config.dart';
import '../../../../core/animation/yasser/yasser_rive_controller.dart';
import '../../../../core/theme/app_colors.dart';

/// Isolated Diagnostic & Testing Screen for Yasser Rive 0.14+ Integration.
///
/// Provides deep runtime telemetry, renderer toggling (Factory.rive vs
/// Factory.flutter), state machine input manipulation, and artboard validation
/// to isolate whether any anomalies stem from the asset or the Flutter framework.
class RiveDiagnosticView extends StatefulWidget {
  const RiveDiagnosticView({super.key});

  @override
  State<RiveDiagnosticView> createState() => _RiveDiagnosticViewState();
}

class _RiveDiagnosticViewState extends State<RiveDiagnosticView> {
  rive.File? _loadedFile;
  YasserRiveController? _widgetController;

  bool _isNativeInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  final List<String> _diagnosticLogs = [];

  bool _useRiveRenderer = false; // true = Factory.rive, false = Factory.flutter
  bool _passwordTypingValue = false;
  int _diagnosticRun = 0;

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  void _log(String message) {
    setState(() {
      _diagnosticLogs.insert(
        0,
        '[${DateTime.now().toIso8601String().substring(11, 19)}] $message',
      );
    });
  }

  Future<void> _runDiagnostic() async {
    final run = ++_diagnosticRun;
    final factory = _useRiveRenderer ? rive.Factory.rive : rive.Factory.flutter;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    rive.File? file;
    try {
      _log('Loading Rive asset with ${factory.runtimeType}…');
      if (!rive.RiveNative.isInitialized) {
        await rive.RiveNative.init();
      }
      if (!mounted || run != _diagnosticRun) return;
      _isNativeInitialized = rive.RiveNative.isInitialized;
      file = await rive.File.asset(
        YasserAnimationCapabilities.assetPath,
        riveFactory: factory,
      );
      if (!mounted || run != _diagnosticRun) return;
      if (file == null) throw StateError('Failed to decode the Rive asset');

      final controller = YasserRiveController(
        file,
        const YasserAnimationConfig(),
      );
      controller.setPasswordTyping(_passwordTypingValue);
      _widgetController?.dispose();
      _loadedFile?.dispose();
      _widgetController = controller;
      _loadedFile = file;
      file = null;
      _log(
        'Bound passwordTyping on ${YasserAnimationCapabilities.artboardName}.',
      );
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted || run != _diagnosticRun) return;
      _log('ERROR: $error');
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    } finally {
      file?.dispose();
    }
  }

  void _togglePasswordTyping(bool value) {
    _widgetController?.setPasswordTyping(value);
    setState(() => _passwordTypingValue = value);
    _log('passwordTyping updated to $value.');
  }

  void _switchRenderer(bool useRive) {
    if (_useRiveRenderer == useRive) return;
    setState(() {
      _useRiveRenderer = useRive;
    });
    _runDiagnostic();
  }

  @override
  void dispose() {
    _widgetController?.dispose();
    _loadedFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Rive 0.14+ Forensic Diagnostic'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rerun Diagnostic',
            onPressed: _runDiagnostic,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Character Preview Card
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? CircularProgressIndicator(color: AppColors.primary)
                      : _errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Rendering Exception Caught',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _widgetController != null
                      ? rive.RiveWidget(
                          controller: _widgetController!,
                          fit: rive.Fit.contain,
                          alignment: Alignment.center,
                        )
                      : const Text('No controller active'),
                ),
              ),

              const SizedBox(height: 16),

              // Telemetry Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    label: 'Runtime: Rive 0.14.11',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  _Badge(
                    label:
                        'RiveNative: ${_isNativeInitialized ? "Initialized" : "Pending"}',
                    icon: _isNativeInitialized
                        ? Icons.memory
                        : Icons.warning_amber,
                    color: _isNativeInitialized ? Colors.blue : Colors.orange,
                  ),
                  _Badge(
                    label:
                        'Renderer: ${_useRiveRenderer ? "Factory.rive (GPU)" : "Factory.flutter (Canvas)"}',
                    icon: Icons.speed,
                    color: _useRiveRenderer ? AppColors.primary : Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Interactive Control Panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Interactive Input Controls',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Password Privacy Toggle
                    SwitchListTile(
                      title: const Text('passwordTyping (Cover Eyes)'),
                      subtitle: const Text(
                        'Tests privacy arm elevation input in State Machine 1',
                      ),
                      value: _passwordTypingValue,
                      activeThumbColor: AppColors.primary,
                      onChanged: _isLoading ? null : _togglePasswordTyping,
                    ),

                    const Divider(),

                    // Renderer Selector
                    Row(
                      children: [
                        const Text(
                          'Active Renderer: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('Factory.rive'),
                          selected: _useRiveRenderer,
                          onSelected: (val) => _switchRenderer(true),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Factory.flutter'),
                          selected: !_useRiveRenderer,
                          onSelected: (val) => _switchRenderer(false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Diagnostic Log Output Box
              Container(
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.terminal,
                          color: Colors.greenAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Telemetry & Event Stream',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_diagnosticLogs.length} events',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _diagnosticLogs.length,
                        itemBuilder: (context, index) {
                          final log = _diagnosticLogs[index];
                          final isError = log.contains('ERROR');
                          final isSuccess = log.contains('SUCCESS');
                          return Text(
                            log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: isError
                                  ? Colors.redAccent
                                  : isSuccess
                                  ? Colors.greenAccent
                                  : const Color(0xFF94A3B8),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
