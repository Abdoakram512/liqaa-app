import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Handcrafted Canvas vector illustrations for Yasser's 28-word Egyptian Arabic
/// dictionary and world collectibles (zero emojis, responsive geometry,
/// crisp tactile outlines, and strict `shouldRepaint` discipline).
class IllustratedVocabularyWidget extends StatelessWidget {
  final String objectKey;
  final String semanticLabel;
  final double size;
  final Color? accentColor;
  final double bounceValue;

  const IllustratedVocabularyWidget({
    super.key,
    required this.objectKey,
    this.semanticLabel = '',
    this.size = 76,
    this.accentColor,
    this.bounceValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel.isNotEmpty ? semanticLabel : objectKey,
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: IllustratedObjectPainter(
              objectKey: objectKey.toLowerCase(),
              accentColor: accentColor ?? AppColors.primary,
              phase: bounceValue,
            ),
          ),
        ),
      ),
    );
  }
}

class IllustratedObjectPainter extends CustomPainter {
  final String objectKey;
  final Color accentColor;
  final double phase;

  const IllustratedObjectPainter({
    required this.objectKey,
    required this.accentColor,
    this.phase = 0.0,
  });

  static const Color _ink = Color(0xFF273141);

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  Paint _stroke(double width, [Color color = _ink]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double s = math.min(size.width, size.height);
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double u = s / 100.0;
    final double sw = math.max(1.8, 2.4 * u);

    canvas.save();
    canvas.translate(cx - 50 * u, cy - 50 * u);
    canvas.scale(u, u);

    if (_matches(['kora', 'ball', 'كورة'])) {
      _drawBall(canvas, sw);
    } else if (_matches(['samaka', 'fish', 'dolphin', 'سمكة'])) {
      _drawFish(canvas, sw);
    } else if (_matches(['batta', 'duck', 'بطة'])) {
      _drawDuck(canvas, sw);
    } else if (_matches(['2etta', 'cat', 'قطة'])) {
      _drawCat(canvas, sw);
    } else if (_matches(['arnab', 'bunny', 'rabbit', 'أرنب'])) {
      _drawRabbit(canvas, sw);
    } else if (_matches(['kalb', 'dog', 'كلب'])) {
      _drawDog(canvas, sw);
    } else if (_matches(['shams', 'sun', 'شمس'])) {
      _drawSun(canvas, sw);
    } else if (_matches(['tofa7a', 'apple', 'تفاحة'])) {
      _drawApple(canvas, sw);
    } else if (_matches(['moza', 'banana', 'موزة'])) {
      _drawBanana(canvas, sw);
    } else if (_matches(['tayara', 'plane', 'طيارة'])) {
      _drawAirplane(canvas, sw);
    } else if (_matches(['3arabeya', 'car', 'عربية'])) {
      _drawCar(canvas, sw);
    } else if (_matches(['beit', 'house', 'بيت'])) {
      _drawHouse(canvas, sw);
    } else if (_matches(['bab', 'door', 'باب'])) {
      _drawDoor(canvas, sw);
    } else if (_matches(['ketab', 'book', 'كتاب'])) {
      _drawBook(canvas, sw);
    } else if (_matches(['alam', 'pen', 'قلم'])) {
      _drawPencil(canvas, sw);
    } else if (_matches(['farasha', 'butterfly', 'bee', 'فراشة'])) {
      _drawButterfly(canvas, sw);
    } else if (_matches(['flower', 'وردة', 'زهرة'])) {
      _drawFlower(canvas, sw, accentColor);
    } else if (_matches(['tree', 'forest', 'شجرة'])) {
      _drawTree(canvas, sw);
    } else if (_matches([
      'gamal',
      'camel',
      'جمل',
      '7esan',
      'horse',
      'حصان',
      'zarafa',
      'giraffe',
      'زرافة',
    ])) {
      _drawGiraffeOrTallAnimal(canvas, sw);
    } else if (_matches(['feel', 'elephant', 'فيل'])) {
      _drawElephant(canvas, sw);
    } else if (_matches(['ta3lab', 'fox', 'تعلب'])) {
      _drawFox(canvas, sw);
    } else if (_matches(['hodhod', 'owl', 'bird', 'هدهد'])) {
      _drawBird(canvas, sw);
    } else if (_matches(['3ein', 'eye', 'عين'])) {
      _drawEye(canvas, sw);
    } else if (_matches(['eid', 'hand', 'إيد'])) {
      _drawHand(canvas, sw);
    } else if (_matches(['regl', 'leg', 'shoe', 'رجل'])) {
      _drawShoe(canvas, sw);
    } else if (_matches(['walad', 'boy', 'bent', 'girl', 'ولد', 'بنت'])) {
      _drawFriendlyFace(canvas, sw, _matches(['bent', 'girl', 'بنت']));
    } else if (_matches(['dahab', 'gold', 'star', 'badge', 'دهب'])) {
      _drawStarMedallion(canvas, sw, accentColor);
    } else {
      _drawStarMedallion(canvas, sw, accentColor);
    }

    canvas.restore();
  }

  bool _matches(List<String> keys) {
    for (final k in keys) {
      if (objectKey.contains(k)) return true;
    }
    return false;
  }

  void _drawBall(Canvas canvas, double sw) {
    const center = Offset(50, 52);
    canvas.drawCircle(center, 34, _fill(Colors.white));
    // Orange & indigo playful panels clipped inside the ball
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: 34)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 34)
        ..lineTo(66, 46)
        ..lineTo(60, 64)
        ..lineTo(40, 64)
        ..lineTo(34, 46)
        ..close(),
      _fill(AppColors.primary),
    );
    canvas.drawCircle(const Offset(24, 30), 12, _fill(AppColors.secondary));
    canvas.drawCircle(const Offset(77, 32), 11, _fill(AppColors.accentSky));
    canvas.drawCircle(const Offset(50, 84), 11, _fill(AppColors.accentMint));
    canvas.restore();
    canvas.drawCircle(center, 34, _stroke(sw));
    canvas.drawArc(
      const Rect.fromLTWH(28, 28, 18, 12),
      -2.6,
      1.3,
      false,
      _stroke(sw * 0.9, Colors.white.withValues(alpha: 0.85)),
    );
  }

  void _drawFish(Canvas canvas, double sw) {
    // Water ripples
    canvas.drawArc(
      const Rect.fromLTWH(16, 74, 68, 12),
      0.2,
      2.7,
      false,
      _stroke(sw * 0.8, AppColors.accentSky.withValues(alpha: 0.5)),
    );
    // Tail fin
    final tail = Path()
      ..moveTo(70, 50)
      ..lineTo(89, 32)
      ..quadraticBezierTo(84, 50, 89, 68)
      ..close();
    canvas.drawPath(tail, _fill(AppColors.primary));
    canvas.drawPath(tail, _stroke(sw));
    // Top fin
    final topFin = Path()
      ..moveTo(38, 30)
      ..quadraticBezierTo(48, 14, 60, 32)
      ..close();
    canvas.drawPath(topFin, _fill(AppColors.primaryLight));
    canvas.drawPath(topFin, _stroke(sw));
    // Body oval
    final bodyRect = const Rect.fromLTWH(14, 29, 60, 42);
    canvas.drawOval(bodyRect, _fill(AppColors.accentMint));
    canvas.drawOval(bodyRect, _stroke(sw));
    // Cute eye & smile
    canvas.drawCircle(const Offset(29, 44), 6.5, _fill(Colors.white));
    canvas.drawCircle(const Offset(28, 44), 3.4, _fill(_ink));
    canvas.drawArc(
      const Rect.fromLTWH(18, 48, 14, 10),
      0.1,
      1.4,
      false,
      _stroke(sw * 0.8),
    );
    // Bubbles
    canvas.drawCircle(const Offset(11, 24), 4, _fill(AppColors.accentSkySoft));
    canvas.drawCircle(
      const Offset(11, 24),
      4,
      _stroke(sw * 0.65, AppColors.accentSky),
    );
    canvas.drawCircle(
      const Offset(17, 14),
      2.8,
      _fill(AppColors.accentSkySoft),
    );
  }

  void _drawDuck(Canvas canvas, double sw) {
    // Body
    final body = Path()
      ..moveTo(22, 60)
      ..quadraticBezierTo(22, 82, 54, 82)
      ..quadraticBezierTo(84, 82, 86, 54)
      ..quadraticBezierTo(76, 56, 62, 52)
      ..quadraticBezierTo(48, 44, 48, 32)
      ..arcTo(const Rect.fromLTWH(18, 18, 32, 30), -0.3, -4.0, false)
      ..close();
    canvas.drawPath(body, _fill(const Color(0xFFFFD44D)));
    canvas.drawPath(body, _stroke(sw));
    // Wing
    canvas.drawArc(
      const Rect.fromLTWH(44, 54, 24, 16),
      0.0,
      3.14,
      false,
      _stroke(sw * 0.85, AppColors.primaryDark),
    );
    // Orange beak
    final beak = Path()
      ..moveTo(18, 33)
      ..quadraticBezierTo(6, 36, 18, 42)
      ..close();
    canvas.drawPath(beak, _fill(AppColors.primary));
    canvas.drawPath(beak, _stroke(sw * 0.9));
    // Eye
    canvas.drawCircle(const Offset(28, 30), 3.5, _fill(_ink));
    canvas.drawCircle(const Offset(27, 29), 1.2, _fill(Colors.white));
  }

  void _drawCat(Canvas canvas, double sw) {
    // Ears
    final leftEar = Path()
      ..moveTo(24, 42)
      ..lineTo(20, 14)
      ..lineTo(42, 28)
      ..close();
    final rightEar = Path()
      ..moveTo(76, 42)
      ..lineTo(80, 14)
      ..lineTo(58, 28)
      ..close();
    canvas.drawPath(leftEar, _fill(AppColors.primaryLight));
    canvas.drawPath(rightEar, _fill(AppColors.primaryLight));
    canvas.drawPath(leftEar, _stroke(sw));
    canvas.drawPath(rightEar, _stroke(sw));
    // Face
    const head = Rect.fromLTWH(20, 24, 60, 54);
    canvas.drawOval(head, _fill(const Color(0xFFFFE0B2)));
    canvas.drawOval(head, _stroke(sw));
    // Eyes, nose & whiskers
    canvas.drawCircle(const Offset(39, 46), 4, _fill(_ink));
    canvas.drawCircle(const Offset(61, 46), 4, _fill(_ink));
    canvas.drawCircle(const Offset(50, 55), 3.6, _fill(AppColors.accentCoral));
    canvas.drawLine(
      const Offset(10, 52),
      const Offset(27, 54),
      _stroke(sw * 0.7),
    );
    canvas.drawLine(
      const Offset(10, 60),
      const Offset(27, 58),
      _stroke(sw * 0.7),
    );
    canvas.drawLine(
      const Offset(90, 52),
      const Offset(73, 54),
      _stroke(sw * 0.7),
    );
    canvas.drawLine(
      const Offset(90, 60),
      const Offset(73, 58),
      _stroke(sw * 0.7),
    );
  }

  void _drawRabbit(Canvas canvas, double sw) {
    final earL = RRect.fromRectAndRadius(
      const Rect.fromLTWH(31, 8, 13, 36),
      const Radius.circular(8),
    );
    final earR = RRect.fromRectAndRadius(
      const Rect.fromLTWH(56, 8, 13, 36),
      const Radius.circular(8),
    );
    canvas.drawRRect(earL, _fill(Colors.white));
    canvas.drawRRect(earR, _fill(Colors.white));
    canvas.drawRRect(earL, _stroke(sw));
    canvas.drawRRect(earR, _stroke(sw));
    canvas.drawOval(
      const Rect.fromLTWH(35, 14, 5, 22),
      _fill(AppColors.accentCoralSoft),
    );
    canvas.drawOval(
      const Rect.fromLTWH(60, 14, 5, 22),
      _fill(AppColors.accentCoralSoft),
    );
    const face = Rect.fromLTWH(23, 34, 54, 48);
    canvas.drawOval(face, _fill(Colors.white));
    canvas.drawOval(face, _stroke(sw));
    canvas.drawCircle(const Offset(40, 53), 3.6, _fill(_ink));
    canvas.drawCircle(const Offset(60, 53), 3.6, _fill(_ink));
    canvas.drawOval(
      const Rect.fromLTWH(46, 59, 8, 6),
      _fill(AppColors.accentCoral),
    );
  }

  void _drawDog(Canvas canvas, double sw) {
    final earL = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 30, 15, 34),
      const Radius.circular(8),
    );
    final earR = RRect.fromRectAndRadius(
      const Rect.fromLTWH(69, 30, 15, 34),
      const Radius.circular(8),
    );
    canvas.drawRRect(earL, _fill(AppColors.worldForestAccent));
    canvas.drawRRect(earR, _fill(AppColors.worldForestAccent));
    canvas.drawRRect(earL, _stroke(sw));
    canvas.drawRRect(earR, _stroke(sw));
    const head = Rect.fromLTWH(24, 24, 52, 52);
    canvas.drawOval(head, _fill(const Color(0xFFFFD8A8)));
    canvas.drawOval(head, _stroke(sw));
    canvas.drawCircle(const Offset(40, 45), 3.8, _fill(_ink));
    canvas.drawCircle(const Offset(60, 45), 3.8, _fill(_ink));
    canvas.drawOval(const Rect.fromLTWH(44, 53, 12, 9), _fill(_ink));
  }

  void _drawSun(Canvas canvas, double sw) {
    const center = Offset(50, 50);
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + phase * 0.4;
      final p1 = Offset(50 + math.cos(a) * 28, 50 + math.sin(a) * 28);
      final p2 = Offset(50 + math.cos(a) * 40, 50 + math.sin(a) * 40);
      canvas.drawLine(p1, p2, _stroke(sw * 1.35, AppColors.primary));
    }
    canvas.drawCircle(center, 22, _fill(const Color(0xFFFFD44D)));
    canvas.drawCircle(center, 22, _stroke(sw, AppColors.primaryDark));
    canvas.drawCircle(const Offset(43, 46), 2.6, _fill(_ink));
    canvas.drawCircle(const Offset(57, 46), 2.6, _fill(_ink));
    canvas.drawArc(
      const Rect.fromLTWH(42, 48, 16, 12),
      0.2,
      2.7,
      false,
      _stroke(sw * 0.85),
    );
  }

  void _drawApple(Canvas canvas, double sw) {
    final stem = Path()
      ..moveTo(50, 26)
      ..quadraticBezierTo(52, 14, 58, 12);
    canvas.drawPath(stem, _stroke(sw, const Color(0xFF7B4B2A)));
    final leaf = Path()
      ..moveTo(52, 20)
      ..quadraticBezierTo(70, 10, 72, 24)
      ..quadraticBezierTo(58, 28, 52, 20);
    canvas.drawPath(leaf, _fill(AppColors.accentMint));
    canvas.drawPath(leaf, _stroke(sw * 0.8));
    final apple = Path()
      ..moveTo(50, 30)
      ..cubicTo(22, 22, 16, 62, 36, 80)
      ..quadraticBezierTo(50, 86, 50, 80)
      ..quadraticBezierTo(50, 86, 64, 80)
      ..cubicTo(84, 62, 78, 22, 50, 30)
      ..close();
    canvas.drawPath(apple, _fill(AppColors.accentCoral));
    canvas.drawPath(apple, _stroke(sw));
    canvas.drawArc(
      const Rect.fromLTWH(28, 38, 12, 20),
      2.4,
      1.3,
      false,
      _stroke(sw * 0.8, Colors.white.withValues(alpha: 0.75)),
    );
  }

  void _drawBanana(Canvas canvas, double sw) {
    final p = Path()
      ..moveTo(22, 66)
      ..quadraticBezierTo(58, 86, 82, 26)
      ..quadraticBezierTo(84, 18, 76, 18)
      ..quadraticBezierTo(62, 62, 18, 56)
      ..close();
    canvas.drawPath(p, _fill(const Color(0xFFFFD84D)));
    canvas.drawPath(p, _stroke(sw));
  }

  void _drawAirplane(Canvas canvas, double sw) {
    final wing = Path()
      ..moveTo(34, 48)
      ..lineTo(54, 16)
      ..lineTo(66, 18)
      ..lineTo(56, 48)
      ..close();
    final lowWing = Path()
      ..moveTo(42, 54)
      ..lineTo(56, 82)
      ..lineTo(66, 80)
      ..lineTo(58, 54)
      ..close();
    canvas.drawPath(wing, _fill(AppColors.accentSky));
    canvas.drawPath(wing, _stroke(sw));
    canvas.drawPath(lowWing, _fill(AppColors.accentSky));
    canvas.drawPath(lowWing, _stroke(sw));
    final fuselage = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 42, 68, 18),
      const Radius.circular(9),
    );
    canvas.drawRRect(fuselage, _fill(Colors.white));
    canvas.drawRRect(fuselage, _stroke(sw));
    canvas.drawCircle(const Offset(36, 51), 3.2, _fill(AppColors.primary));
    canvas.drawCircle(const Offset(48, 51), 3.2, _fill(AppColors.primary));
    canvas.drawCircle(const Offset(60, 51), 3.2, _fill(AppColors.primary));
  }

  void _drawCar(Canvas canvas, double sw) {
    final roof = Path()
      ..moveTo(28, 46)
      ..lineTo(38, 28)
      ..lineTo(66, 28)
      ..lineTo(76, 46)
      ..close();
    canvas.drawPath(roof, _fill(AppColors.accentSkySoft));
    canvas.drawPath(roof, _stroke(sw));
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 46, 72, 24),
      const Radius.circular(10),
    );
    canvas.drawRRect(body, _fill(AppColors.primary));
    canvas.drawRRect(body, _stroke(sw));
    for (final x in [30.0, 70.0]) {
      canvas.drawCircle(Offset(x, 72), 10, _fill(_ink));
      canvas.drawCircle(Offset(x, 72), 4.5, _fill(Colors.white));
    }
  }

  void _drawHouse(Canvas canvas, double sw) {
    final walls = RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 44, 56, 40),
      const Radius.circular(6),
    );
    canvas.drawRRect(walls, _fill(const Color(0xFFFFF4DC)));
    canvas.drawRRect(walls, _stroke(sw));
    final roof = Path()
      ..moveTo(14, 46)
      ..lineTo(50, 16)
      ..lineTo(86, 46)
      ..close();
    canvas.drawPath(roof, _fill(AppColors.accentCoral));
    canvas.drawPath(roof, _stroke(sw));
    final door = RRect.fromRectAndCorners(
      const Rect.fromLTWH(41, 56, 18, 28),
      topLeft: const Radius.circular(9),
      topRight: const Radius.circular(9),
    );
    canvas.drawRRect(door, _fill(AppColors.primary));
    canvas.drawRRect(door, _stroke(sw));
  }

  void _drawDoor(Canvas canvas, double sw) {
    final frame = RRect.fromRectAndCorners(
      const Rect.fromLTWH(28, 16, 44, 70),
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
    );
    canvas.drawRRect(frame, _fill(AppColors.primaryDark));
    canvas.drawRRect(frame, _stroke(sw));
    canvas.drawCircle(const Offset(62, 54), 4, _fill(AppColors.accentGoldSoft));
  }

  void _drawBook(Canvas canvas, double sw) {
    final left = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 24, 34, 52),
      const Radius.circular(6),
    );
    final right = RRect.fromRectAndRadius(
      const Rect.fromLTWH(50, 24, 34, 52),
      const Radius.circular(6),
    );
    canvas.drawRRect(left, _fill(Colors.white));
    canvas.drawRRect(right, _fill(AppColors.background));
    canvas.drawRRect(left, _stroke(sw));
    canvas.drawRRect(right, _stroke(sw));
    canvas.drawLine(
      const Offset(24, 38),
      const Offset(42, 38),
      _stroke(sw * 0.75, AppColors.secondary),
    );
    canvas.drawLine(
      const Offset(58, 38),
      const Offset(76, 38),
      _stroke(sw * 0.75, AppColors.primary),
    );
    canvas.drawLine(
      const Offset(58, 48),
      const Offset(74, 48),
      _stroke(sw * 0.75, AppColors.primary),
    );
  }

  void _drawPencil(Canvas canvas, double sw) {
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(-0.65);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-30, -8, 48, 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, _fill(AppColors.primary));
    canvas.drawRRect(body, _stroke(sw));
    final tip = Path()
      ..moveTo(18, -8)
      ..lineTo(34, 0)
      ..lineTo(18, 8)
      ..close();
    canvas.drawPath(tip, _fill(const Color(0xFFFFE0B2)));
    canvas.drawPath(tip, _stroke(sw));
    canvas.restore();
  }

  void _drawButterfly(Canvas canvas, double sw) {
    canvas.drawOval(
      const Rect.fromLTWH(18, 24, 28, 30),
      _fill(AppColors.secondaryLight),
    );
    canvas.drawOval(
      const Rect.fromLTWH(54, 24, 28, 30),
      _fill(AppColors.secondaryLight),
    );
    canvas.drawOval(
      const Rect.fromLTWH(24, 50, 22, 24),
      _fill(AppColors.primaryLight),
    );
    canvas.drawOval(
      const Rect.fromLTWH(54, 50, 22, 24),
      _fill(AppColors.primaryLight),
    );
    canvas.drawOval(const Rect.fromLTWH(18, 24, 28, 30), _stroke(sw));
    canvas.drawOval(const Rect.fromLTWH(54, 24, 28, 30), _stroke(sw));
    canvas.drawOval(const Rect.fromLTWH(24, 50, 22, 24), _stroke(sw));
    canvas.drawOval(const Rect.fromLTWH(54, 50, 22, 24), _stroke(sw));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(46, 26, 8, 48),
        const Radius.circular(4),
      ),
      _fill(_ink),
    );
  }

  void _drawFlower(Canvas canvas, double sw, Color petalColor) {
    canvas.drawLine(
      const Offset(50, 52),
      const Offset(50, 86),
      _stroke(sw * 1.2, AppColors.accentMintDark),
    );
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final c = Offset(50 + math.cos(a) * 18, 42 + math.sin(a) * 18);
      canvas.drawCircle(c, 11, _fill(petalColor));
      canvas.drawCircle(c, 11, _stroke(sw * 0.8));
    }
    canvas.drawCircle(const Offset(50, 42), 11, _fill(const Color(0xFFFFD44D)));
    canvas.drawCircle(const Offset(50, 42), 11, _stroke(sw));
  }

  void _drawTree(Canvas canvas, double sw) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(43, 56, 14, 30),
        const Radius.circular(4),
      ),
      _fill(const Color(0xFF9C6644)),
    );
    canvas.drawCircle(const Offset(50, 40), 22, _fill(AppColors.accentMint));
    canvas.drawCircle(const Offset(34, 48), 16, _fill(AppColors.accentMint));
    canvas.drawCircle(const Offset(66, 48), 16, _fill(AppColors.accentMint));
    canvas.drawCircle(const Offset(50, 40), 22, _stroke(sw));
  }

  void _drawGiraffeOrTallAnimal(Canvas canvas, double sw) {
    final neck = RRect.fromRectAndRadius(
      const Rect.fromLTWH(41, 28, 16, 48),
      const Radius.circular(8),
    );
    canvas.drawRRect(neck, _fill(const Color(0xFFFFCA62)));
    canvas.drawRRect(neck, _stroke(sw));
    canvas.drawOval(
      const Rect.fromLTWH(34, 18, 30, 22),
      _fill(const Color(0xFFFFCA62)),
    );
    canvas.drawOval(const Rect.fromLTWH(34, 18, 30, 22), _stroke(sw));
    canvas.drawCircle(const Offset(45, 28), 3, _fill(_ink));
    canvas.drawCircle(const Offset(56, 28), 3, _fill(_ink));
    canvas.drawCircle(
      const Offset(49, 54),
      4,
      _fill(AppColors.worldForestAccent),
    );
    canvas.drawCircle(
      const Offset(47, 68),
      3.5,
      _fill(AppColors.worldForestAccent),
    );
  }

  void _drawElephant(Canvas canvas, double sw) {
    canvas.drawOval(
      const Rect.fromLTWH(16, 28, 22, 34),
      _fill(const Color(0xFFB5C7D9)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(62, 28, 22, 34),
      _fill(const Color(0xFFB5C7D9)),
    );
    canvas.drawOval(const Rect.fromLTWH(16, 28, 22, 34), _stroke(sw));
    canvas.drawOval(const Rect.fromLTWH(62, 28, 22, 34), _stroke(sw));
    canvas.drawCircle(const Offset(50, 46), 22, _fill(const Color(0xFFCFE0F0)));
    canvas.drawCircle(const Offset(50, 46), 22, _stroke(sw));
    final trunk = Path()
      ..moveTo(46, 52)
      ..quadraticBezierTo(44, 78, 58, 76);
    canvas.drawPath(trunk, _stroke(sw * 2.2, const Color(0xFF9EB4CA)));
    canvas.drawCircle(const Offset(42, 42), 3, _fill(_ink));
    canvas.drawCircle(const Offset(58, 42), 3, _fill(_ink));
  }

  void _drawFox(Canvas canvas, double sw) {
    final earL = Path()
      ..moveTo(24, 42)
      ..lineTo(22, 16)
      ..lineTo(42, 30)
      ..close();
    final earR = Path()
      ..moveTo(76, 42)
      ..lineTo(78, 16)
      ..lineTo(58, 30)
      ..close();
    canvas.drawPath(earL, _fill(AppColors.accentCoral));
    canvas.drawPath(earR, _fill(AppColors.accentCoral));
    canvas.drawPath(earL, _stroke(sw));
    canvas.drawPath(earR, _stroke(sw));
    final head = Path()
      ..moveTo(22, 40)
      ..quadraticBezierTo(50, 22, 78, 40)
      ..lineTo(50, 78)
      ..close();
    canvas.drawPath(head, _fill(AppColors.primary));
    canvas.drawPath(head, _stroke(sw));
    canvas.drawCircle(const Offset(40, 47), 3.4, _fill(_ink));
    canvas.drawCircle(const Offset(60, 47), 3.4, _fill(_ink));
    canvas.drawCircle(const Offset(50, 74), 4, _fill(_ink));
  }

  void _drawBird(Canvas canvas, double sw) {
    canvas.drawCircle(const Offset(50, 52), 26, _fill(AppColors.primary));
    canvas.drawCircle(const Offset(50, 52), 26, _stroke(sw));
    canvas.drawCircle(const Offset(40, 46), 6, _fill(Colors.white));
    canvas.drawCircle(const Offset(60, 46), 6, _fill(Colors.white));
    canvas.drawCircle(const Offset(40, 46), 3, _fill(_ink));
    canvas.drawCircle(const Offset(60, 46), 3, _fill(_ink));
    final beak = Path()
      ..moveTo(45, 53)
      ..lineTo(55, 53)
      ..lineTo(50, 62)
      ..close();
    canvas.drawPath(beak, _fill(const Color(0xFFFFD44D)));
    canvas.drawPath(beak, _stroke(sw * 0.8));
  }

  void _drawEye(Canvas canvas, double sw) {
    final eye = Path()
      ..moveTo(14, 50)
      ..quadraticBezierTo(50, 20, 86, 50)
      ..quadraticBezierTo(50, 80, 14, 50)
      ..close();
    canvas.drawPath(eye, _fill(Colors.white));
    canvas.drawPath(eye, _stroke(sw));
    canvas.drawCircle(const Offset(50, 50), 14, _fill(AppColors.accentSky));
    canvas.drawCircle(const Offset(50, 50), 7, _fill(_ink));
    canvas.drawCircle(const Offset(46, 46), 3, _fill(Colors.white));
  }

  void _drawHand(Canvas canvas, double sw) {
    final palm = RRect.fromRectAndRadius(
      const Rect.fromLTWH(32, 42, 36, 38),
      const Radius.circular(14),
    );
    canvas.drawRRect(palm, _fill(const Color(0xFFFFD2A6)));
    canvas.drawRRect(palm, _stroke(sw));
    for (final x in [35.0, 44.0, 53.0, 62.0]) {
      final f = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3, 20, 7, 28),
        const Radius.circular(4),
      );
      canvas.drawRRect(f, _fill(const Color(0xFFFFD2A6)));
      canvas.drawRRect(f, _stroke(sw * 0.85));
    }
  }

  void _drawShoe(Canvas canvas, double sw) {
    final sole = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 60, 64, 14),
      const Radius.circular(6),
    );
    final upper = Path()
      ..moveTo(22, 60)
      ..lineTo(28, 34)
      ..lineTo(52, 42)
      ..quadraticBezierTo(78, 44, 78, 60)
      ..close();
    canvas.drawPath(upper, _fill(AppColors.secondary));
    canvas.drawPath(upper, _stroke(sw));
    canvas.drawRRect(sole, _fill(Colors.white));
    canvas.drawRRect(sole, _stroke(sw));
  }

  void _drawFriendlyFace(Canvas canvas, double sw, bool withBow) {
    canvas.drawCircle(const Offset(50, 52), 26, _fill(const Color(0xFFFFD8B4)));
    canvas.drawCircle(const Offset(50, 52), 26, _stroke(sw));
    canvas.drawCircle(const Offset(41, 48), 3.4, _fill(_ink));
    canvas.drawCircle(const Offset(59, 48), 3.4, _fill(_ink));
    canvas.drawArc(
      const Rect.fromLTWH(40, 52, 20, 14),
      0.2,
      2.7,
      false,
      _stroke(sw * 0.85),
    );
    if (withBow) {
      canvas.drawCircle(const Offset(68, 28), 6, _fill(AppColors.accentRose));
      canvas.drawCircle(const Offset(76, 32), 5, _fill(AppColors.accentRose));
    }
  }

  void _drawStarMedallion(Canvas canvas, double sw, Color color) {
    final star = Path();
    const cx = 50.0;
    const cy = 50.0;
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? 34.0 : 15.0;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(cx + math.cos(angle) * r, cy + math.sin(angle) * r);
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(star, _fill(color));
    canvas.drawPath(star, _stroke(sw));
    canvas.drawCircle(
      const Offset(cx, cy),
      8,
      _fill(Colors.white.withValues(alpha: 0.7)),
    );
  }

  @override
  bool shouldRepaint(covariant IllustratedObjectPainter oldDelegate) {
    return oldDelegate.objectKey != objectKey ||
        oldDelegate.accentColor != accentColor ||
        (oldDelegate.phase - phase).abs() > 0.01;
  }
}
