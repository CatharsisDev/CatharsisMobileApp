import '/components/gamecard_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'home_page_widget.dart' show HomePageWidget;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomePageModel extends FlutterFlowModel<HomePageWidget> {
  ///  State fields for stateful widgets in this page.

  // Keep a single controller instance to preserve swipe state across navigation
  final CardSwiperController swipeableStackController = CardSwiperController();
  // Model for Gamecard components
  late GamecardModel gamecardModel1;
  late GamecardModel gamecardModel2;
  late GamecardModel gamecardModel3;
  late GamecardModel gamecardModel4;

  void resetCards() {
    // Intentionally left as a no-op to avoid recreating the controller,
    // which would reset swipe state when navigating away and back.
  }

  @override
  void initState(BuildContext context) {
    gamecardModel1 = createModel(context, () => GamecardModel());
    gamecardModel2 = createModel(context, () => GamecardModel());
    gamecardModel3 = createModel(context, () => GamecardModel());
    gamecardModel4 = createModel(context, () => GamecardModel());
  }

  @override
  void dispose() {
    gamecardModel1.dispose();
    gamecardModel2.dispose();
    gamecardModel3.dispose();
    gamecardModel4.dispose();
  }
}