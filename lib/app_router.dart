import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/pages/auth/login_page.dart';
import 'pages/home_page/home_page_widget.dart';
import 'pages/profile/profile_page.dart';
import 'pages/welcome_screen/welcome_screen.dart';
import 'main.dart';
import 'provider/tutorial_state_provider.dart';

GoRouter createRouter(AppStateNotifier appStateNotifier, WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: appStateNotifier,
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/login',
        name: 'LoginPage',
        builder: (context, state) => LoginPage(),
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Check if user has seen welcome screen
            final tutorialState = ref.read(tutorialProvider);
            if (!tutorialState.hasSeenWelcome) {
              return '/welcome';
            }
            return '/home';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/welcome',
        name: 'WelcomeScreen',
        builder: (context, state) => const WelcomeScreen(),
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return '/login';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/home',
        name: 'HomePage',
        builder: (context, state) => NavBarPage(initialPage: 'HomePage'),
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return '/login';
          }
          
          // Check if user has seen welcome screen
          final tutorialState = ref.read(tutorialProvider);
          if (!tutorialState.hasSeenWelcome) {
            return '/welcome';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'ProfilePage',
        builder: (context, state) => NavBarPage(initialPage: 'ProfilePage'),
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return '/login';
          }
          return null;
        },
      ),
    ],
  );
}