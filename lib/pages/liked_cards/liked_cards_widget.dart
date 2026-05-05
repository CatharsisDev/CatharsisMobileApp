import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../provider/theme_provider.dart';
import '../../provider/app_state_provider.dart';
import '../../provider/reflection_provider.dart';
import '../../components/reflection_bottom_sheet.dart';
import '../../questions_model.dart';

enum _SortOrder { dateAdded, alphabetical, hasReflection }

class LikedCardsWidget extends ConsumerStatefulWidget {
  const LikedCardsWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<LikedCardsWidget> createState() => _LikedCardsWidgetState();
}

class _LikedCardsWidgetState extends ConsumerState<LikedCardsWidget> {
  _SortOrder _sortOrder = _SortOrder.dateAdded;

  List<Question> _sorted(List<Question> questions, Map<String, String> notes) {
    final list = List<Question>.from(questions);
    switch (_sortOrder) {
      case _SortOrder.dateAdded:
        // Keep original insertion order — newest liked at the bottom; reverse
        // so the most recently liked card appears first.
        return list.reversed.toList();
      case _SortOrder.alphabetical:
        list.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
        return list;
      case _SortOrder.hasReflection:
        list.sort((a, b) {
          final aHas = (notes[_noteKey(a)] ?? '').isNotEmpty ? 0 : 1;
          final bHas = (notes[_noteKey(b)] ?? '').isNotEmpty ? 0 : 1;
          if (aHas != bHas) return aHas.compareTo(bHas);
          return a.text.toLowerCase().compareTo(b.text.toLowerCase());
        });
        return list;
    }
  }

  String _noteKey(Question q) {
    final key = '${q.category.trim()}|${q.text.trim()}';
    return key.length > 500 ? key.substring(0, 500) : key;
  }

  void _showSortSheet(BuildContext context, CustomThemeExtension? customTheme, Color fontColor) {
    final options = [
      (_SortOrder.dateAdded,      Icons.access_time_rounded,   'Date added'),
      (_SortOrder.alphabetical,   Icons.sort_by_alpha_rounded,  'Alphabetical'),
      (_SortOrder.hasReflection,  Icons.edit_note_rounded,      'Has reflection'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: fontColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sort by',
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: fontColor,
              ),
            ),
            const SizedBox(height: 12),
            ...options.map((o) {
              final selected = _sortOrder == o.$1;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(
                  o.$2,
                  color: selected
                      ? (customTheme?.preferenceButtonColor ?? Colors.orange)
                      : fontColor.withOpacity(0.55),
                ),
                title: Text(
                  o.$3,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? (customTheme?.preferenceButtonColor ?? Colors.orange)
                        : fontColor,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded,
                        color: customTheme?.preferenceButtonColor ?? Colors.orange)
                    : null,
                onTap: () {
                  setState(() => _sortOrder = o.$1);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(cardStateProvider);
    final likedQuestions = cardState.likedQuestions;
    final notifier = ref.read(cardStateProvider.notifier);
    final notes = ref.watch(reflectionProvider);
    final reflectionNotifier = ref.read(reflectionProvider.notifier);

    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final fontColor = customTheme?.fontColor ??
        theme.textTheme.bodyMedium?.color ??
        theme.primaryColor;

    final sorted = _sorted(likedQuestions, notes);

    final sortLabels = {
      _SortOrder.dateAdded:     'Date added',
      _SortOrder.alphabetical:  'Alphabetical',
      _SortOrder.hasReflection: 'Has reflection',
    };

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
        actions: likedQuestions.isEmpty
            ? null
            : [
                TextButton.icon(
                  onPressed: () =>
                      _showSortSheet(context, customTheme, fontColor),
                  icon: Icon(Icons.sort_rounded,
                      size: 18, color: theme.iconTheme.color),
                  label: Text(
                    sortLabels[_sortOrder]!,
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      fontSize: 13,
                      color: theme.iconTheme.color,
                    ),
                  ),
                ),
              ],
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
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final question = sorted[index];
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
