import 'dart:typed_data';
import 'dart:convert';
import 'package:polzet_app/api/api_config.dart';

final Map<String, Uint8List> _imageCache = {};

String? resolveProfileImageUrl(String? path) {
  if (path == null || path.trim().isEmpty || path.trim() == 'null') return null;
  if (path.startsWith('assets/')) return path;
  if (path.startsWith('http') || path.startsWith('data:image')) return path;
  final separator = path.startsWith('/') ? '' : '/';
  return '${ApiConfig.baseUrlImage}$separator$path';
}


Uint8List? getConvertImage(image) {
  if (image == null || image.isEmpty) return null;
  try {
    final str = image as String;
    if (_imageCache.containsKey(str)) {
      return _imageCache[str];
    }

    // Return null immediately for paths and URLs to avoid throwing FormatException in base64Decode
    if (str.startsWith('/') || str.startsWith('http') || str.contains('/')) {
      return null;
    }

    final idx = str.indexOf('base64,');
    final Uint8List decoded;
    if (idx != -1) {
      decoded = base64Decode(str.substring(idx + 7));
    } else {
      decoded = base64Decode(str);
    }

    // Keep cache size bounded to prevent memory leaks
    if (_imageCache.length > 100) {
      _imageCache.clear();
    }
    _imageCache[str] = decoded;
    return decoded;
  } catch (e) {
    return null;
  }
}

Uint8List? getProfileImage(profilePicture) {
  return getConvertImage(profilePicture);
}
