import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'gamecard_model.dart';
export 'gamecard_model.dart';

class GamecardWidget extends StatefulWidget {
  const GamecardWidget({super.key});

  @override
  State<GamecardWidget> createState() => _GamecardWidgetState();
}

class _GamecardWidgetState extends State<GamecardWidget> {
  late GamecardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GamecardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double borderRadiusValue = 15; 

    return Align(
      alignment: AlignmentDirectional(0.0, 0.0),
      child: Container(
        width: 400.0,
        height: 400.0,
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(borderRadiusValue),
          border: Border.all(
            color: const Color.fromARGB(255, 162, 156, 154), 
            width: 5.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/resized_400x400_gradient.png',
            width: 500.0,
            height: 500.0,
            fit: BoxFit.cover, 
          ),
        ),
      ),
    );
  }
}
