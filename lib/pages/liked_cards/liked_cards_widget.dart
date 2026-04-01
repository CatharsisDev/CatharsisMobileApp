import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../provider/theme_provider.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/reflection_provider.dart';
import '../../components/reflection_bottom_sheet.dart';

class LikedCardsWidget extends ConsumerWidget {
  const LikedCardsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardState = ref.watch(cardStateProvider);
    final likedQuestions = cardState.likedQuestions;
    final notifier = ref.read(cardStateProvider.notifier);
    // Watch reflections so the note-preview rebuilds when notes change.
    ref.watch(reflectionProvider);
    final reflectionNotifier = ref.read(reflectionProvider.notifier);

    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Liked Cards',
          style: TextStyle(
            fontFamily: 'Runtime',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
      ),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Theme-aware background
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              image: (customTheme?.showBackgroundTexture ?? false) &&
                      (customTheme?.backgroundImagePath != null)
                  ? DecorationImage(
                      image: AssetImage(customTheme!.backgroundImagePath!),
                      fit: BoxFit.cover,
                      opacity: 0.4,
                    )
                  : null,
            ),
          ),
          // Main content
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
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: likedQuestions.length,
                      itemBuilder: (context, index) {
                        final question = likedQuestions[index];
                        final note = reflectionNotifier.noteFor(question);
                        final hasNote = note != null && note.isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: theme.cardColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Card header row ───────────────────────
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Question text + category
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            question.text,
                                            style: TextStyle(
                                              fontFamily: 'Runtime',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: theme
                                                  .textTheme.bodyMedium?.color,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            question.category,
                                            style: TextStyle(
                                              fontFamily: 'Runtime',
                                              fontSize: 13,
                                              color: theme.brightness ==
                                                      Brightness.dark
                                                  ? Colors.grey[400]
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Action buttons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Reflect button
                                        IconButton(
                                          icon: Icon(
                                            hasNote
                                                ? Icons.edit_note_rounded
                                                : Icons.edit_note_outlined,
                                            color: hasNote
                                                ? Colors.orange
                                                : (theme.brightness ==
                                                        Brightness.dark
                                                    ? Colors.grey[500]
                                                    : Colors.grey[400]),
                                            size: 24,
                                          ),
                                          tooltip: hasNote
                                              ? 'Edit reflection'
                                              : 'Add reflection',
                                          onPressed: () => showReflectionSheet(
                                              context, ref, question),
                                        ),
                                        // Unlike button
                                        IconButton(
                                          icon: const Icon(Icons.favorite,
                                              color: Colors.red),
                                          onPressed: () =>
                                              notifier.toggleLiked(question),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // ── Reflection note preview ───────────────
                                if (hasNote) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => showReflectionSheet(
                                        context, ref, question),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: theme.brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.06)
                                            : Colors.black.withOpacity(0.04),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.format_quote_rounded,
                                              color: Colors.orange
                                                  .withOpacity(0.7),
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              note,
                                              style: TextStyle(
                                                fontFamily: 'Runtime',
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic,
                                                color: theme.textTheme
                                                    .bodyMedium?.color
                                                    ?.withOpacity(0.75),
                                                height: 1.4,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
