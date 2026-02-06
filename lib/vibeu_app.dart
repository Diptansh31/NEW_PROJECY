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
  late final _chat = FirestoreChatController(auth: _auth);
  late final _social = FirestoreSocialGraphController(chat: _chat);
  final _notifications = FirestoreNotificationsController();
  final _posts = FirestorePostsController();

  @override
  Widget build(BuildContext context) {
    // 💕 Modern Love Theme - Bold Pink/Rose Dating App Style
    // Inspired by Tinder, Bumble with romantic pink tones
    
    // Primary colors
    const loveRose = Color(0xFFFF4B6E);      // Main pink/rose - passionate
    const loveCoral = Color(0xFFFF6B8A);     // Lighter coral pink
    const loveDeep = Color(0xFFE91E63);      // Deep pink for accents
    const loveLight = Color(0xFFFFB6C1);     // Light pink for backgrounds
    
    // Supporting colors
    const heartRed = Color(0xFFFF5252);      // For hearts/likes
    const successGreen = Color(0xFF4CAF50);  // Match success
    const goldStar = Color(0xFFFFD700);      // Super like/premium

    final light = ColorScheme.fromSeed(
      seedColor: loveRose,
      brightness: Brightness.light,
      primary: loveRose,
      secondary: loveCoral,
    ).copyWith(
      primary: loveRose,
      onPrimary: Colors.white,
      secondary: loveCoral,
      tertiary: successGreen,
      error: heartRed,
      surface: const Color(0xFFFFFBFC),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFFF5F7),
      surfaceContainer: const Color(0xFFFFF0F3),
      surfaceContainerHigh: const Color(0xFFFFE8EC),
      surfaceContainerHighest: const Color(0xFFFFE0E6),
      outline: const Color(0xFFFFB6C1),
      outlineVariant: const Color(0xFFFFD6DD),
    );

    final dark = ColorScheme.fromSeed(
      seedColor: loveRose,
      brightness: Brightness.dark,
      primary: loveRose,
      secondary: loveCoral,
    ).copyWith(
      primary: loveRose,
      onPrimary: Colors.white,
      secondary: loveCoral,
      tertiary: successGreen,
      error: heartRed,
      surface: const Color(0xFF1A1118),
      surfaceContainerLowest: const Color(0xFF120B0F),
      surfaceContainerLow: const Color(0xFF1F141A),
      surfaceContainer: const Color(0xFF261A20),
      surfaceContainerHigh: const Color(0xFF2D1F26),
      surfaceContainerHighest: const Color(0xFF382830),
      outline: const Color(0xFF6D4A55),
      outlineVariant: const Color(0xFF4A3038),
    );

    ThemeData baseTheme(ColorScheme scheme) {
      final isLight = scheme.brightness == Brightness.light;
      
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        
        // AppBar - Clean with subtle love accent
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: loveRose.withValues(alpha: 0.05),
          titleTextStyle: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: scheme.primary),
        ),
        
        // Cards - Rounded with soft shadows
        cardTheme: CardThemeData(
          elevation: isLight ? 2 : 0,
          shadowColor: loveRose.withValues(alpha: 0.15),
          color: scheme.surfaceContainerLow,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        
        // Navigation Bar - With love accent indicator
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: scheme.surface,
          elevation: 0,
          height: 70,
          indicatorColor: loveRose.withValues(alpha: 0.15),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: loveRose, size: 26);
            }
            return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: loveRose,
              );
            }
            return TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            );
          }),
        ),
        
        // Filled Buttons - Bold with gradient feel
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: loveRose,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: loveRose.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.3,
            ),
          ),
        ),
        
        // Outlined Buttons - Pink border
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: loveRose,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: loveRose.withValues(alpha: 0.5), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        
        // Text Buttons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: loveRose,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        
        // Elevated Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHigh,
            foregroundColor: loveRose,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        
        // FAB - Love pink
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: loveRose,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        
        // Input Fields - Soft pink accent
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: loveRose, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: heartRed, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
          prefixIconColor: scheme.onSurfaceVariant,
        ),
        
        // Chips - Rounded pills with love colors
        chipTheme: ChipThemeData(
          backgroundColor: scheme.surfaceContainerHigh,
          selectedColor: loveRose.withValues(alpha: 0.2),
          disabledColor: scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          labelStyle: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          secondaryLabelStyle: TextStyle(color: loveRose),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          showCheckmark: true,
          checkmarkColor: loveRose,
        ),
        
        // Dialogs
        dialogTheme: DialogThemeData(
          backgroundColor: scheme.surface,
          elevation: 8,
          shadowColor: loveRose.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        
        // Bottom Sheet
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surface,
          modalBackgroundColor: scheme.surface,
          elevation: 8,
          shadowColor: loveRose.withValues(alpha: 0.2),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          dragHandleColor: scheme.outlineVariant,
          dragHandleSize: const Size(40, 4),
        ),
        
        // Snackbar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: scheme.inverseSurface,
          contentTextStyle: TextStyle(color: scheme.onInverseSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        
        // Divider
        dividerTheme: DividerThemeData(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          thickness: 1,
        ),
        
        // List Tile
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        
        // Icon Theme
        iconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
        
        // Primary Icon Theme
        primaryIconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        
        // Badge Theme
        badgeTheme: BadgeThemeData(
          backgroundColor: heartRed,
          textColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        // Progress Indicator
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: loveRose,
          circularTrackColor: loveRose.withValues(alpha: 0.2),
          linearTrackColor: loveRose.withValues(alpha: 0.2),
        ),
        
        // Switch
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return loveRose;
            return scheme.outline;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return loveRose.withValues(alpha: 0.5);
            }
            return scheme.surfaceContainerHighest;
          }),
        ),
        
        // Checkbox
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return loveRose;
            return Colors.transparent;
          }),
          checkColor: WidgetStatePropertyAll(Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: BorderSide(color: scheme.outline, width: 1.5),
        ),
        
        // Radio
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return loveRose;
            return scheme.outline;
          }),
        ),
        
        // Slider
        sliderTheme: SliderThemeData(
          activeTrackColor: loveRose,
          inactiveTrackColor: loveRose.withValues(alpha: 0.3),
          thumbColor: loveRose,
          overlayColor: loveRose.withValues(alpha: 0.2),
        ),
        
        // Tab Bar
        tabBarTheme: TabBarThemeData(
          labelColor: loveRose,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: loveRose,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
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
