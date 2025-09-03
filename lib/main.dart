import 'dart:io';
import 'package:catharsis_cards/provider/auth_provider.dart';
import 'package:catharsis_cards/provider/theme_provider.dart'; // Add this import
import 'package:catharsis_cards/provider/user_profile_provider.dart';
import 'package:catharsis_cards/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';


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


Future<void> _initAdsAndroid() async {
  // Initialize the Mobile Ads SDK (Android only)
  await MobileAds.instance.initialize();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase BEFORE anything else
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notifications (Awesome Notifications)
  await NotificationService.init();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(QuestionAdapter());

  if (Platform.isAndroid) {
    await _initAdsAndroid();
  }

  // Handle Firebase Dynamic Links
  final PendingDynamicLinkData? initialLink =
      await FirebaseDynamicLinks.instance.getInitialLink();

  if (initialLink != null) {
    final Uri deepLink = initialLink.link;
    print("Initial deep link: $deepLink");
    // Handle deep link if necessary
  }

  FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
    print("Dynamic link received: ${dynamicLinkData.link}");
    // Handle link when app is open
  }).onError((error) {
    print('Error receiving dynamic link: $error');
  });

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
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _appStateNotifier = AppStateNotifier.instance;
    _router = app_router.createRouter(_appStateNotifier, ref);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme provider instead of using the old theme mode
    final themeState = ref.watch(themeProvider);

    // Auth state listener with proper cleanup
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      final previousUser = previous?.whenOrNull(data: (user) => user);
      final currentUser = next.whenOrNull(data: (user) => user);
      
      // Handle logout scenario
      if (previousUser != null && currentUser == null) {
        // User logged out - invalidate providers after navigation
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            // Invalidate providers to force fresh state on next login
            ref.invalidate(userProfileProvider);
            ref.invalidate(cardStateProvider);
            ref.invalidate(tutorialProvider);
          }
        });
      }
      
      // Always refresh router
      _router.refresh();
    });

    // Tutorial state listener
    ref.listen<TutorialState>(tutorialProvider, (previous, next) {
      _router.refresh();
    });

    return MaterialApp.router(
      title: 'CatharsisCards',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      // Use the theme from your custom theme provider
      theme: themeState.themeData,
      darkTheme: themeState.themeData, // You can also set a specific dark theme here if needed
      themeMode: ThemeMode.light, // Let your custom provider handle the theme switching
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

class DebugUtils {
  static Future<void> printAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    print('=== SharedPreferences Debug ===');
    print('Total keys: ${keys.length}');
    
    for (final key in keys) {
      final value = prefs.get(key);
      print('$key: $value');
    }
    print('==============================');
  }
  
  static Future<void> printTutorialStateForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'has_seen_tutorial_$userId';
    final value = prefs.getBool(key);
    
    print('=== Tutorial State Debug ===');
    print('User ID: $userId');
    print('Key: $key');
    print('Value: $value');
    print('===========================');
  }
  
  static Future<void> clearAllTutorialStates() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith('has_seen_tutorial_')) {
        await prefs.remove(key);
        print('Removed: $key');
      }
    }
  }
}
