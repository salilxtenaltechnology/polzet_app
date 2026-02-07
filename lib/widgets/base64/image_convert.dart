// ignore_for_file: strict_top_level_inference

import 'dart:typed_data';
import 'dart:convert';

Uint8List? getConvertImage(image) {
  if (image == null || image.isEmpty) return null;
  try {
    String base64Data = image.replaceFirst(
      RegExp(r'data:image/[^;]+;base64,'),
      '',
    );
    return base64Decode(base64Data);
  } catch (e) {
    return null;
  }
}

Uint8List? getProfileImage(profilePicture) {
  if (profilePicture == null || profilePicture.isEmpty) return null;
  try {
    String base64Data = profilePicture.replaceFirst(
      RegExp(r'data:image/[^;]+;base64,'),
      '',
    );
    return base64Decode(base64Data);
  } catch (e) {
    return null;
  }
}
