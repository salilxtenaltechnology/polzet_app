import 'package:flutter/material.dart';

import '../../gen/assets.gen.dart';

class AppIcons {
  /*---- Bottom Navigation ----*/
  static Widget activeHome({double size = 24, Color? color, Key? key}) =>
      _img(Assets.images.activeHome, size: size, color: color, key: key);

  static Widget inactiveHome({double size = 24, Color? color, Key? key}) =>
      _img(Assets.images.inactiveHome, size: size, color: color, key: key);

  static Widget activeMessage({double size = 24, Color? color, Key? key}) =>
      _img(Assets.images.activeMessage, size: size, color: color, key: key);

  static Widget inactiveMessage({double size = 24, Color? color, Key? key}) =>
      _img(Assets.images.inactiveMessage, size: size, color: color, key: key);

  static Widget activeBell({double size = 24, Color? color, Key? key}) =>
      _img(Assets.images.activeBell, size: size, color: color, key: key);

  static Widget inactiveBell({double size = 24, Color? color, Key? key}) =>
      _img(Assets.images.inactiveBell, size: size, color: color, key: key);

  /*---- Post Actions ----*/
  static Widget filledHeart({double size = 23, Color? color, Key? key}) =>
      _img(Assets.images.filledHeart, size: size, color: color, key: key);

  static Widget outlineHeart({double size = 24, Color? color, Key? key}) =>
      _img(Assets.images.heart, size: size, color: color, key: key);

  static Widget like({double size = 19, Color? color, Key? key}) =>
      _img(Assets.images.typeLike, size: size, color: color, key: key);

  static Widget icCommnet({double size = 19, Color? color, Key? key}) =>
      _img(Assets.images.icMessage, size: size, color: color, key: key);

  static Widget icVote({double size = 14.5, Color? color, Key? key}) =>
      _img(Assets.images.icVote, size: size, color: color, key: key);

  static Widget commnetBox({double size = 22, Color? color, Key? key}) =>
      _img(Assets.images.comments, size: size, color: color, key: key);

  static Widget sharePost({double size = 23, Color? color, Key? key}) =>
      _img(Assets.images.forward, size: size, color: color, key: key);

  static Widget filledSave({double size = 22, Color? color, Key? key}) =>
      Icon(Icons.bookmark, size: size, color: color, key: key);

  static Widget outlineSave({double size = 22, Color? color, Key? key}) =>
      _img(Assets.images.icSave, size: size, color: color, key: key);


  static Widget _img(
    AssetGenImage asset, {
    double size = 24,
    double? width,
    double? height,
    Color? color,
    BoxFit fit = BoxFit.contain,
    Key? key,
  }) {
    return asset.image(
      key: key,
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcIn : null,
    );
  }
}
