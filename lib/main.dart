// ignore_for_file: unused_field, deprecated_member_use, unused_element, library_private_types_in_public_api
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/search/posts/single_post_details.dart';
import 'package:provider/provider.dart';

import 'api/services/notification/notification_services.dart';
import 'core/constants/app_strings.dart';
import 'core/navigation/notification_router.dart';
import 'core/themes/app_themes.dart';
import 'core/themes/theme_provider.dart';
import 'data/token/shared_preferences.dart';
import 'firebase_options.dart';
import 'languages/l10n/generated/app_localizations.dart';
import 'provider/connection_provider.dart';
import 'provider/private_chat_provider.dart';

import 'provider/user_provider.dart';
import 'screens/home/home_imports.dart';
import 'screens/home/profile/chase/user_chase.dart';
import 'screens/home/message/chat/private/private_chat_screen.dart';
import 'screens/home/message/chat/group/group_chat_screen.dart';
import 'screens/home/profile/public/public_profile_screen.dart';
import 'provider/group_chat_provider.dart';
import 'screens/splash/splash_screen.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🔔 Background message received: ${message.data}");
  await NotificationService.showBackgroundNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SharedPrefService.clearOnFirstLaunch();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }

  try {
    if (kReleaseMode) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      debugPrint('✅ App Check activated (production)');
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      debugPrint('✅ App Check activated (debug)');
    }
  } catch (e) {
    debugPrint('⚠️ App Check failed (non-critical): $e');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      NotificationRouter().setPendingNotification(initialMessage);
    }
    debugPrint('✅ FCM initialized');
  } catch (e) {
    debugPrint('❌ FCM initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
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
    NotificationService().initialize();
    _setupNotificationCallbacks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    NotificationService().updateAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed');
        _reconnectNotificationWebSocket();
        _reconnectChatWebSocketIfActive();
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 App paused');
        break;
      default:
        break;
    }
  }

  /// Reconnect notification WebSocket
  Future<void> _reconnectNotificationWebSocket() async {
    final loggedIn = await _isLoggedIn();
    if (loggedIn && !NotificationService().isWebSocketConnected) {
      debugPrint('🔄 Reconnecting Notification WebSocket...');
      final accessToken = await SharedPrefService.getToken();
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
    final accessToken = await SharedPrefService.getToken();
    return accessToken != null;
  }

  Future<void> _loadSavedLanguage() async {
    final languageCode = await SharedPrefService.getLanguage();
    final String currentLang = languageCode ?? 'en';
    setState(() {
      _locale = Locale(currentLang);
    });
    try {
      await FirebaseAuth.instance.setLanguageCode(currentLang);
    } catch (e) {
      debugPrint('Error setting Firebase language code: $e');
    }
  }

  void changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
    try {
      FirebaseAuth.instance.setLanguageCode(locale.languageCode);
    } catch (e) {
      debugPrint('Error setting Firebase language code: $e');
    }
  }

  void resetLocale() {
    setState(() {
      _locale = const Locale('en');
    });
    try {
      FirebaseAuth.instance.setLanguageCode('en');
    } catch (e) {
      debugPrint('Error setting Firebase language code: $e');
    }
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
      debugPrint('⏳ UserProvider not ready, triggering silent load...');
      userProvider.loadUserDataSilently();
      final ready = await userProvider.waitForUserData(
        timeout: const Duration(seconds: 5),
      );
      if (!ready) {
        debugPrint('❌ Timeout waiting for UserProvider');
        _navigateToNotificationsTab(context);
        return;
      }
    }

    _navigateToNotificationDestination(context, message.data, messageId: message.messageId);
  }

  void _handleForegroundNotificationTap(NotificationPayload payload) async {
    final context = navigatorKey.currentContext;
    if (context == null || !mounted) {
      debugPrint('⚠️ Context not ready for foreground navigation');
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!userProvider.isUserDataValid()) {
      debugPrint('⏳ UserProvider not ready, triggering silent load...');
      userProvider.loadUserDataSilently();
      final ready = await userProvider.waitForUserData(
        timeout: const Duration(seconds: 5),
      );
      if (!ready) {
        debugPrint('❌ Timeout waiting for UserProvider');
        _navigateToNotificationsTab(context);
        return;
      }
    }

    _navigateToNotificationDestination(context, payload.data, messageId: payload.id);
  }

  void _navigateToNotificationDestination(
    BuildContext context,
    Map<String, dynamic> rawData, {
    String? messageId,
  }) {
    if (messageId != null) {
      SharedPrefService.setString('last_processed_notification_id', messageId);
      debugPrint('📬 main.dart: Persisted processed notification ID: $messageId');
    }

    final notificationData = rawData['notification'] is Map
        ? rawData['notification'] as Map<String, dynamic>
        : rawData;

    final Map<String, dynamic> data = {...rawData, ...notificationData};
    final type = (data['type'] ?? '').toString().toLowerCase().trim();

    // Read username from provider
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String username = userProvider.username ?? '';

    debugPrint('🎯 Navigating to notification type: "$type"');
    debugPrint('📋 Full notification data: $data');
    debugPrint('   👤 Username: $username');

    Widget? destination;

    if (type == 'like' ||
        type == 'like_group' ||
        type == 'comment' ||
        type == 'commetnt' ||
        type == 'vote' ||
        type == 'reply') {
      final String? postId = data['post_id']?.toString();
      debugPrint('   📝 Post notification detected - postId: $postId');

      if (postId != null && postId.isNotEmpty && postId != '0') {
        if (username.isEmpty) {
          debugPrint(
            '⚠️ _navigateToNotificationDestination: username is empty, fallback to notifications tab',
          );
          _navigateToNotificationsTab(context);
          return;
        }
        destination = SinglePostDetails(username: username, postId: postId);
      } else {
        debugPrint('❌ Invalid or missing post_id for type: $type');
      }
    } else if (type == 'follow') {
      final String? userId = data['sender_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        destination = PublicProfileScreen(userId: userId);
      } else {
        debugPrint('❌ Invalid or missing sender_id for type: $type');
      }
    } else if (type == 'follow_group') {
      destination = UserChase(
        username: userProvider.username ?? '',
        initialIndex: 0,
        followerCount: userProvider.followers_count ?? '0',
        followingCount: userProvider.following_count ?? '0',
        chaseList: userProvider.chase_list,
        rechaseList: userProvider.rechase_list,
      );
    } else if (type == 'new_message' ||
        type == 'new_group_added' ||
        type == 'group_admin_promote') {
      final meta = data['meta'] is Map
          ? data['meta'] as Map<String, dynamic>
          : null;
      final senderId = _parseToInt(data['sender_id'] ?? meta?['sender_id']);
      final memberName = (data['sender'] ?? meta?['sender'] ?? 'Chat')
          .toString();
      final profileUrl = (data['sender_profile_image'] ?? data['profile_image'])
          ?.toString();
      final chatId = _parseToInt(data['chat_id'] ?? meta?['chat_id']);
      final groupName =
          (data['group_name'] ?? meta?['group_name'])?.toString() ?? '';

      debugPrint(
        '   💬 Message notification - name: $memberName, chatId: $chatId, groupName: $groupName',
      );

      if (chatId > 0) {
        if (groupName.isNotEmpty) {
          destination = ChangeNotifierProvider(
            create: (_) => GroupChatProvider(),
            child: GroupChatScreen(groupName: groupName, chatId: chatId),
          );
        } else {
          destination = PrivateChatScreen(
            userId: senderId,
            memberName: memberName,
            profileUrl: profileUrl,
            chatId: chatId,
          );
        }
      } else {
        debugPrint('❌ Invalid or missing chat_id for type: $type');
      }
    } else {
      debugPrint('⚠️ Unknown notification type: "$type"');
    }

    if (destination != null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => destination!));
    } else {
      _navigateToNotificationsTab(context);
    }
  }

  void _navigateToNotificationsTab(BuildContext context) {
    debugPrint('🔔 Navigating to notifications tab');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 0)),
      (route) => false,
    );
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ScreenUtilInit(
      designSize: const Size(360, 800),
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
