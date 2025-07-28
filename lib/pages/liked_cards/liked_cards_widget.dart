import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../provider/theme_provider.dart';
import '../../provider/app_state_provider.dart';

class LikedCardsWidget extends ConsumerWidget {
  const LikedCardsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardState = ref.watch(cardStateProvider);
    final likedQuestions = cardState.likedQuestions;
    final notifier = ref.read(cardStateProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Liked Cards',
          style: GoogleFonts.raleway(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Cream gradient background covers entire screen
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFAF1E1),
                  const Color(0xFFFAF1E1).withOpacity(0.95),
                ],
              ),
            ),
          ),
          // Texture overlay at 40% opacity
          Opacity(
            opacity: 0.4,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background_texture.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Main content shifted below AppBar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: likedQuestions.isEmpty
                  ? Center(
                      child: Text(
                        'No liked cards yet',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 20,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: likedQuestions.length,
                      itemBuilder: (context, index) {
                        final question = likedQuestions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            title: Text(
                              question.text,
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              question.category,
                              style: TextStyle(
                                fontFamily: 'Runtime',
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red),
                              onPressed: () {
                                notifier.toggleLiked(question);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}