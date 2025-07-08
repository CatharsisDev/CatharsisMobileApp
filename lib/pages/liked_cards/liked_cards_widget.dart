import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/theme_provider.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../provider/app_state_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class LikedCardsWidget extends ConsumerWidget {
  const LikedCardsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(cardStateProvider);
    final notifier = ref.read(cardStateProvider.notifier);

    return Scaffold(
      backgroundColor: ref.watch(themeProvider).themeName == 'dark'
          ? Theme.of(context).scaffoldBackgroundColor
          : ref.watch(themeProvider).themeName == 'light'
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color.fromRGBO(208, 164, 180, 0.95),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Liked Cards',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'Raleway',
                color: Colors.white,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ref.watch(themeProvider).themeName == 'dark'
                ? [
                    Theme.of(context).appBarTheme.backgroundColor!,
                    Theme.of(context).scaffoldBackgroundColor
                  ]
                : ref.watch(themeProvider).themeName == 'light'
                    ? [
                        Theme.of(context).appBarTheme.backgroundColor!,
                        Theme.of(context).scaffoldBackgroundColor
                      ]
                    : [
                        Color.fromARGB(235, 208, 164, 180),
                        Color.fromRGBO(140, 198, 255, 1)
                      ],
            stops: [0.0, 1.0],
            begin: AlignmentDirectional(1.0, -0.34),
            end: AlignmentDirectional(-1.0, 0.34),
          ),
        ),
        child: appState.likedQuestions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 50,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No liked cards yet',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Raleway',
                            color: Colors.white,
                            fontSize: 18.0,
                          ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appState.likedQuestions.length,
                itemBuilder: (context, index) {
                  final question = appState.likedQuestions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: ref.watch(themeProvider).themeName == 'dark'
                          ? Color(0xFF2D2D2D)
                          : ref.watch(themeProvider).themeName == 'light'
                              ? Color.fromARGB(255, 215, 211, 211)
                              : Color.fromARGB(255, 222, 202, 202),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        question.text,
                        style: GoogleFonts.raleway(
                          fontSize:
                              20.0, // Increased font size for better readability
                          color: const Color.fromARGB(221, 255, 255, 255),
                          fontWeight: FontWeight
                              .w500, // Slightly bold for better emphasis
                          letterSpacing:
                              0.5, // Adds a bit of spacing between characters
                          shadows: [
                            Shadow(
                              color: const Color.fromARGB(
                                  150, 0, 0, 0), // Slightly softer shadow
                              offset: const Offset(2.0, 2.0),
                              blurRadius:
                                  2.5, // Slightly stronger blur for a subtle glow
                            ),
                          ],
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          question.category,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Raleway',
                                    fontSize: 14.0,
                                    color: const Color(0xFFE35F42),
                                  ),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.favorite,
                          color: Color(0xFFE35F42),
                        ),
                        onPressed: () => notifier.toggleLiked(question),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
