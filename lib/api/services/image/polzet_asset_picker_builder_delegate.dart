// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/button/back_button.dart';
import 'image_picker_service.dart';

/// Custom AssetPickerBuilderDelegate that renders the custom gallery UI to match
/// the Polzet reference design specifications:
/// - Clean white app bar with back arrow and left-aligned "Recents ⌵" dropdown.
/// - Floating white album popover card with soft shadow, thumbnails, and counts.
/// - 3-column photo grid with subtle tile corner rounding (6px) and 4px spacing.
/// - Burgundy circular selection badge with white checkmark on selected tiles.
/// - Bottom bar showing horizontal selected-image strip with tap-to-remove (✕)
///   badges on the left, and burgundy "Next" button on the right.
class PolzetAssetPickerBuilderDelegate
    extends DefaultAssetPickerBuilderDelegate<DefaultAssetPickerProvider> {
  PolzetAssetPickerBuilderDelegate({
    required super.provider,
    required super.initialPermission,
    super.gridCount = 3,
    super.pickerTheme,
    super.textDelegate = const PolzetAssetPickerTextDelegate(),
  }) : super(shouldRevertGrid: false);

  /// Launches the Polzet custom asset picker with this delegate
  static Future<List<AssetEntity>?> pickAssets(
    BuildContext context, {
    required int maxAssets,
    RequestType requestType = RequestType.image,
  }) async {
    const permissionRequestOption = PermissionRequestOption(
      androidPermission: AndroidPermission(
        type: RequestType.image,
        mediaLocation: false,
      ),
    );

    final PermissionState ps = await AssetPicker.permissionCheck(
      requestOption: permissionRequestOption,
    );

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF05070E)
        : const Color(0xFFFDFDFD);
    final DefaultAssetPickerProvider provider = DefaultAssetPickerProvider(
      maxAssets: maxAssets,
      pageSize: 90,
      requestType: requestType,
    );

    final PolzetAssetPickerBuilderDelegate delegate =
        PolzetAssetPickerBuilderDelegate(
          provider: provider,
          initialPermission: ps,
          gridCount: 3,
          pickerTheme: AssetPicker.themeData(
            AppColors.primaryColor,
            light: !isDark,
          ).copyWith(
            scaffoldBackgroundColor: bgColor,
            canvasColor: bgColor,
            cardColor: bgColor,
          ),
          textDelegate: const PolzetAssetPickerTextDelegate(),
        );

    return await AssetPicker.pickAssetsWithDelegate<
      AssetEntity,
      AssetPathEntity,
      DefaultAssetPickerProvider,
      PolzetAssetPickerBuilderDelegate
    >(
      context,
      delegate: delegate,
      permissionRequestOption: permissionRequestOption,
    );
  }

  @override
  // ignore: must_call_super
  void initState(
    covariant AssetPickerState<
      AssetEntity,
      AssetPathEntity,
      PolzetAssetPickerBuilderDelegate
    >
    state,
  ) {
    presentLimitedTapGestureRecognizer = TapGestureRecognizer()
      ..onTap = PhotoManager.presentLimited;
  }

  @override
  double get itemSpacing => 4.0;

  @override
  ThemeData get theme {
    final base = super.theme;
    final isDark = base.brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF05070E)
        : const Color(0xFFFDFDFD);
    return base.copyWith(
      scaffoldBackgroundColor: bgColor,
      canvasColor: bgColor,
      cardColor: bgColor,
    );
  }

  /// Returns `false` so that `wechat_assets_picker` does not inject iOS-specific
  /// duplicate [SliverGap] above the photo grid. Since [PolzetAssetPickerBuilderDelegate]
  /// uses [AssetPickerAppBarWrapper] to position the body cleanly below the app bar,
  /// returning `false` aligns iOS with the clean layout without changing Android logic.
  @override
  bool isAppleOS(BuildContext context) => false;

  @override
  Future<void> selectAsset(
    BuildContext context,
    AssetEntity asset,
    int index,
    bool selected,
  ) async {
    final bool? selectPredicateResult = await selectPredicate?.call(
      context,
      asset,
      selected,
    );
    if (selectPredicateResult == false) {
      return;
    }
    final p = context.read<DefaultAssetPickerProvider>();
    if (selected) {
      p.unSelectAsset(asset);
      return;
    }
    if (isSingleAssetMode) {
      p.selectedAssets = <AssetEntity>[asset];
    } else {
      p.selectAsset(asset);
    }
  }

  @override
  AssetPickerAppBar appBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final AssetPickerAppBar bar = AssetPickerAppBar(
      backgroundColor: isDarkMode
          ? const Color(0xFF05070E)
          : const Color(0xFFFDFDFD),
      elevation: 0,
      centerTitle: true,
      height: AppConstants.toolbarHeight.h,
      leading: SizedBox(
        width: 45.w,
        child: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: PrimaryBackButton(
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      title: pathEntitySelector(context),
      actions: const <Widget>[],
    );
    appBarPreferredSize ??= bar.preferredSize;
    return bar;
  }

  @override
  Widget pathEntitySelector(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (provider.currentPath == null) return;
        isSwitchingPath.value = !isSwitchingPath.value;
      },
      child:
          Selector<DefaultAssetPickerProvider, PathWrapper<AssetPathEntity>?>(
            selector: (_, p) => p.currentPath,
            builder: (_, p, __) {
              final AssetPathEntity? path = p?.path;
              final String name = path == null
                  ? 'Recent'
                  : (isPermissionLimited && path.isAll
                        ? textDelegate.accessiblePathName
                        : pathNameBuilder?.call(path) ?? path.name);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ValueListenableBuilder<bool>(
                    valueListenable: isSwitchingPath,
                    builder: (_, bool isSwitching, __) {
                      return AnimatedRotation(
                        turns: isSwitching ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 24,
                          color: textColor,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget pathEntityListBackdrop(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSwitchingPath,
      builder: (_, bool isSwitching, __) {
        if (!isSwitching) return const SizedBox.shrink();
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => isSwitchingPath.value = false,
            child: const ColoredBox(color: Colors.transparent),
          ),
        );
      },
    );
  }

  @override
  Widget pathEntityListWidget(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<bool>(
      valueListenable: isSwitchingPath,
      builder: (_, bool isSwitching, __) {
        if (!isSwitching) return const SizedBox.shrink();
        return Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              elevation: 10,
              shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.25),
              color: isDark ? AppColors.darkPrimaryCardColor : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: 240,
                constraints: const BoxConstraints(maxHeight: 330),
              child:
                  Selector<
                    DefaultAssetPickerProvider,
                    List<PathWrapper<AssetPathEntity>>
                  >(
                    selector: (_, p) => p.paths,
                    builder: (_, paths, __) {
                      final filtered = paths
                          .where((p) => (p.assetCount ?? 0) > 0)
                          .toList();
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (BuildContext c, int i) =>
                            pathEntityWidget(
                              context: c,
                              list: filtered,
                              index: i,
                            ),
                      );
                    },
                  ),
            ),
          ),
        ),
      );
    },
  );
}

  @override
  Widget pathEntityWidget({
    required BuildContext context,
    required List<PathWrapper<AssetPathEntity>> list,
    required int index,
  }) {
    final PathWrapper<AssetPathEntity> wrapper = list[index];
    final AssetPathEntity pathEntity = wrapper.path;
    final Uint8List? data = wrapper.thumbnailData;

    final String name = isPermissionLimited && pathEntity.isAll
        ? textDelegate.accessiblePathName
        : pathNameBuilder?.call(pathEntity) ?? pathEntity.name;
    final int count = wrapper.assetCount ?? 0;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        Feedback.forTap(context);
        context.read<DefaultAssetPickerProvider>().switchPath(wrapper);
        isSwitchingPath.value = false;
        gridScrollController.jumpTo(0);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                color: isDark
                    ? const Color(0xFF212328)
                    : const Color(0xFFEEEEEE),
                child: data != null
                    ? Image.memory(data, fit: BoxFit.cover)
                    : Icon(
                        Icons.photo,
                        color: isDark ? Colors.white54 : Colors.grey,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: isDark
                          ? AppColors.darkBodyTextColor
                          : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget assetGridItemBuilder({
    required BuildContext context,
    required int index,
    required List<AssetEntity> currentAssets,
    required List<SpecialItemFinalized> specialItemsFinalized,
  }) {
    final p = context.read<DefaultAssetPickerProvider>();
    final int length = currentAssets.length;
    final PathWrapper<AssetPathEntity>? currentWrapper = p.currentPath;
    final AssetPathEntity? currentPathEntity = currentWrapper?.path;

    if (currentPathEntity == null) {
      return const SizedBox.shrink();
    }

    if (p.hasMoreToLoad) {
      if ((p.pageSize <= gridCount * 3 && index == length - 1) ||
          index == length - gridCount * 3) {
        p.loadMoreAssets();
      }
    }

    final AssetEntity asset = currentAssets.elementAt(index);
    final Widget builder = switch (asset.type) {
      AssetType.image ||
      AssetType.video => imageAndVideoItemBuilder(context, index, asset),
      AssetType.audio => audioItemBuilder(context, index, asset),
      AssetType.other => const SizedBox.shrink(),
    };
    final Widget content = Stack(
      key: ValueKey<String>(asset.id),
      children: <Widget>[
        ClipRRect(borderRadius: BorderRadius.circular(6), child: builder),
        selectedBackdrop(context, index, asset),
        selectIndicator(context, index, asset),
      ],
    );
    return content;
  }

  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final selected = provider.selectedAssets.contains(asset);
          selectAsset(context, asset, index, selected);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Selector<DefaultAssetPickerProvider, bool>(
            selector: (_, p) => p.selectedAssets.contains(asset),
            builder: (_, bool selected, __) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                color: selected
                    ? Colors.black.withOpacity(0.35)
                    : Colors.transparent,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    return Selector<DefaultAssetPickerProvider, bool>(
      selector: (_, p) => p.selectedAssets.contains(asset),
      builder: (BuildContext context, bool selected, _) {
        return Positioned(
          top: 8,
          right: 8,
          child: IgnorePointer(
            ignoring: !selected,
            child: AnimatedScale(
              scale: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: selected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    selectAsset(context, asset, index, selected);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryColor,
                      border: Border.all(color: Colors.white, width: 1.8),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget bottomActionBar(BuildContext context) {
    return Selector<DefaultAssetPickerProvider, int>(
      selector: (_, p) => p.selectedAssets.length,
      builder: (BuildContext context, int count, _) {
        if (count == 0) {
          return const SizedBox.shrink();
        }
        final double bottomPadding = MediaQuery.of(context).padding.bottom;
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode
          ? const Color(0xFF05070E)
          : const Color(0xFFFDFDFD),
            border: Border(
              top: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : const Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 54,
                  child:
                      Selector<DefaultAssetPickerProvider, List<AssetEntity>>(
                        selector: (_, p) => p.selectedAssets,
                        builder: (_, selectedList, __) {
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (BuildContext ctx, int i) {
                              final asset = selectedList[i];
                              return Stack(
                                clipBehavior: Clip.none,
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 54,
                                      height: 54,
                                      child: AssetEntityImage(
                                        asset,
                                        isOriginal: false,
                                        thumbnailSize:
                                            const ThumbnailSize.square(150),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        selectAsset(ctx, asset, -1, true);
                                      },
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  if (provider.selectedAssets.isNotEmpty) {
                    Navigator.of(context).maybePop(provider.selectedAssets);
                  }
                },
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 35),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget androidLayout(BuildContext context) {
    return AssetPickerAppBarWrapper(
      appBar: appBar(context),
      body: Consumer<DefaultAssetPickerProvider>(
        builder: (context, p, _) {
          final hasAssetsToDisplay = p.hasAssetsToDisplay;
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final shouldBuildSpecialItems = assetsGridSpecialItemsFinalized(
            context: context,
            path: p.currentPath?.path,
          ).isNotEmpty;
          final shouldDisplayAssets =
              hasAssetsToDisplay || shouldBuildSpecialItems;
          final Color bgColor = isDarkMode
              ? const Color(0xFF05070E)
              : const Color(0xFFFDFDFD);
          return ColoredBox(
            color: bgColor,
            child: AnimatedSwitcher(
              duration: switchingPathDuration,
              child: shouldDisplayAssets
                  ? Stack(
                      children: <Widget>[
                        RepaintBoundary(
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                child: ColoredBox(
                                  color: bgColor,
                                  child: assetsGridBuilder(context),
                                ),
                              ),
                              bottomActionBar(context),
                            ],
                          ),
                        ),
                        pathEntityListBackdrop(context),
                        pathEntityListWidget(context),
                      ],
                    )
                  : loadingIndicator(context),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget appleOSLayout(BuildContext context) => androidLayout(context);
}
