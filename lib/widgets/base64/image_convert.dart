// ignore_for_file: strict_top_level_inference

import 'dart:typed_data';
import 'dart:convert';

Uint8List? getConvertImage(image) {
  if (image == null || image.isEmpty) return null;
  try {
    final str = image as String;
    final idx = str.indexOf('base64,');
    if (idx != -1) {
      return base64Decode(str.substring(idx + 7));
    }
    return base64Decode(str);
  } catch (e) {
    return null;
  }
}

Uint8List? getProfileImage(profilePicture) {
  if (profilePicture == null || profilePicture.isEmpty) return null;
  try {
    final str = profilePicture as String;
    final idx = str.indexOf('base64,');
    if (idx != -1) {
      return base64Decode(str.substring(idx + 7));
    }
    return base64Decode(str);
  } catch (e) {
    return null;
  }
}
