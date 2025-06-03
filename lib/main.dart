import 'package:catharsis_cards/questions_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/pop_up_provider.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register the Question adapter
  Hive.registerAdapter(QuestionAdapter());

  // Remove duplicate runApp and only run after initialization
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
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
      'LikedCards': LikedCardsWidget(),
    };
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    // Check if current question is liked
    final isCurrentQuestionLiked = cardState.currentQuestion != null &&
        cardState.likedQuestions.any((q) =>
            q.text == cardState.currentQuestion!.text &&
            q.category == cardState.currentQuestion!.category);

    return Scaffold(
      body: _currentPage ?? tabs[_currentPageName],
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          BottomNavigationBar(
            currentIndex: currentIndex == 0 ? 0 : 2,
            onTap: (i) {
              if (i == 1) return;
              setState(() {
                _currentPage = null;
                _currentPageName = i == 0 ? 'HomePage' : 'LikedCards';
              });
            },
            backgroundColor: Color.fromRGBO(140, 198, 255, 0.7),
            selectedItemColor: Colors.white,
            unselectedItemColor: FlutterFlowTheme.of(context).secondaryText,
            showSelectedLabels: true,
            showUnselectedLabels: false,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.home_outlined,
                  size: 24.0,
                ),
                label: 'Home',
                tooltip: '',
              ),
              BottomNavigationBarItem(
                icon: SizedBox(height: 24),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: FaIcon(
                  FontAwesomeIcons.bookmark,
                  size: 20.0,
                ),
                activeIcon: FaIcon(
                  FontAwesomeIcons.solidBookmark,
                  size: 20.0,
                  color: Colors.white,
                ),
                label: 'Favorites',
                tooltip: '',
              ),
            ],
          ),
          if (_currentPageName == 'HomePage')
            Positioned(
              bottom: 25,
              child: FlutterFlowIconButton(
                borderColor: Colors.transparent,
                borderRadius: 8.0,
                buttonSize: 70.0,
                icon: FaIcon(
                  isCurrentQuestionLiked
                      ? FontAwesomeIcons.solidHeart
                      : FontAwesomeIcons.heart,
                  color: isCurrentQuestionLiked 
                      ? Colors.red
                      : FlutterFlowTheme.of(context).info,
                  size: 45.0,
                ),
                onPressed: () {
  if (cardState.hasReachedSwipeLimit) {
    ref.read(popUpProvider.notifier).showPopUp(cardState.swipeResetTime);
  } else if (cardState.currentQuestion != null) {
    notifier.toggleLiked(cardState.currentQuestion!);
  }
},
              ),
            ),
        ],
      ),
    );
  }
}