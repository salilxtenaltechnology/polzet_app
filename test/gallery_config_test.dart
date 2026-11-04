import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:polzet_app/api/services/image/gallery_config.dart';
import 'package:polzet_app/api/services/image/image_picker_service.dart';
import 'package:polzet_app/api/services/image/polzet_asset_picker_builder_delegate.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.fluttercandies/photo_manager'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAssetPathList') {
          return <dynamic, dynamic>{'data': <dynamic>[]};
        }
        if (methodCall.method == 'requestPermissionExtend' ||
            methodCall.method == 'getPermissionResult') {
          return 1;
        }
        return <dynamic, dynamic>{'data': <dynamic>[]};
      },
    );
  });

  group('Gallery Configuration & AssetPickerConfig Tests', () {
    test('GalleryConfig defaults to customGallery in non-release mode', () {
      GalleryConfig.setForceSystemPickerForTesting(null);
      expect(GalleryConfig.isCustomGalleryActive, isTrue);
      expect(GalleryConfig.currentMode, GalleryPickerMode.customGallery);
    });

    test('GalleryConfig responds to forced mode in testing', () {
      GalleryConfig.setForceSystemPickerForTesting(true);
      expect(GalleryConfig.isCustomGalleryActive, isFalse);
      expect(GalleryConfig.currentMode, GalleryPickerMode.systemPhotoPicker);

      GalleryConfig.setForceSystemPickerForTesting(false);
      expect(GalleryConfig.isCustomGalleryActive, isTrue);
      expect(GalleryConfig.currentMode, GalleryPickerMode.customGallery);

      GalleryConfig.setForceSystemPickerForTesting(null);
    });

    test('AssetPickerConfig initializes with pickerTheme and NO themeColor without assertion error', () {
      // Verifies that line 45 assertion ('pickerTheme == null || themeColor == null')
      // and line 52 assertion ('pageSize % gridCount == 0') both pass
      expect(
        () => AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.image,
          gridCount: 3,
          pageSize: 90,
          pickerTheme: AssetPicker.themeData(AppColors.primaryColor, light: true),
          textDelegate: const PolzetAssetPickerTextDelegate(),
        ),
        returnsNormally,
      );

      expect(
        () => AssetPickerConfig(
          maxAssets: 9,
          requestType: RequestType.image,
          gridCount: 3,
          pageSize: 90,
          pickerTheme: AssetPicker.themeData(AppColors.primaryColor, light: true),
          textDelegate: const PolzetAssetPickerTextDelegate(),
        ),
        returnsNormally,
      );
    });

    test('AssetPickerConfig throws assertion if both pickerTheme and themeColor are provided', () {
      expect(
        () => AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.image,
          gridCount: 3,
          pageSize: 90,
          themeColor: AppColors.primaryColor,
          pickerTheme: AssetPicker.themeData(AppColors.primaryColor, light: true),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('PolzetAssetPickerBuilderDelegate initializes with 3 columns, 4px spacing, and custom styling', () {
      final provider = DefaultAssetPickerProvider(
        maxAssets: 4,
        pageSize: 90,
        requestType: RequestType.image,
      );

      final delegate = PolzetAssetPickerBuilderDelegate(
        provider: provider,
        initialPermission: PermissionState.authorized,
        gridCount: 3,
        pickerTheme: AssetPicker.themeData(AppColors.primaryColor, light: true),
        textDelegate: const PolzetAssetPickerTextDelegate(),
      );

      expect(delegate.gridCount, 3);
      expect(delegate.itemSpacing, 4.0);
      expect(delegate.textDelegate.confirm, 'Next');
    });

    testWidgets('PolzetAssetPickerBuilderDelegate renders custom AppBar with back arrow and Recents title', (WidgetTester tester) async {
      final provider = DefaultAssetPickerProvider(
        maxAssets: 4,
        pageSize: 90,
        requestType: RequestType.image,
      );

      final delegate = PolzetAssetPickerBuilderDelegate(
        provider: provider,
        initialPermission: PermissionState.authorized,
        gridCount: 3,
        pickerTheme: AssetPicker.themeData(AppColors.primaryColor, light: true),
        textDelegate: const PolzetAssetPickerTextDelegate(),
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 800),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (newCtx) => ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
                          value: provider,
                          child: Scaffold(
                            appBar: delegate.appBar(newCtx),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('AssetPicker widget mounts with PolzetAssetPickerBuilderDelegate without runtime type error', (WidgetTester tester) async {
      final provider = DefaultAssetPickerProvider(
        maxAssets: 4,
        pageSize: 90,
        requestType: RequestType.image,
      );

      final delegate = PolzetAssetPickerBuilderDelegate(
        provider: provider,
        initialPermission: PermissionState.authorized,
        gridCount: 3,
        pickerTheme: AssetPicker.themeData(AppColors.primaryColor, light: true),
        textDelegate: const PolzetAssetPickerTextDelegate(),
      );

      final picker = AssetPicker<AssetEntity, AssetPathEntity,
          PolzetAssetPickerBuilderDelegate>(
        permissionRequestOption: const PermissionRequestOption(),
        builder: delegate,
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 800),
          child: MaterialApp(
            home: picker,
          ),
        ),
      );

      // Settle the DefaultAssetPickerProvider 250ms initialization timer
      await tester.pump(const Duration(milliseconds: 300));

      // Verify widget mounted successfully and initState ran with no State subtype exception
      expect(find.byWidget(picker), findsOneWidget);
    });

    testWidgets('PolzetAssetPickerBuilderDelegate isAppleOS returns false on both iOS and Android to prevent duplicate top gaps', (WidgetTester tester) async {
      final provider = DefaultAssetPickerProvider(
        maxAssets: 4,
        pageSize: 90,
        requestType: RequestType.image,
      );

      final delegate = PolzetAssetPickerBuilderDelegate(
        provider: provider,
        initialPermission: PermissionState.authorized,
        gridCount: 3,
        pickerTheme: AssetPicker.themeData(AppColors.primaryColor, light: true),
        textDelegate: const PolzetAssetPickerTextDelegate(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) {
              expect(delegate.isAppleOS(context), isFalse);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (context) {
              expect(delegate.isAppleOS(context), isFalse);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
