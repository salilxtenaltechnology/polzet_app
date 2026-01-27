// ignore_for_file: unused_field, deprecated_member_use, unused_element, library_private_types_in_public_api
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/services/fcm/fcm_service.dart';
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
import 'screens/home/settings/security/biometric/biometric_screen.dart';
import 'screens/home/settings/security/biometric/biometric_service.dart';
import 'screens/home/settings/security/pin/pin_gate_screen.dart';
import 'screens/home/settings/security/pin/pin_status.dart';
import 'screens/splash/splash_screen.dart';

// ✅ Background message handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint("🔔 ===== BACKGROUND MESSAGE =====");
  debugPrint("Title: ${message.notification?.title}");
  debugPrint("Body: ${message.notification?.body}");
  debugPrint("Data: ${message.data}");
  debugPrint("================================");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
  OverlayEntry? _notificationOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLanguage();
    _initializeDeepLinking();
    _setupNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeNotificationOverlay();
    DeepLinkService().dispose();
    NotificationService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed');
        _reconnectWebSocketIfNeeded();
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 App paused');
        _removeNotificationOverlay();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
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

  Future<void> _setupNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));

    NotificationService().onNotificationReceived = (payload) {
      _showNotificationPopup(payload);
    };

    NotificationService().onFCMMessageTap = (payload) {
      _handleNotificationTap(payload);
    };

    final loggedIn = await isLoggedIn();
    if (loggedIn) {
      await _connectWebSocket();
      await _registerFCMToken();
    }
  }

  Future<void> _registerFCMToken() async {
    try {
      final fcmToken = await NotificationService().getFCMToken();
      if (fcmToken != null) {
        String platform = Platform.isAndroid ? 'android' : 'ios';
        await FcmApiService.registerFcmToken(fcmToken, platform);
        await SharedPrefService.saveFcmToken(fcmToken);
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
    }
  }

  Future<void> _connectWebSocket() async {
    final accessToken = await SharedPrefService.getAccessToken();
    if (accessToken != null) {
      debugPrint('🔌 Connecting to WebSocket...');
      await NotificationService().connectToWebSocket(accessToken);
    }
  }

  Future<void> _reconnectWebSocketIfNeeded() async {
    final loggedIn = await isLoggedIn();
    if (loggedIn && !NotificationService().isWebSocketConnected) {
      debugPrint('🔄 Reconnecting WebSocket...');
      await _connectWebSocket();
    }
  }

  void _showNotificationPopup(NotificationPayload payload) {
    _removeNotificationOverlay();

    final context = navigatorKey.currentContext;
    if (context == null || !mounted) return;

    _notificationOverlay = OverlayEntry(
      builder: (context) => NotificationPopup(
        payload: payload,
        onTap: () {
          _removeNotificationOverlay();
          _handleNotificationTap(payload);
        },
        onDismiss: _removeNotificationOverlay,
      ),
    );

    Overlay.of(context).insert(_notificationOverlay!);

    Future.delayed(const Duration(seconds: 4), () {
      _removeNotificationOverlay();
    });
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  void _handleNotificationTap(NotificationPayload payload) {
    final context = navigatorKey.currentContext;
    if (context == null || !mounted) return;

    final type = payload.type.toLowerCase();

    switch (type) {
      case 'post':
      case 'like':
      case 'comment':
        final postId = payload.data['post_id'];
        final username = payload.data['username'];
        if (postId != null && username != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PostDetailScreen(username: username, postId: postId),
            ),
          );
        }
        break;

      case 'follow':
        final userId = payload.data['user_id'];
        debugPrint('Navigate to profile: $userId');
        break;

      case 'new_message':
      case 'chat':
        final chatId = payload.data['chat_id'];
        final senderId = payload.data['sender_id'];
        debugPrint('Navigate to chat: $chatId from sender: $senderId');
        break;

      default:
        debugPrint('Unknown notification type: ${payload.type}');
    }
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

class NotificationPopup extends StatefulWidget {
  final NotificationPayload payload;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationPopup({
    super.key,
    required this.payload,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends State<NotificationPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'post':
        return Icons.article;
      case 'new_message':
      case 'chat':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'like':
        return Colors.pink;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return Colors.purple;
      case 'post':
        return Colors.orange;
      case 'new_message':
      case 'chat':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForType(widget.payload.type);
    final icon = _getIconForType(widget.payload.type);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  _dismiss();
                  widget.onTap();
                },
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity!.abs() > 100) {
                    _dismiss();
                  }
                },
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [Colors.white, color.withOpacity(0.05)],
                      ),
                      border: Border.all(
                        color: color.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.payload.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          widget.payload.source ==
                                              NotificationSource.webSocket
                                          ? Colors.blue[100]
                                          : Colors.green[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.payload.source ==
                                              NotificationSource.webSocket
                                          ? 'LIVE'
                                          : 'PUSH',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            widget.payload.source ==
                                                NotificationSource.webSocket
                                            ? Colors.blue[900]
                                            : Colors.green[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.payload.body,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
