import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../animation/yasser/yasser_animation_capabilities.dart';
import '../animation/yasser/yasser_animation_mapper.dart';
import '../animation/yasser/yasser_animation_state.dart';
import '../animation/yasser/yasser_controller.dart';

/// Flagship unified character widget for Yasser (ياسر).
///
/// Features modern Rive 0.14+ runtime architecture with Factory.rive renderer,
/// FileLoader asset deduplication, RiveWidget, and RiveWidgetController.
/// Seamlessly falls back to high-resolution 2.5D character poses with native
/// Flutter breathing and micro-physics if runtime support is unavailable.
class YasserCharacter extends StatefulWidget {
  /// Global toggle allowing test environments or platforms lacking native
  /// dynamic libraries to enforce the 2.5D illustration fallback.
  static bool enableRiveRuntime = true;

  /// Shared static FileLoader ensuring `assets/rive/yasser.riv` is loaded and
  /// decoded once using the native Rive Renderer (`Factory.rive`).
  static rive.FileLoader? _sharedFileLoader;

  static rive.FileLoader get sharedFileLoader {
    return _sharedFileLoader ??= rive.FileLoader.fromAsset(
      YasserAnimationCapabilities.assetPath,
      riveFactory: rive.Factory.rive,
    );
  }

  /// Reset the shared file loader (useful for testing or reloading).
  static void resetSharedLoader() {
    _sharedFileLoader?.dispose();
    _sharedFileLoader = null;
  }

  final YasserController? controller;
  final YasserAnimationState? state;
  final double? width;
  final double? height;
  final Alignment alignment;
  final bool enableTapReaction;
  final VoidCallback? onTap;
  final bool showShadow;
  final String heroTag;

  const YasserCharacter({
    super.key,
    this.controller,
    this.state,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.enableTapReaction = true,
    this.onTap,
    this.showShadow = true,
    this.heroTag = 'yasser_character_hero',
  });

  @override
  State<YasserCharacter> createState() => _YasserCharacterState();
}

class _YasserCharacterState extends State<YasserCharacter>
    with SingleTickerProviderStateMixin {
  late YasserController _controller;
  bool _ownsController = false;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  rive.RiveWidgetController? _riveWidgetController;
  bool _isLoadingRive = false;
  bool _hasRiveError = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = YasserController();
      _ownsController = true;
    }

    if (widget.state != null) {
      _controller.engine.triggerState(widget.state!);
    }

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    _initRiveController();
  }

  Future<void> _initRiveController() async {
    if (!YasserCharacter.enableRiveRuntime) return;
    if (_riveWidgetController != null) return;

    if (mounted) {
      setState(() {
        _isLoadingRive = true;
        _hasRiveError = false;
      });
    }

    try {
      if (!rive.RiveNative.isInitialized) {
        await rive.RiveNative.init();
      }

      final file = await YasserCharacter.sharedFileLoader.file();
      if (!mounted) return;

      final controller = rive.RiveWidgetController(
        file,
        artboardSelector: rive.ArtboardNamed(_controller.config.artboardName),
        stateMachineSelector:
            rive.StateMachineNamed(_controller.config.stateMachineName),
      );

      _riveWidgetController = controller;
      _controller.attachWidgetController(controller);

      if (mounted) {
        setState(() {
          _isLoadingRive = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[YasserCharacter] Rive loading note (using 2.5D fallback): $e');
      setState(() {
        _isLoadingRive = false;
        _hasRiveError = true;
      });
    }
  }

  @override
  void didUpdateWidget(covariant YasserCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != null && widget.state != oldWidget.state) {
      _controller.engine.triggerState(widget.state!);
    }
    if (YasserCharacter.enableRiveRuntime &&
        _riveWidgetController == null &&
        !_hasRiveError &&
        !_isLoadingRive) {
      _initRiveController();
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _controller.detachWidgetController();
    _riveWidgetController?.dispose();
    _riveWidgetController = null;
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enableTapReaction) return;
    _controller.handleTap();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final double targetWidth = widget.width ?? 260.0;
    final double targetHeight = widget.height ?? 340.0;

    return ValueListenableBuilder<YasserStateMapping>(
      valueListenable: _controller.stateNotifier,
      builder: (context, mapping, child) {
        return GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: targetWidth,
            height: targetHeight,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // Organic Ground Shadow
                if (widget.showShadow)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: targetWidth * 0.55,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(targetWidth * 0.55, 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E293B).withOpacity(0.18),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Character Render Layer (Rive or Fallback)
                Positioned.fill(
                  child: Align(
                    alignment: widget.alignment,
                    child: _buildCharacterContent(mapping),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacterContent(YasserStateMapping mapping) {
    // If Rive runtime is disabled, failed, or still loading first frame, show 2.5D fallback
    if (!YasserCharacter.enableRiveRuntime ||
        _hasRiveError ||
        _riveWidgetController == null) {
      return _build2DFallback(mapping);
    }

    // Render native Rive 0.14+ widget using Factory.rive
    return rive.RiveWidget(
      controller: _riveWidgetController!,
      fit: rive.Fit.contain,
      alignment: widget.alignment,
    );
  }

  Widget _build2DFallback(YasserStateMapping mapping) {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _breathingAnimation.value,
          child: child,
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInQuad,
        child: Image.asset(
          mapping.fallbackAssetPath,
          key: ValueKey<String>(mapping.fallbackAssetPath),
          fit: BoxFit.contain,
          alignment: widget.alignment,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/yasser/original/yasser_standing.png',
              fit: BoxFit.contain,
            );
          },
        ),
      ),
    );
  }
}
