// ignore_for_file: unused_field, deprecated_member_use, unused_element, library_private_types_in_public_api
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/services/notification/notification_services.dart';
import 'core/constants/app_strings.dart';
import 'core/themes/app_themes.dart';
import 'core/themes/theme_provider.dart';
import 'data/token/shared_preferences.dart';
import 'firebase_options.dart'; // Import this
import 'l10n/generated/app_localizations.dart';
import 'provider/public_profile_provider.dart';
import 'provider/user_provider.dart';
import 'screens/home/settings/security/biometric/biometric_screen.dart';
import 'screens/home/settings/security/biometric/biometric_service.dart';
import 'screens/home/settings/security/pin/pin_gate_screen.dart';
import 'screens/home/settings/security/pin/pin_status.dart';
import 'screens/splash/splash_screen.dart';

// Created by -- Dev.Pratik Patadiya on 27/03/2025
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with proper error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize notification service after Firebase
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
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

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
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

  Future<Widget> _getInitialScreen() async {
    // Check if user is logged in
    final bool isUserLoggedIn = await isLoggedIn();

    if (!isUserLoggedIn) {
      // User not logged in, go to splash screen
      return SplashScreen(isLogged: false);
    }

    // User is logged in, check security settings
    final bool isBiometricEnabled = await BiometricService.isBiometricEnabled();

    // Check if main security is enabled
    if (!isBiometricEnabled) {
      // No security enabled, proceed to main app
      return SplashScreen(isLogged: true);
    }

    // Security is enabled, check which type
    final bool isPinSecurityEnabled = await PinService.isPinSecurityEnabled();
    final bool isFingerprintEnabled =
        await BiometricService.isFingerprintEnabled();

    // Priority: PIN Security > Fingerprint Security
    if (isPinSecurityEnabled) {
      // Check if PIN is actually set
      final bool isPinSet = await PinService.isPinSet();

      if (isPinSet) {
        // Show PIN gate screen
        return PinGateScreen();
      }
    }

    // Check fingerprint security
    if (isFingerprintEnabled) {
      // Check if biometric is available on device
      final bool isBiometricAvailable =
          await BiometricService.isBiometricAvailable();

      if (isBiometricAvailable) {
        // Show biometric gate screen for authentication
        return BiometricGateScreen();
      }
    }

    // No valid security method enabled or available, proceed to main app
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
        locale: _locale,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('ar'), // Arabic
          Locale('en'), // English
          Locale('de'), // German
          Locale('hi'), // Hindi
          Locale('id'), // Indonesian
          Locale('es'), // Spanish
          Locale('vi'), // Vietnamese
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
              return asyncSnapshot.data ?? SplashScreen(isLogged: false);
            }
          },
        ),
      ),
    );
  }
}