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
      backgroundColor: ref.watch(themeProvider).themeName == 'dark'
          ? Theme.of(context).scaffoldBackgroundColor
          : ref.watch(themeProvider).themeName == 'light'
              ? Colors.grey[100]
              : const Color(0xFFEFEFEF),
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
      body: likedQuestions.isEmpty
          ? Center(
              child: Text(
                'No liked cards yet',
                style: GoogleFonts.raleway(
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
                      style: GoogleFonts.raleway(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      question.category,
                      style: GoogleFonts.raleway(
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
    );
  }
}