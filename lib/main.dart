import 'package:catharsis_cards/provider/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'questions_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'provider/app_state_provider.dart';
import 'provider/pop_up_provider.dart';
import 'provider/tutorial_state_provider.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';
import '/pages/profile/profile_page.dart';
import '/pages/home_page/home_page_widget.dart';
import 'app_router.dart' as app_router;

class AppStateNotifier extends ChangeNotifier {
  static final AppStateNotifier _instance = AppStateNotifier._internal();
  factory AppStateNotifier() => _instance;
  static AppStateNotifier get instance => _instance;
  
  AppStateNotifier._internal() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      notifyListeners();
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  Hive.registerAdapter(QuestionAdapter());
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  ConsumerState<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends ConsumerState<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _appStateNotifier = AppStateNotifier.instance;
    _router = app_router.createRouter(_appStateNotifier, ref);
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) async {
          final currentLocation =
              _router.routerDelegate.currentConfiguration.fullPath;
          
          if (user != null) {
            // User is logged in
            if (currentLocation == '/login' || currentLocation == '/') {
              // Check if user has seen welcome screen
              final tutorialState = ref.read(tutorialProvider);
              if (!tutorialState.hasSeenWelcome) {
                _router.go('/welcome');
              } else {
                _router.go('/home');
              }
            }
          } else {
            // User is not logged in
            if (currentLocation != '/login' && currentLocation != '/') {
              _router.go('/login');
            }
          }
        },
        loading: () {},
        error: (_, __) => _router.go('/login'),
      );
    });

    // Also listen to tutorial state changes
    ref.listen<TutorialState>(tutorialProvider, (previous, next) {
      final user = FirebaseAuth.instance.currentUser;
      final currentLocation =
          _router.routerDelegate.currentConfiguration.fullPath;
      
      // If user just completed tutorial and is still on welcome screen
      if (user != null && 
          next.hasSeenWelcome && 
          currentLocation == '/welcome') {
        _router.go('/home');
      }
    });

    return MaterialApp.router(
      title: 'CatharsisCards',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

class NavBarPage extends ConsumerStatefulWidget {
  NavBarPage({Key? key, this.initialPage, this.page}) : super(key: key);
  final String? initialPage;
  final Widget? page;

  @override
  ConsumerState<NavBarPage> createState() => _NavBarPageState();
}

class _NavBarPageState extends ConsumerState<NavBarPage> {
  String _currentPageName = 'HomePage';
  late Widget? _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(cardStateProvider);
    final notifier = ref.read(cardStateProvider.notifier);

    final tabs = {
      'HomePage': HomePageWidget(),
      'ProfilePage': ProfilePageWidget(),
    };
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    // Check if current question is liked
    final isCurrentQuestionLiked = cardState.currentQuestion != null &&
        cardState.likedQuestions.any((q) =>
            q.text == cardState.currentQuestion!.text &&
            q.category == cardState.currentQuestion!.category);

    return Scaffold(
      body: Stack(
        children: [
          _currentPage ?? tabs[_currentPageName]!,
          if (_currentPageName == 'HomePage')
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(),
            ),
        ],
      ),
    );
  }
}