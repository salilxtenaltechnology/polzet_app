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
import 'core/themes/app_themes.dart';
import 'core/themes/theme_provider.dart';
import 'data/token/shared_preferences.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'provider/public_profile_provider.dart';
import 'provider/user_provider.dart';
import 'screens/home/home feed/post/post_details_screen.dart';
import 'screens/home/home_imports.dart';
import 'screens/home/notifications/notification_details.dart';
import 'screens/home/profile/public/public_profile.dart';
import 'screens/home/settings/security/biometric/biometric_screen.dart';
import 'screens/home/settings/security/biometric/biometric_service.dart';
import 'screens/home/settings/security/pin/pin_gate_screen.dart';
import 'screens/home/settings/security/pin/pin_status.dart';
import 'screens/splash/splash_screen.dart';

// ✅ Background message handler - CRITICAL for tap handling when app is killed/background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint("🔔 ===== BACKGROUND MESSAGE HANDLER =====");
  debugPrint("Title: ${message.notification?.title}");
  debugPrint("Body: ${message.notification?.body}");
  debugPrint("Data: ${message.data}");
  debugPrint("========================================");

  // ✅ The notification is automatically shown by FCM in background
  // We just need to log here - tap handling is done in onMessageOpenedApp
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ CRITICAL: Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await NotificationService().initialize();
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
  String? _pendingUsername;
  String? _pendingPostId;
  bool _isAppInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLanguage();
    _initializeDeepLinking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationCallbacks();
    });
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

    // ✅ CRITICAL: Update NotificationService with app state
    NotificationService().updateAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed - ONLINE');
        _reconnectWebSocketIfNeeded();
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 App paused - OFFLINE');
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 App inactive');
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 App detached - TERMINATED');
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden');
        break;
    }
  }

  Future<bool> isLoggedIn() async {
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

  // ✅ Only setup notification tap callbacks here - permission handled in HomeScreen
  Future<void> _setupNotificationCallbacks() async {
    debugPrint('🔧 Setting up notification tap callbacks...');

    // ✅ CRITICAL: Callback for notification TAPS
    NotificationService().onFCMMessageTap = (payload) {
      debugPrint('👆 ===== NOTIFICATION TAPPED =====');
      debugPrint('Type: ${payload.type}');
      debugPrint('Data: ${payload.data}');
      debugPrint('==================================');

      _handleNotificationTap(payload);
    };

    debugPrint('✅ Notification tap callback registered');
  }

  Future<void> _reconnectWebSocketIfNeeded() async {
    final loggedIn = await isLoggedIn();
    if (loggedIn && !NotificationService().isWebSocketConnected) {
      debugPrint('🔄 Reconnecting WebSocket...');
      final accessToken = await SharedPrefService.getAccessToken();
      if (accessToken != null) {
        await NotificationService().connectToWebSocket(accessToken);
      }
    }
  }

  void _handleNotificationTap(NotificationPayload payload) {
    debugPrint('🎯 _handleNotificationTap called');
    debugPrint('Context available: ${navigatorKey.currentContext != null}');
    debugPrint('Mounted: $mounted');

    final context = navigatorKey.currentContext;
    if (context == null || !mounted) {
      debugPrint('⚠️ Cannot handle tap - context not available or not mounted');
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && navigatorKey.currentContext != null) {
          debugPrint('🔄 Retrying notification tap handling...');
          _handleNotificationTap(payload);
        }
      });
      return;
    }

    final type = payload.type.toLowerCase();
    debugPrint('📱 Handling notification tap - Type: $type');

    switch (type) {
      case 'like':
      case 'comment':
      case 'vote':
        final postId = payload.data['post_id'];
        debugPrint('Post ID: $postId');

        if (postId != null) {
          // Convert to int if it's a string
          final postIdInt = postId is int
              ? postId
              : int.tryParse(postId.toString());

          if (postIdInt != null) {
            debugPrint(
              '📝 Navigating to NotificationDetails with postId: $postIdInt',
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationDetails(postId: postIdInt),
              ),
            );
          } else {
            debugPrint('⚠️ Invalid post_id, going to notifications tab');
            _navigateToNotificationScreen(context);
          }
        } else {
          debugPrint('⚠️ Missing post_id, going to notifications tab');
          _navigateToNotificationScreen(context);
        }
        break;

      case 'follow':
        final userId = payload.data['sender_id'];
        debugPrint('👤 Follow notification - User ID: $userId');

        if (userId != null) {
          // Convert to int if it's a string
          final userIdInt = userId is int
              ? userId
              : int.tryParse(userId.toString());

          if (userIdInt != null) {
            debugPrint(
              '👤 Navigating to PublicProfile with userId: $userIdInt',
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PublicProfile(userId: userIdInt),
              ),
            );
          } else {
            debugPrint('⚠️ Invalid user_id, going to notifications tab');
            _navigateToNotificationScreen(context);
          }
        } else {
          debugPrint('⚠️ Missing user_id, going to notifications tab');
          _navigateToNotificationScreen(context);
        }
        break;

      case 'post':
      case 'new_message':
      case 'chat':
      case 'notification':
      default:
        debugPrint('🔔 Redirecting to notifications tab for type: $type');
        _navigateToNotificationScreen(context);
        break;
    }
  }

  void _navigateToNotificationScreen(BuildContext context) {
    debugPrint('📲 Navigating to notification screen (tab index 3)');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(initialIndex: 3),
        settings: const RouteSettings(name: '/notifications'),
      ),
      (route) => false,
    );
  }

  void _initializeDeepLinking() {
    DeepLinkService().initialize(
      onPostLinkReceived: (username, postId) {
        debugPrint('🔗 Deep link - Username: $username, PostId: $postId');

        if (_isAppInitialized) {
          _navigateToPostDetail(username, postId);
        } else {
          setState(() {
            _pendingUsername = username;
            _pendingPostId = postId;
          });
        }
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

  void _handlePendingDeepLink() {
    if (_pendingUsername != null && _pendingPostId != null) {
      final username = _pendingUsername!;
      final postId = _pendingPostId!;

      setState(() {
        _pendingUsername = null;
        _pendingPostId = null;
      });

      _navigateToPostDetail(username, postId);
    }
  }

  void _handlePendingNotification() {
    final message = NotificationService().pendingInitialMessage;
    if (message != null) {
      debugPrint('🚀 ===== HANDLING PENDING NOTIFICATION =====');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Data: ${message.data}');
      debugPrint('==========================================');

      final payload = NotificationPayload.fromFCM(message);

      // When app opens from terminated state, handle the notification
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          debugPrint('🎯 Processing pending notification tap...');
          _handleNotificationTap(payload);
        }
      });
    } else {
      debugPrint('ℹ️ No pending notification from terminated state');
    }
  }

  Future<Widget> _getInitialScreen() async {
    final bool isUserLoggedIn = await isLoggedIn();

    if (!isUserLoggedIn) {
      return SplashScreen(isLogged: false);
    }

    final bool isBiometricEnabled = await BiometricService.isBiometricEnabled();

    if (!isBiometricEnabled) {
      return SplashScreen(isLogged: true);
    }

    final bool isPinSecurityEnabled = await PinService.isPinSecurityEnabled();
    final bool isFingerprintEnabled =
        await BiometricService.isFingerprintEnabled();

    if (isPinSecurityEnabled) {
      final bool isPinSet = await PinService.isPinSet();
      if (isPinSet) {
        return const PinGateScreen();
      }
    }

    if (isFingerprintEnabled) {
      final bool isBiometricAvailable =
          await BiometricService.isBiometricAvailable();
      if (isBiometricAvailable) {
        return const BiometricGateScreen();
      }
    }

    return SplashScreen(isLogged: true);
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
        home: FutureBuilder<Widget>(
          future: _getInitialScreen(),
          builder: (context, asyncSnapshot) {
            if (asyncSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Theme.of(context).colorScheme.background,
                body: const Center(child: CircularProgressIndicator()),
              );
            } else if (asyncSnapshot.hasError) {
              return SplashScreen(isLogged: false);
            } else {
              if (!_isAppInitialized) {
                _isAppInitialized = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handlePendingDeepLink();
                  _handlePendingNotification();
                });
              }
              return asyncSnapshot.data ?? SplashScreen(isLogged: false);
            }
          },
        ),
      ),
    );
  }
}
