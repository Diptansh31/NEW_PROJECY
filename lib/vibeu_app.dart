import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'auth/firebase_auth_controller.dart';
import 'social/firestore_social_graph_controller.dart';
import 'chat/firestore_chat_controller.dart';
import 'notifications/firestore_notifications_controller.dart';
import 'posts/firestore_posts_controller.dart';

class VibeUApp extends StatefulWidget {
  const VibeUApp({super.key});

  @override
  State<VibeUApp> createState() => _VibeUAppState();
}

class _VibeUAppState extends State<VibeUApp> {
  final _auth = FirebaseAuthController();
  final _social = FirestoreSocialGraphController();
  late final _chat = FirestoreChatController(auth: _auth);
  final _notifications = FirestoreNotificationsController();
  final _posts = FirestorePostsController();

  @override
  Widget build(BuildContext context) {
    // Dating-app-adjacent palette: vibrant purple base + warm rose accent.
    // Goal: "matching" vibe without looking like a Tinder clone.
    const seed = Color(0xFF7C3AED); // violet
    const rose = Color(0xFFFF4D8D); // warm pink/rose
    const mint = Color(0xFF22C55E); // positive/confirm

    final light = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      secondary: rose,
      tertiary: mint,
      surface: const Color(0xFFFFFBFF),
      surfaceContainerHighest: const Color(0xFFF4F0FF),
    );

    final dark = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: rose,
      tertiary: mint,
      surface: const Color(0xFF120B1F),
      surfaceContainerHighest: const Color(0xFF221338),
    );

    ThemeData baseTheme(ColorScheme scheme) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: scheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: scheme.surface,
          indicatorColor: scheme.primary.withValues(alpha: 0.14),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: scheme.outlineVariant),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: BorderSide(color: scheme.outlineVariant),
          labelStyle: TextStyle(color: scheme.onSurface),
          secondaryLabelStyle: TextStyle(color: scheme.onSecondary),
          selectedColor: scheme.secondary.withValues(alpha: 0.22),
        ),
      );
    }

    return MaterialApp(
      title: 'vibeU',
      debugShowCheckedModeBanner: false,
      theme: baseTheme(light),
      darkTheme: baseTheme(dark),
      themeMode: ThemeMode.system,
      home: AuthGate(controller: _auth, social: _social, chat: _chat, notifications: _notifications, posts: _posts),
    );
  }
}
