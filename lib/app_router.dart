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
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        redirect: (context, state) async {
          // Get auth state
          final authState = ref.read(authStateProvider);
          final user = authState.whenOrNull(data: (user) => user);
          
          print('Root redirect - User: ${user?.email}, Path: ${state.matchedLocation}');
          
          if (user == null) {
            return '/login';
          }
          
          // User is logged in, check tutorial state
          final tutorialState = ref.read(tutorialProvider);
          print('Tutorial state - hasSeenWelcome: ${tutorialState.hasSeenWelcome}, isInitialized: ${tutorialState.isInitialized}, isLoading: ${tutorialState.isLoading}');
          
          // If tutorial state is not ready, wait
          if (!tutorialState.isInitialized || tutorialState.isLoading) {
            print('Tutorial state not ready, waiting...');
            
            // Wait up to 500ms for tutorial state to load
            for (int i = 0; i < 10; i++) {
              await Future.delayed(Duration(milliseconds: 50));
              final updatedState = ref.read(tutorialProvider);
              if (updatedState.isInitialized && !updatedState.isLoading) {
                print('Tutorial state loaded after ${(i + 1) * 50}ms');
                return updatedState.hasSeenWelcome ? '/home' : '/welcome';
              }
            }
            
            // If still not loaded after 500ms, assume welcome already seen
            print('Tutorial state not loaded after timeout, assuming welcome already seen');
            return '/home';
          }
          
          // Tutorial state is ready
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
          
          print('Login redirect - User: ${user?.email}');
          
          if (user != null) {
            // User is already logged in
            final tutorialState = ref.read(tutorialProvider);
            
            // If tutorial state is not ready, wait
            if (!tutorialState.isInitialized || tutorialState.isLoading) {
              print('Tutorial not initialized on login redirect, waiting...');
              
              // Wait up to 500ms for tutorial state to load
              for (int i = 0; i < 10; i++) {
                await Future.delayed(Duration(milliseconds: 50));
                final updatedState = ref.read(tutorialProvider);
                if (updatedState.isInitialized && !updatedState.isLoading) {
                  print('Tutorial state loaded after ${(i + 1) * 50}ms');
                  return updatedState.hasSeenWelcome ? '/home' : '/welcome';
                }
              }
              
              // If still not loaded after timeout, assume welcome already seen
              print('Tutorial state not loaded after timeout on login redirect, assuming welcome already seen');
              return '/home';
            }
            
            print('Login redirect - hasSeenWelcome: ${tutorialState.hasSeenWelcome}');
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
          
          print('Welcome redirect - User: ${user?.email}');
          
          if (user == null) {
            return '/login';
          }
          
          // Check if they've already seen welcome
          final tutorialState = ref.read(tutorialProvider);
          
          // Wait for initialization if needed
          if (!tutorialState.isInitialized || tutorialState.isLoading) {
            print('Tutorial state loading on welcome redirect, waiting...');
            
            // Give it a moment to load
            await Future.delayed(Duration(milliseconds: 200));
            final updatedState = ref.read(tutorialProvider);
            
            if (updatedState.isInitialized && updatedState.hasSeenWelcome) {
              print('User has already seen welcome after load, redirecting to home');
              return '/home';
            }
          } else if (tutorialState.hasSeenWelcome) {
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
        redirect: (context, state) async {
          final authState = ref.read(authStateProvider);
          final user = authState.whenOrNull(data: (user) => user);
          
          print('Home redirect - User: ${user?.email}');
          
          if (user == null) {
            return '/login';
          }
          
          // Check if user has seen welcome screen
          final tutorialState = ref.read(tutorialProvider);
          
          // Wait for tutorial state to initialize
          if (!tutorialState.isInitialized || tutorialState.isLoading) {
            print('Tutorial state not ready on home redirect, waiting...');
            
            await Future.delayed(Duration(milliseconds: 200));
            final updatedState = ref.read(tutorialProvider);
            
            if (updatedState.isInitialized && !updatedState.hasSeenWelcome) {
              print('Tutorial check after wait - user needs to see welcome');
              return '/welcome';
            }
          } else if (!tutorialState.hasSeenWelcome) {
            print('Home redirect - hasSeenWelcome: false, redirecting to welcome');
            return '/welcome';
          }
          
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
          
          if (user == null) {
            return '/login';
          }
          
          // Also check welcome screen for profile
          final tutorialState = ref.read(tutorialProvider);
          
          // Wait for tutorial state to initialize
          if (!tutorialState.isInitialized || tutorialState.isLoading) {
            await Future.delayed(Duration(milliseconds: 200));
            final updatedState = ref.read(tutorialProvider);
            
            if (updatedState.isInitialized && !updatedState.hasSeenWelcome) {
              return '/welcome';
            }
          } else if (!tutorialState.hasSeenWelcome) {
            return '/welcome';
          }
          
          return null;
        },
      ),
    ],
  );
}