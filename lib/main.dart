// ignore_for_file: unused_field, deprecated_member_use, unused_element, library_private_types_in_public_api
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/services/link/deeplink_generator_service.dart';
import 'api/services/notification/notification_services.dart';
import 'core/constants/app_strings.dart';
import 'core/navigation/notification_router.dart';
import 'core/themes/app_themes.dart';
import 'core/themes/theme_provider.dart';
import 'data/token/shared_preferences.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'provider/group_chat_provider.dart';
import 'provider/private_chat_provider.dart';
import 'provider/public_profile_provider.dart';
import 'provider/user_provider.dart';
import 'screens/home/home feed/post/post_details_screen.dart';
import 'screens/home/home_imports.dart';
import 'screens/home/notifications/notification_details.dart';
import 'screens/home/profile/public/public_profile.dart';
import 'screens/splash/splash_screen.dart';

// ✅ Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🔔 Background message received: ${message.data}");
  await NotificationService.showBackgroundNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 COLD START: Notification tap detected');
      debugPrint('   Title: ${initialMessage.notification?.title}');
      debugPrint('   Body: ${initialMessage.notification?.body}');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('📋 NOTIFICATION DATA STRUCTURE:');
      debugPrint('   Keys: ${initialMessage.data.keys.toList()}');
      initialMessage.data.forEach((key, value) {
        debugPrint('   $key: $value (${value.runtimeType})');
      });

      if (initialMessage.data.containsKey('notification')) {
        debugPrint('   ⚠️ DETECTED NESTED "notification" OBJECT!');
        debugPrint('   Content: ${initialMessage.data['notification']}');
      }
      debugPrint('═══════════════════════════════════════════════════');

      NotificationRouter().setPendingNotification(initialMessage);
    }

    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => PublicProfileProvider()),
        // ✅ Register PrivateChatProvider at app level so its WS lifecycle
        // is managed globally and survives screen navigation
        ChangeNotifierProvider(create: (_) => PrivateChatProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Locale? _locale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLanguage();
    _initializeDeepLinking();
    NotificationService().initialize();
    _setupNotificationCallbacks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkService().dispose();
    NotificationService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // ✅ Keep NotificationService in sync with lifecycle
    NotificationService().updateAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed');
        _reconnectNotificationWebSocket();
        _reconnectChatWebSocketIfActive(); // ✅ Also reconnect chat WS
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 App paused');
        // ✅ Do NOT disconnect chat WS on pause — let PrivateChatProvider
        // handle its own reconnect. Disconnecting here causes the issue.
        break;
      default:
        break;
    }
  }

  /// ✅ Reconnect notification WebSocket
  Future<void> _reconnectNotificationWebSocket() async {
    final loggedIn = await _isLoggedIn();
    if (loggedIn && !NotificationService().isWebSocketConnected) {
      debugPrint('🔄 Reconnecting Notification WebSocket...');
      final accessToken = await SharedPrefService.getAccessToken();
      if (accessToken != null) {
        await NotificationService().connectToWebSocket(accessToken);
      }
    }
  }

  Future<void> _reconnectChatWebSocketIfActive() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final chatProvider = Provider.of<PrivateChatProvider>(
      context,
      listen: false,
    );

    if (chatProvider.memberName != null && !chatProvider.isConnected) {
      debugPrint('🔄 Reconnecting Chat WebSocket...');
      await chatProvider.reconnect();
    }
  }

  Future<bool> _isLoggedIn() async {
    final accessToken = await SharedPrefService.getAccessToken();
    return accessToken != null;
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode');
    if (languageCode != null) {
      setState(() {
        _locale = Locale(languageCode);
      });
    }
  }

  void changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  void _setupNotificationCallbacks() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👆 Notification tapped (background): ${message.data}');
      _handleBackgroundNotificationTap(message);
    });

    NotificationService().onFCMMessageTap = (payload) {
      debugPrint('👆 Local notification tapped: ${payload.data}');
      _handleForegroundNotificationTap(payload);
    };
  }

  void _handleBackgroundNotificationTap(RemoteMessage message) async {
    final context = navigatorKey.currentContext;
    if (context == null || !mounted) {
      debugPrint('⚠️ Context not ready, storing notification for later');
      NotificationRouter().setPendingNotification(message);
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!userProvider.isUserDataValid()) {
      debugPrint('⏳ UserProvider not ready, waiting...');
      final ready = await userProvider.waitForUserData(
        timeout: const Duration(seconds: 5),
      );
      if (!ready) {
        debugPrint('❌ Timeout waiting for UserProvider');
        _navigateToNotificationsTab(context);
        return;
      }
    }

    _navigateToNotificationDestination(context, message.data);
  }

  void _handleForegroundNotificationTap(NotificationPayload payload) async {
    final context = navigatorKey.currentContext;
    if (context == null || !mounted) {
      debugPrint('⚠️ Context not ready for foreground navigation');
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!userProvider.isUserDataValid()) {
      debugPrint('⏳ UserProvider not ready, waiting...');
      final ready = await userProvider.waitForUserData(
        timeout: const Duration(seconds: 5),
      );
      if (!ready) {
        debugPrint('❌ Timeout waiting for UserProvider');
        _navigateToNotificationsTab(context);
        return;
      }
    }

    _navigateToNotificationDestination(context, payload.data);
  }

  void _navigateToNotificationDestination(
    BuildContext context,
    Map<String, dynamic> rawData,
  ) {
    final notificationData = rawData['notification'] is Map
        ? rawData['notification'] as Map<String, dynamic>
        : rawData;

    final Map<String, dynamic> data = {...rawData, ...notificationData};
    final type = (data['type'] ?? '').toString().toLowerCase().trim();

    debugPrint('🎯 Navigating to notification type: "$type"');
    debugPrint('📋 Full notification data: $data');

    Widget? destination;

    if (type == 'like' ||
        type == 'comment' ||
        type == 'commetnt' ||
        type == 'vote' ||
        type == 'reply') {
      final postId = _parseToInt(data['post_id']);
      debugPrint('   📝 Post notification detected - postId: $postId');

      if (postId > 0) {
        debugPrint('✅ Creating NotificationDetails (postId: $postId)');
        destination = NotificationDetails(postId: postId);
      } else {
        debugPrint('❌ Invalid or missing post_id for type: $type');
      }
    } else if (type == 'follow') {
      final userId = _parseToInt(data['sender_id']);
      debugPrint('   👤 Follow notification detected - userId: $userId');

      if (userId > 0) {
        debugPrint('✅ Creating PublicProfile (userId: $userId)');
        destination = PublicProfile(userId: userId);
      } else {
        debugPrint('❌ Invalid or missing sender_id for type: $type');
      }
    } else {
      debugPrint('⚠️ Unknown notification type: "$type"');
    }

    if (destination != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => destination!));
    } else {
      debugPrint('↩️ No valid destination, going to notifications tab');
      _navigateToNotificationsTab(context);
    }
  }

  void _navigateToNotificationsTab(BuildContext context) {
    debugPrint('🔔 Navigating to notifications tab');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 3)),
      (route) => false,
    );
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _initializeDeepLinking() {
    DeepLinkService().initialize(
      onPostLinkReceived: (username, postId) {
        debugPrint('🔗 Deep link - Username: $username, PostId: $postId');
        _navigateToPostDetail(username, postId);
      },
    );
  }

  void _navigateToPostDetail(String username, String postId) {
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = navigatorKey.currentContext;
      if (context != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                PostDetailScreen(username: username, postId: postId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      useInheritedMediaQuery: true,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        locale: _locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
          Locale('de'),
          Locale('hi'),
          Locale('id'),
          Locale('es'),
          Locale('vi'),
        ],
        theme: AppThemes.lightMode,
        darkTheme: AppThemes.darkMode,
        themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        title: AppStrings.appName,
        home: const SplashScreen(),
      ),
    );
  }
}