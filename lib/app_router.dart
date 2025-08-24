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
import 'provider/auth_provider.dart';

GoRouter createRouter(AppStateNotifier appStateNotifier, WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: appStateNotifier,
    routes: [
      // Loader page to avoid race conditions
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        redirect: (context, state) async {
          final authState = ref.read(authStateProvider);
          final user = authState.whenOrNull(data: (user) => user);

          // Not logged in? Go to login.
          if (user == null) return '/login';

          // Wait until tutorial state is loaded
          final tutorialState = ref.read(tutorialProvider);
          if (!tutorialState.isInitialized || tutorialState.isLoading) {
            return null; // Stay on splash until ready
          }

          // Go to correct next page
          return tutorialState.hasSeenWelcome ? '/home' : '/welcome';
        },
      ),
      GoRoute(
        path: '/login',
        name: 'LoginPage',
        builder: (context, state) => LoginPage(),
        redirect: (context, state) async {
          final authState = ref.read(authStateProvider);
          final user = authState.whenOrNull(data: (user) => user);

          // Already logged in? Check tutorial state
          if (user != null) {
            final tutorialState = ref.read(tutorialProvider);
            if (!tutorialState.isInitialized || tutorialState.isLoading) {
              return null; // Wait for state, stay here
            }
            return tutorialState.hasSeenWelcome ? '/home' : '/welcome';
          }

          return null; // Stay on login page
        },
      ),
      GoRoute(
        path: '/welcome',
        name: 'WelcomeScreen',
        builder: (context, state) => const WelcomeScreen(),
        redirect: (context, state) async {
          final authState = ref.read(authStateProvider);
          final user = authState.whenOrNull(data: (user) => user);
          if (user == null) return '/login';

          final tutorialState = ref.read(tutorialProvider);
          if (!tutorialState.isInitialized || tutorialState.isLoading) {
            return null; // Wait for state, stay here
          }
          if (tutorialState.hasSeenWelcome) return '/home';
          return null; // Stay on welcome screen
        },
      ),
      GoRoute(
        path: '/home',
        name: 'HomePage',
        builder: (context, state) => NavBarPage(initialPage: 'HomePage'),
        redirect: (context, state) async {
          final authState = ref.read(authStateProvider);
          final user = authState.whenOrNull(data: (user) => user);
          if (user == null) return '/login';

          final tutorialState = ref.read(tutorialProvider);
          if (!tutorialState.isInitialized || tutorialState.isLoading) {
            return null; // Wait for state, stay here
          }
          if (!tutorialState.hasSeenWelcome) return '/welcome';
          return null; // Stay on home
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'ProfilePage',
        builder: (context, state) => NavBarPage(initialPage: 'ProfilePage'),
        redirect: (context, state) async {
          final authState = ref.read(authStateProvider);
          final user = authState.whenOrNull(data: (user) => user);
          if (user == null) return '/login';

          final tutorialState = ref.read(tutorialProvider);
          if (!tutorialState.isInitialized || tutorialState.isLoading) {
            return null; // Wait for state, stay here
          }
          if (!tutorialState.hasSeenWelcome) return '/welcome';
          return null;
        },
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) {
          // Handle the OAuth callback and redirect to home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/home');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    ],
  );
}