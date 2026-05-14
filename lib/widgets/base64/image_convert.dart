// ignore_for_file: strict_top_level_inference

import 'dart:typed_data';
import 'dart:convert';

final Map<String, Uint8List> _imageCache = {};

Uint8List? getConvertImage(image) {
  if (image == null || image.isEmpty) return null;
  try {
    final str = image as String;
    if (_imageCache.containsKey(str)) {
      return _imageCache[str];
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
