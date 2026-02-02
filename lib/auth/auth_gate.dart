import 'package:flutter/material.dart';

import '../ui/app_shell.dart';
import 'local_auth_controller.dart';
import '../ui/auth/login_page.dart';

import '../social/social_graph_controller.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.controller, required this.social});

  final LocalAuthController controller;
  final SocialGraphController social;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final user = controller.currentUser;
        if (user == null) {
          return LoginPage(controller: controller);
        }

        return AppShell(
          signedInEmail: user.email,
          onSignOut: controller.signOut,
          auth: controller,
          social: social,
        );
      },
    );
  }
}
