import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Manages extraction of bundled AI model assets to local storage for native FFI / C++ engines.
class AiAssetHelper {
  static final Map<String, String> _extractedPaths = {};

  /// Ensures an asset file exists on local filesystem and returns its verified absolute path.
  /// Throws [FileSystemException] if neither extracted asset nor direct disk asset exists.
  static Future<String> getLocalAssetPath(String assetPath) async {
    if (_extractedPaths.containsKey(assetPath)) {
      final cached = _extractedPaths[assetPath]!;
      final f = File(cached);
      if (f.existsSync() && f.lengthSync() > 0) {
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
      // Fallback for host unit tests running in project root without path_provider plugin
      final directFile = File(assetPath);
      if (directFile.existsSync() && directFile.lengthSync() > 0) {
        final absPath = directFile.absolute.path;
        _extractedPaths[assetPath] = absPath;
        return absPath;
      }
      debugPrint('[AiAssetHelper] Asset unavailable ($assetPath): $e');
      rethrow;
    }
  }

  /// Checks if a file exists on local storage with non-zero length.
  static bool fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      final f = File(path);
      return f.existsSync() && f.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }
}
