import 'package:catharsis_cards/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/components/gamecard_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/pop_up_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import '/components/swipe_limit_popup.dart';
import '../../provider/tutorial_state_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme_settings/theme_settings_page.dart';

class HomePageWidget extends ConsumerStatefulWidget {
  const HomePageWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends ConsumerState<HomePageWidget> with TickerProviderStateMixin {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late CardSwiperController _cardController;
  late AnimationController _handController;
  late Animation<Offset> _swipeAnimation;

  @override
  void initState() {
    super.initState();
    _cardController = CardSwiperController();

    // Initialize the hand swipe animation
    _handController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _swipeAnimation = Tween<Offset>(
      begin: Offset(-0.1, 0.0),
      end: Offset(0.1, 0.0),
    ).animate(CurvedAnimation(
      parent: _handController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _cardController.dispose();
    _handController.dispose();
    super.dispose();
  }

  void _handleCategorySelection(String category, CardStateNotifier notifier) {
    notifier.updateCategory(category == 'All Categories' ? 'all' : category);
    Navigator.pop(context); // Close the drawer after category selection
  }

  void _showExtraPackagePopUp(BuildContext context, DateTime? resetTime) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return SwipeLimitPopup(
        resetTime: resetTime,
        onDismiss: () {
          Navigator.of(context).pop();
          ref.read(popUpProvider.notifier).hidePopUp();
        },
        onPurchase: () {
          // Add purchase logic
        },
        onTimerEnd: () {
          Navigator.of(context).pop();
          ref.read(popUpProvider.notifier).hidePopUp();
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(cardStateProvider);
    final notifier = ref.read(cardStateProvider.notifier);
    final showTutorial = ref.watch(tutorialProvider);
    final tutorialNotifier = ref.read(tutorialProvider.notifier);

    // Listen for popup trigger
    ref.listen<bool>(popUpProvider, (previous, next) {
      if (next) {
        _showExtraPackagePopUp(context, cardState.swipeResetTime);
      }
    });

    return Stack(
      children: [
        GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: ref.watch(themeProvider).themeName == 'dark'
    ? Theme.of(context).scaffoldBackgroundColor 
    : ref.watch(themeProvider).themeName == 'light'
    ? Color.fromARGB(235, 201, 197, 197)
    : const Color.fromRGBO(208, 164, 180, 0.95),
            drawer: AnimatedOpacity(
              opacity: 0.8,
              duration: 300.0.ms,
              curve: Curves.easeInOut,
              child: Container(
                width: 250.0,
                child: Drawer(
                  elevation: 16.0,
                  child: Container(
                    decoration: BoxDecoration(
  gradient: LinearGradient(
    colors: ref.watch(themeProvider).themeName == 'dark'
    ? [Theme.of(context).appBarTheme.backgroundColor!, Theme.of(context).scaffoldBackgroundColor] 
    : ref.watch(themeProvider).themeName == 'light'
        ? [Color.fromARGB(235, 211, 209, 210), Color.fromARGB(255, 185, 204, 224)]
        : [Color.fromARGB(235, 208, 164, 180), Color.fromARGB(255, 140, 198, 255)],
                        stops: [0.0, 1.0],
                        begin: AlignmentDirectional(1.0, -0.34),
                        end: AlignmentDirectional(-1.0, 0.34),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: SingleChildScrollView(
 child: Column(
   mainAxisSize: MainAxisSize.max,
   mainAxisAlignment: MainAxisAlignment.center,
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
     Padding(
       padding: const EdgeInsetsDirectional.fromSTEB(10.0, 40.0, 40.0, 35.0),
       child: InkWell(
         onTap: () => _handleCategorySelection('All Categories', notifier),
         child: Text(
           'All Categories',
           style: GoogleFonts.raleway(
             color: cardState.currentCategory == 'all'
                 ? const Color.fromARGB(255, 227, 95, 66)
                 : Colors.white,
             fontSize: 25.0,
             fontWeight: FontWeight.bold,
             letterSpacing: 0.0,
             shadows: [
               Shadow(
                 color: FlutterFlowTheme.of(context).secondaryText,
                 offset: const Offset(2.0, 2.0),
                 blurRadius: 2.0,
               )
             ],
           ),
         ),
       ),
     ),
     const SizedBox(height: 20),
     ...{
       'Love and Intimacy': 'assets/images/love_intimacy_icon.png',
       'Spirituality': 'assets/images/spirituality_icon.png',
       'Society': 'assets/images/society_icon.png',
       'Interactions and\nRelationships': 'assets/images/interactions_relationships_icon.png'
     }.entries
         .map((entry) {
           final category = entry.key;
           final iconPath = entry.value;
           bool isSelected = category.replaceAll('\n', ' ').trim() == 
                           cardState.currentCategory.replaceAll(RegExp(r'\s+'), ' ').trim();
           
           return Padding(
             padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
             child: InkWell(
               onTap: () => _handleCategorySelection(category, notifier),
               child: Row(
                 children: [
                   if (iconPath != null)
                     Padding(
                       padding: const EdgeInsets.only(right: 8.0),
                       child: Image.asset(
                         iconPath,
                         width: 47,
                         height: 47,
                       ),
                     ),
                   if (category.contains('\n'))
                     Text.rich(
                       TextSpan(
                         children: category.split('\n').map((line) {
                           return TextSpan(
                             text: '$line\n',
                             style: GoogleFonts.raleway(
                               color: isSelected
                                   ? const Color(0xFFE35F42)
                                   : Colors.white,
                               fontSize: 20.0,
                               fontWeight: FontWeight.bold,
                               letterSpacing: 0.0,
                               shadows: [
                                 Shadow(
                                   color: FlutterFlowTheme.of(context).secondaryText,
                                   offset: const Offset(2.0, 2.0),
                                   blurRadius: 2.0,
                                 )
                               ],
                             ),
                           );
                         }).toList(),
                       ),
                     )
                   else
                     Text(
                       category,
                       style: GoogleFonts.raleway(
                         color: isSelected
                             ? const Color(0xFFE35F42)
                             : Colors.white,
                         fontSize: 20.0,
                         fontWeight: FontWeight.bold,
                         letterSpacing: 0.0,
                         shadows: [
                           Shadow(
                             color: FlutterFlowTheme.of(context).secondaryText,
                             offset: const Offset(2.0, 2.0),
                             blurRadius: 2.0,
                           )
                         ],
                       ),
                     ),
                 ],
               ),
             ),
           );
         })
         .toList()
         .divide(const SizedBox(height: 40.0))
         .addToEnd(const SizedBox(height: 120.0)),
   ],
 ),
)
                        ),
                        Align(
                          alignment: const AlignmentDirectional(-2.0, 1.8),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 0.0, 20.0),
                            child: Image.asset(
                              'assets/images/catharsis_word_only.png',
                              width: 200.0,
                              height: 400.0,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: SafeArea(
              top: true,
              child: Stack(
                children: [
                  Container(
  width: MediaQuery.sizeOf(context).width * 1.0,
  height: MediaQuery.sizeOf(context).height * 1.029,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: ref.watch(themeProvider).themeName == 'dark'
   ? [Color(0xFF1E1E1E), Color(0xFF121212)]
   : ref.watch(themeProvider).themeName == 'light'
       ? [Color.fromARGB(235, 201, 197, 197), Color.fromARGB(255, 255, 255, 255)]
       : [Color.fromARGB(235, 208, 164, 180), Color.fromARGB(255, 140, 198, 255)],
      stops: [0.0, 1.0],
      begin: AlignmentDirectional(0.6, -0.34),
      end: AlignmentDirectional(-1.0, 0.34),
    ),
  ),
),
                  if (cardState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Align(
                      alignment: const AlignmentDirectional(0.0, 0.0),
                      child: Container(
                        width: MediaQuery.sizeOf(context).width * 4.0,
                        height: 485.0,
                        child: Stack(
                          alignment: const AlignmentDirectional(0.0, 0.0),
                          children: [
                            FlutterFlowSwipeableStack(
                              onSwipeFn: (index) => notifier.handleCardSwiped(index),
                              onLeftSwipe: notifier.handleCardSwiped,
                              onRightSwipe: notifier.handleCardSwiped,
                              onUpSwipe: notifier.handleCardSwiped,
                              onDownSwipe: notifier.handleCardSwiped,
                              itemBuilder: (context, index) {
                                final currentQuestions = cardState.activeQuestions;
                                if (currentQuestions.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No questions available',
                                      style: GoogleFonts.raleway(
                                            color: Colors.white,
                                            fontSize: 20.0,
                                          ),
                                    ),
                                  );
                                }

                                final normalizedIndex = index % currentQuestions.length;
                                final question = currentQuestions[normalizedIndex];

                                return Stack(
                                  children: [
                                    Align(
                                      alignment: const AlignmentDirectional(0.0, 0.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: GamecardWidget(),
                                      ),
                                    ),
                                    Align(
                                      alignment: const AlignmentDirectional(0.0, 0.0),
                                      child: Container(
                                        width: 400.0,
                                        height: 400.0,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Align(
                                              alignment: const AlignmentDirectional(0.0, 0.0),
                                              child: Padding(
                                                padding: const EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 60.0),
                                                child: Text(
                                                  question.text,
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.raleway(
                                          
                                                    color: Colors.white,
                                                    fontSize: 28.0,
                                                    letterSpacing: 0.2,
                                                    shadows: [
                                                      Shadow(
                                                        color: FlutterFlowTheme.of(context).secondaryText,
                                                        offset: const Offset(2.0, 2.0),
                                                        blurRadius: 2.0,
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: 20,
                                              child: Text(
                                                question.category,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.raleway(
                                                  color: Colors.white,
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.0,
                                                  shadows: [
                                                    Shadow(
                                                      color: FlutterFlowTheme.of(context).secondaryText,
                                                      offset: const Offset(2.0, 2.0),
                                                      blurRadius: 2.0,
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              itemCount: cardState.activeQuestions.isEmpty ? 1 : cardState.activeQuestions.length,
                              controller: _cardController,
                              loop: true,
                              cardDisplayCount: 4,
                              scale: 0.9,
                              threshold: 0.7,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(10.0, 10.0, 0.0, 0.0),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        scaffoldKey.currentState!.openDrawer();
                      },
                      child: Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 40.0,
                      ),
                    ),
                  ),
                  Positioned(
  right: 10,
  top: 10,
  child: InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ThemeSettingsPage(), // Ensure this page is defined and imported
        ),
      );
    },
    child: Icon(
      Icons.palette_outlined,
      color: Colors.white, // Change color to match your theme
      size: 40.0,
    ),
  ),
),
                ],
              ),
            ),
          ),
        ),

        // Tutorial Overlay
        if (showTutorial)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Swipe left and right on cards to navigate!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.raleway(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: _swipeAnimation,
                    child: const Icon(
                      Icons.swipe,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Tap the heart icon to like a card and save it for later!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  ElevatedButton(
                    onPressed: () {
                      tutorialNotifier.hideTutorial();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 10.0,
                      ),
                    ),
                    child: const Text(
                      "Got it!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}