// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/acc_verify.png
  AssetGenImage get accVerify =>
      const AssetGenImage('assets/images/acc_verify.png');

  /// File path: assets/images/active_bell.png
  AssetGenImage get activeBell =>
      const AssetGenImage('assets/images/active_bell.png');

  /// File path: assets/images/active_home.png
  AssetGenImage get activeHome =>
      const AssetGenImage('assets/images/active_home.png');

  /// File path: assets/images/active_message.png
  AssetGenImage get activeMessage =>
      const AssetGenImage('assets/images/active_message.png');

  /// File path: assets/images/active_user.png
  AssetGenImage get activeUser =>
      const AssetGenImage('assets/images/active_user.png');

  /// File path: assets/images/add_group.png
  AssetGenImage get addGroup =>
      const AssetGenImage('assets/images/add_group.png');

  /// File path: assets/images/add_image.png
  AssetGenImage get addImage =>
      const AssetGenImage('assets/images/add_image.png');

  /// File path: assets/images/add_users.png
  AssetGenImage get addUsers =>
      const AssetGenImage('assets/images/add_users.png');

  /// File path: assets/images/bg.png
  AssetGenImage get bg => const AssetGenImage('assets/images/bg.png');

  /// File path: assets/images/comments.png
  AssetGenImage get comments =>
      const AssetGenImage('assets/images/comments.png');

  /// File path: assets/images/connected.json
  String get connected => 'assets/images/connected.json';

  /// File path: assets/images/current_user.png
  AssetGenImage get currentUser =>
      const AssetGenImage('assets/images/current_user.png');

  /// File path: assets/images/default_cover.png
  AssetGenImage get defaultCover =>
      const AssetGenImage('assets/images/default_cover.png');

  /// File path: assets/images/filled_heart.png
  AssetGenImage get filledHeart =>
      const AssetGenImage('assets/images/filled_heart.png');

  /// File path: assets/images/forward.png
  AssetGenImage get forward => const AssetGenImage('assets/images/forward.png');

  /// File path: assets/images/heart.png
  AssetGenImage get heart => const AssetGenImage('assets/images/heart.png');

  /// File path: assets/images/ic_active_poll.png
  AssetGenImage get icActivePoll =>
      const AssetGenImage('assets/images/ic_active_poll.png');

  /// File path: assets/images/ic_add_user.png
  AssetGenImage get icAddUser =>
      const AssetGenImage('assets/images/ic_add_user.png');

  /// File path: assets/images/ic_facebook.png
  AssetGenImage get icFacebook =>
      const AssetGenImage('assets/images/ic_facebook.png');

  /// File path: assets/images/ic_google.png
  AssetGenImage get icGoogle =>
      const AssetGenImage('assets/images/ic_google.png');

  /// File path: assets/images/ic_poll.png
  AssetGenImage get icPoll => const AssetGenImage('assets/images/ic_poll.png');

  /// File path: assets/images/ic_splash.png
  AssetGenImage get icSplash =>
      const AssetGenImage('assets/images/ic_splash.png');

  /// File path: assets/images/ic_user.png
  AssetGenImage get icUser => const AssetGenImage('assets/images/ic_user.png');

  /// File path: assets/images/ic_users.png
  AssetGenImage get icUsers =>
      const AssetGenImage('assets/images/ic_users.png');

  /// File path: assets/images/image_icon.png
  AssetGenImage get imageIcon =>
      const AssetGenImage('assets/images/image_icon.png');

  /// File path: assets/images/inactive_bell.png
  AssetGenImage get inactiveBell =>
      const AssetGenImage('assets/images/inactive_bell.png');

  /// File path: assets/images/inactive_home.png
  AssetGenImage get inactiveHome =>
      const AssetGenImage('assets/images/inactive_home.png');

  /// File path: assets/images/inactive_message.png
  AssetGenImage get inactiveMessage =>
      const AssetGenImage('assets/images/inactive_message.png');

  /// File path: assets/images/inactive_user.png
  AssetGenImage get inactiveUser =>
      const AssetGenImage('assets/images/inactive_user.png');

  /// File path: assets/images/insights.json
  String get insights => 'assets/images/insights.json';

  /// File path: assets/images/loading.json
  String get loading => 'assets/images/loading.json';

  /// File path: assets/images/lost_connection.json
  String get lostConnection => 'assets/images/lost_connection.json';

  /// File path: assets/images/poll.png
  AssetGenImage get poll => const AssetGenImage('assets/images/poll.png');

  /// File path: assets/images/progress_indicator.json
  String get progressIndicator => 'assets/images/progress_indicator.json';

  /// File path: assets/images/server.png
  AssetGenImage get server => const AssetGenImage('assets/images/server.png');

  /// File path: assets/images/share.png
  AssetGenImage get share => const AssetGenImage('assets/images/share.png');

  /// File path: assets/images/things.png
  AssetGenImage get things => const AssetGenImage('assets/images/things.png');

  /// File path: assets/images/things_icon.png
  AssetGenImage get thingsIcon =>
      const AssetGenImage('assets/images/things_icon.png');

  /// List of all assets
  List<dynamic> get values => [
    accVerify,
    activeBell,
    activeHome,
    activeMessage,
    activeUser,
    addGroup,
    addImage,
    addUsers,
    bg,
    comments,
    connected,
    currentUser,
    defaultCover,
    filledHeart,
    forward,
    heart,
    icActivePoll,
    icAddUser,
    icFacebook,
    icGoogle,
    icPoll,
    icSplash,
    icUser,
    icUsers,
    imageIcon,
    inactiveBell,
    inactiveHome,
    inactiveMessage,
    inactiveUser,
    insights,
    loading,
    lostConnection,
    poll,
    progressIndicator,
    server,
    share,
    things,
    thingsIcon,
  ];
}

class Assets {
  const Assets._();

  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
