/// Akashi — Entry Point
/// Mobile app for Bangladeshi farmers: satellite-powered crop health monitoring.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/config/app_config.dart';
import 'core/theme/theme.dart';
import 'core/l10n/bn_strings.dart';
import 'providers/auth_provider.dart';
import 'providers/farmer_provider.dart';
import 'providers/field_provider.dart';
import 'providers/weather_provider.dart';
import 'screens/splash_screen.dart';

/// FCM background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are processed silently — no UI interaction here
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── System UI ──────────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFEAEEF7),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ─── Firebase ───────────────────────────────────────────────────────────
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ─── Supabase ───────────────────────────────────────────────────────────
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const AkashiApp());
}

class AkashiApp extends StatelessWidget {
  const AkashiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FarmerProvider()),
        ChangeNotifierProvider(create: (_) => FieldProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
      ],
      child: MaterialApp(
        title: BnStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AkashiTheme.light,

        // ─── Bengali locale support ──────────────────────────────────────
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('bn', 'BD'), // Bengali — Bangladesh
          Locale('en', 'US'), // English fallback
        ],
        locale: const Locale('bn', 'BD'),

        home: const SplashScreen(),
      ),
    );
  }
}
