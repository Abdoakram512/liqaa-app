import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

/// Reusable celebration overlay with gentle, playful confetti physics.
class ConfettiCelebrationOverlay extends StatefulWidget {
  final Widget child;
  final ConfettiController? confettiController;

  const ConfettiCelebrationOverlay({
    super.key,
    required this.child,
    this.confettiController,
  });

  @override
  State<ConfettiCelebrationOverlay> createState() =>
      _ConfettiCelebrationOverlayState();
}

class _ConfettiCelebrationOverlayState
    extends State<ConfettiCelebrationOverlay> {
  late ConfettiController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.confettiController != null) {
      _controller = widget.confettiController!;
    } else {
      _controller = ConfettiController(duration: const Duration(seconds: 2));
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Top center celebratory emitter
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: pi / 2, // downwards
            maxBlastForce: 8,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 25,
            gravity: 0.2,
            colors: const [
              Color(0xFFF59E0B), // Amber
              Color(0xFF38BDF8), // Sky Blue
              Color(0xFF10B981), // Emerald
              Color(0xFFF43F5E), // Coral
              Color(0xFFA855F7), // Purple
            ],
          ),
        ),
      ],
    );
  }
}
