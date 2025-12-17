import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'main_navigation.dart';
import 'welcome_screen.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // RUN MIGRATION - Comment this line after migration is complete
  // await runMigration();
  
  await _ensureAnonymousSignIn();
  cameras = await availableCameras();
  runApp(const MyApp());
}

Future<void> _ensureAnonymousSignIn() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) {
    return;
  }
  try {
    await auth.signInAnonymously().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Anonymous auth failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saudi Dates Classifier',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF8B4513),
          secondary: const Color(0xFFD2691E),
          tertiary: const Color(0xFFDEB887),
          surface: const Color(0xFFFFF8DC),
          surfaceContainerHighest: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onSurfaceVariant: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8DC),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF8B4513),
          elevation: 2,
          centerTitle: true,
          titleTextStyle: GoogleFonts.playfair(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B4513),
            foregroundColor: Colors.white,
            elevation: 3,
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textTheme: GoogleFonts.robotoTextTheme().copyWith(
          titleLarge: GoogleFonts.playfair(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8B4513),
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ),
      home: WelcomeScreen(cameras: cameras),
    );
  }
}
