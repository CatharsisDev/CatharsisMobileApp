import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/auth_provider.dart';
import '../../pages/auth/login_page.dart';
import '../../main.dart';
import '../flutter_flow_theme.dart';
import '../../pages/profile/profile_page.dart';

const kTransitionInfoKey = '__transition_info__';

class AppStateNotifier extends ChangeNotifier {
  static final AppStateNotifier _instance = AppStateNotifier._internal();

  AppStateNotifier._internal();

  static AppStateNotifier get instance => _instance;

  bool showSplashImage = true;

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier, WidgetRef ref) => GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  refreshListenable: appStateNotifier,
  routes: [
    GoRoute(
      name: '_initialize',
      path: '/',
      builder: (context, state) => const LoadingScreen(),
    ),
    GoRoute(
      name: 'Login',
      path: '/login',
      builder: (context, state) => LoginPage(),
    ),
    GoRoute(
      name: 'HomePage',
      path: '/home',
      builder: (context, state) => NavBarPage(),
    ),
    GoRoute(
      name: 'LikedCards',
      path: '/liked',
      builder: (context, state) => NavBarPage(initialPage: 'LikedCards'),
    ),
    GoRoute(
      name: 'ProfilePage',
      path: '/profile',
      builder: (context, state) => const ProfilePageWidget(),
    ),
  ],
  redirect: (context, state) {
    print('Current path: ${state.matchedLocation}');
    final container = ProviderScope.containerOf(context);
    final authState = container.read(authStateProvider);
    
    return authState.when(
      data: (user) {
        print('User: ${user?.email ?? "null"}');
        print('Auth data loaded, path: ${state.matchedLocation}');
        
        if (state.matchedLocation == '/') {
          final destination = user != null ? '/home' : '/login';
          print('Redirecting from / to $destination');
          return destination;
        }
        
        final isLoggedIn = user != null;
        final isLoginRoute = state.matchedLocation == '/login';
        
        if (!isLoggedIn && !isLoginRoute) {
          print('Not logged in, redirecting to login');
          return '/login';
        }
        if (isLoggedIn && isLoginRoute) {
          print('Already logged in, redirecting to home');
          return '/home';
        }
        
        print('No redirect needed');
        return null;
      },
      loading: () {
        print('Auth loading...');
        return null;
      },
      error: (err, stack) {
        print('Auth error: $err');
        print('Stack: $stack');
        return state.matchedLocation == '/' ? '/login' : null;
      },
    );
  },
);

class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Force navigation after a delay if auth doesn't resolve
    Future.delayed(Duration(seconds: 3), () {
      if (context.mounted) {
        context.go('/login');
      }
    });
    
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: Center(
        child: CircularProgressIndicator(
          color: FlutterFlowTheme.of(context).primary,
        ),
      ),
    );
  }
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  bool get hasFutures => asyncParams.isNotEmpty;

  Future completeFutures() => Future.wait(
        asyncParams.entries.map(
          (param) => param.value(state.pathParameters[param.key] ?? '')
              .then((value) => futureParamValues[param.key] = value),
        ),
      );
}

enum PageTransitionType {
  fade,
  slide,
  scale,
  rotation,
  size,
  rightToLeft,
  leftToRight,
  topToBottom,
  bottomToTop,
}

class PageTransition<T> extends PageRouteBuilder<T> {
  PageTransition({
    required this.child,
    required this.type,
    this.curve = Curves.ease,
    this.alignment,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 300),
    this.fullscreenDialog = false,
    this.opaque = true,
    this.isIos = false,
    this.matchingBuilder,
  }) : super(
          pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) {
            return child;
          },
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          fullscreenDialog: fullscreenDialog,
          opaque: opaque,
          transitionsBuilder: (BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child) {
            switch (type) {
              case PageTransitionType.fade:
                return FadeTransition(opacity: animation, child: child);
              case PageTransitionType.slide:
              case PageTransitionType.rightToLeft:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              case PageTransitionType.leftToRight:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1.0, 0.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              case PageTransitionType.topToBottom:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, -1.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              case PageTransitionType.bottomToTop:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              case PageTransitionType.scale:
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              case PageTransitionType.rotation:
                return RotationTransition(
                  turns: animation,
                  child: child,
                );
              case PageTransitionType.size:
                return Align(
                  alignment: alignment ?? Alignment.center,
                  child: SizeTransition(
                    sizeFactor: animation,
                    child: child,
                  ),
                );
              default:
                return FadeTransition(opacity: animation, child: child);
            }
          },
        );

  final Widget child;
  final PageTransitionType type;
  final Curve curve;
  final Alignment? alignment;
  final Duration duration;
  final Duration reverseDuration;
  final bool fullscreenDialog;
  final bool opaque;
  final bool isIos;
  final Widget Function(Animation<double>, Animation<double>, Widget)?
      matchingBuilder;
}