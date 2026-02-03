import 'package:flutter/material.dart';

import '../ui/app_shell.dart';
import 'firebase_auth_controller.dart';
import '../ui/auth/login_page.dart';

import '../social/firestore_social_graph_controller.dart';

import '../chat/firestore_chat_controller.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.controller, required this.social, required this.chat});

  final FirebaseAuthController controller;
  final FirestoreSocialGraphController social;
  final FirestoreChatController chat;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final fbUser = controller.firebaseUser;
        if (fbUser == null) {
          return LoginPage(controller: controller);
        }

        return FutureBuilder(
          future: controller.getCurrentProfile(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Failed to load profile: ${snapshot.error}'));
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snapshot.data;
            if (profile == null) {
              return const Center(child: Text('Profile not found in Firestore.'));
            }

            return AppShell(
              signedInUid: fbUser.uid,
              signedInEmail: profile.email,
              onSignOut: () => controller.signOut(),
              auth: controller,
              social: social,
              chat: chat,
            );
          },
        );
      },
    );
  }
}
