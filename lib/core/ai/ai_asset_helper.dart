import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Manages extraction of bundled AI model assets to the local filesystem for native C/FFI consumption.
class AiAssetHelper {
  static final Map<String, String> _extractedPaths = {};

  /// Ensures an asset file is written to local device storage and returns its absolute path.
  static Future<String> getLocalAssetPath(String assetPath) async {
    if (_extractedPaths.containsKey(assetPath)) {
      final cached = _extractedPaths[assetPath]!;
      if (File(cached).existsSync()) {
        return cached;
      }
    }

    try {
      Directory baseDir;
      try {
        baseDir = await getApplicationSupportDirectory();
      } catch (_) {
        baseDir = await getTemporaryDirectory();
      }

      // Preserve relative path structure inside the app directory
      final sanitizedSubPath = assetPath.replaceAll('assets/', '').replaceAll('\\', '/');
      final targetFile = File('${baseDir.path}/$sanitizedSubPath');

      if (await targetFile.exists() && (await targetFile.length()) > 0) {
        _extractedPaths[assetPath] = targetFile.path;
        return targetFile.path;
      }

      await targetFile.parent.create(recursive: true);
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await targetFile.writeAsBytes(bytes, flush: true);

      _extractedPaths[assetPath] = targetFile.path;
      debugPrint('[AiAssetHelper] Extracted $assetPath -> ${targetFile.path} (${bytes.length} bytes)');
      return targetFile.path;
    } catch (e) {
      debugPrint('[AiAssetHelper] Error extracting asset $assetPath: $e');
      // If filesystem extraction fails, return the raw asset path as fallback
      return assetPath;
    }
  }

  /// Checks if a file exists on local storage
  static bool fileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}
