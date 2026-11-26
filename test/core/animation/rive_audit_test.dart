import 'dart:io' as io;
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Verify yasser.riv asset exists and matches known binary properties',
    () async {
      final file = io.File(YasserAnimationCapabilities.assetPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'assets/rive/yasser.riv must exist',
      );

      final bytes = await file.readAsBytes();
      expect(bytes.length, equals(YasserAnimationCapabilities.assetByteSize));

      // Verify RIVE signature header
      expect(bytes[0], equals(0x52)); // 'R'
      expect(bytes[1], equals(0x49)); // 'I'
      expect(bytes[2], equals(0x56)); // 'V'
      expect(bytes[3], equals(0x45)); // 'E'

      // Verify format major version 7, minor version 5
      expect(bytes[4], equals(7));
      expect(bytes[5], equals(5));
    },
  );
}
