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
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ), // Loading screen while determining where to go
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          print('Root redirect - User: ${user?.email}, Path: ${state.matchedLocation}');
          
          if (user == null) {
            return '/login';
          }
          
          // User is logged in, check if they've seen welcome
          final tutorialState = ref.read(tutorialProvider);
          print('Tutorial state - hasSeenWelcome: ${tutorialState.hasSeenWelcome}, isInitialized: ${tutorialState.isInitialized}');
          
          // Wait for tutorial state to initialize
          if (!tutorialState.isInitialized) {
            print('Tutorial state not initialized, waiting...');
            // Schedule a refresh after a delay
            Future.delayed(Duration(milliseconds: 100), () {
              ref.invalidate(tutorialProvider);
            });
            return null; // Stay on loading screen
          }
          
          if (!tutorialState.hasSeenWelcome) {
            print('User has not seen welcome, redirecting to /welcome');
            return '/welcome';
          }
          
          print('User has seen welcome, redirecting to /home');
          return '/home';
        },
      ),
      GoRoute(
        path: '/login',
        name: 'LoginPage',
        builder: (context, state) => LoginPage(),
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          print('Login redirect - User: ${user?.email}');
          
          if (user != null) {
            // User is already logged in
            final tutorialState = ref.read(tutorialProvider);
            
            // Wait for tutorial state to initialize
            if (!tutorialState.isInitialized) {
              print('Tutorial not initialized on login redirect, scheduling recheck');
              Future.delayed(Duration(milliseconds: 100), () {
                ref.invalidate(tutorialProvider);
                ref.read(tutorialProvider.notifier).checkIfTutorialSeen();
              });
              return null;
            }
            
            print('Login redirect - hasSeenWelcome: ${tutorialState.hasSeenWelcome}');
            if (!tutorialState.hasSeenWelcome) {
              return '/welcome';
            }
            return '/home';
          }
          return null; // Stay on login page
        },
      ),
      GoRoute(
        path: '/welcome',
        name: 'WelcomeScreen',
        builder: (context, state) => const WelcomeScreen(),
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          print('Welcome redirect - User: ${user?.email}');
          
          if (user == null) {
            return '/login';
          }
          
          // Check if they've already seen welcome
          final tutorialState = ref.read(tutorialProvider);
          if (tutorialState.isInitialized && tutorialState.hasSeenWelcome) {
            print('Welcome redirect - User has already seen welcome, redirecting to home');
            return '/home';
          }
          
          return null; // Stay on welcome screen
        },
      ),
      GoRoute(
        path: '/home',
        name: 'HomePage',
        builder: (context, state) => NavBarPage(initialPage: 'HomePage'),
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          print('Home redirect - User: ${user?.email}');
          
          if (user == null) {
            return '/login';
          }
          
          // Check if user has seen welcome screen
          final tutorialState = ref.read(tutorialProvider);
          
          // Wait for tutorial state to initialize
          if (!tutorialState.isInitialized) {
            return null;
          }
          
          print('Home redirect - hasSeenWelcome: ${tutorialState.hasSeenWelcome}');
          if (!tutorialState.hasSeenWelcome) {
            return '/welcome';
          }
          return null; // Stay on home
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
          
          // Also check welcome screen for profile
          final tutorialState = ref.read(tutorialProvider);
          
          // Wait for tutorial state to initialize
          if (!tutorialState.isInitialized) {
            return null;
          }
          
          if (!tutorialState.hasSeenWelcome) {
            return '/welcome';
          }
          return null;
        },
      ),
    ],
  );
}