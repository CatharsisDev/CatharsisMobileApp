/// Quality checks for question text, applied to every question source:
/// the bundled CSVs, AI-generated questions, and the local Hive caches.
///
/// AI output in particular can contain broken lines — answers cut off when the
/// model hits its token limit, intro lines like "Here are 20 questions:", or a
/// single question split over two lines. These must never reach a card.
///
/// The same rules are mirrored server-side in functions/index.js
/// (isValidQuestion) — keep the two in sync when changing them.
class QuestionQuality {
  QuestionQuality._();

  static const int minChars = 15;
  static const int maxChars = 220;
  static const int minWords = 4;
  static const int maxWords = 40;

  /// Words a complete question never ends on. "What do you think about the?"
  /// is a sign the text was cut off mid-sentence.
  /// (Prepositions are deliberately not listed — "...who would you go with?"
  /// is a normal English question.)
  static const Set<String> _danglingEndWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'nor', 'your', 'my', 'their',
    'our', 'its', 'because', 'than',
  };

  /// Prompts that are valid without a question mark ("Name three...").
  static final RegExp _imperativeStart = RegExp(
    r'^(Name|Describe|Explain|Tell|Share|Imagine|Think|List|Pick|Choose)\b',
  );

  /// Phrases that show the model talking about the task instead of asking.
  static final RegExp _metaText = RegExp(
    r'^(here are|here is|sure|certainly|of course|okay|ok)\b|as an ai|questions?:\s*$',
    caseSensitive: false,
  );

  /// Typographic characters mapped to plain equivalents. The display font only
  /// covers basic Latin, so anything else is transliterated or removed.
  static const Map<String, String> _charMap = {
    '‘': "'", '’': "'", '‛': "'", '′': "'",
    '“': '"', '”': '"', '„': '"', '″': '"',
    '–': ' - ', '—': ' - ', '−': '-',
    '…': '...', ' ': ' ',
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'å': 'a', 'ã': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n', 'ß': 'ss',
    'É': 'E', 'À': 'A', 'Ü': 'U', 'Ö': 'O', 'Ä': 'A',
  };

  /// Normalises raw question text: strips list numbering/bullets and wrapping
  /// quotes, replaces typographic characters, and collapses whitespace.
  static String clean(String raw) {
    var t = raw;
    _charMap.forEach((from, to) => t = t.replaceAll(from, to));
    t = t
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // anything the font can't draw
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirst(RegExp(r'^(Q\d*[:.)]|\d+[.):]?)\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^[-*•]\s*'), '')
        .trim();

    // Strip quotes wrapping the whole line ("Do you...?") but keep inner ones.
    if (t.length > 2 && t.startsWith('"') && t.endsWith('"') &&
        '"'.allMatches(t).length == 2) {
      t = t.substring(1, t.length - 1).trim();
    }
    // Space before punctuation: "you ?" → "you?"
    t = t.replaceAllMapped(RegExp(r'\s+([?!.,;:])'), (m) => m[1]!);
    return t;
  }

  /// True if [text] (already cleaned) looks like a complete, displayable question.
  static bool isValid(String text) {
    final t = text.trim();
    if (t.length < minChars || t.length > maxChars) return false;

    final words = t.split(' ');
    if (words.length < minWords || words.length > maxWords) return false;

    // Must start like a sentence.
    if (!RegExp(r'^[A-Z"]').hasMatch(t)) return false;

    // Must end like a complete sentence: a question ("...?"), a question
    // followed by a prompt ("...? Explain why!"), or an imperative prompt
    // ("Name three people you admire.").
    if (!RegExp(r'[?.!]"?$').hasMatch(t)) return false;
    if (!t.contains('?') && !_imperativeStart.hasMatch(t)) return false;

    // Cut off mid-sentence ("...about the?").
    final lastWord = words.last
        .replaceAll(RegExp(r'[^A-Za-z]'), '')
        .toLowerCase();
    if (_danglingEndWords.contains(lastWord)) return false;

    // Unbalanced quotes or brackets mean part of the text is missing.
    if ('"'.allMatches(t).length.isOdd) return false;
    if ('('.allMatches(t).length != ')'.allMatches(t).length) return false;

    if (_metaText.hasMatch(t)) return false;
    if (t.endsWith(':')) return false;

    return true;
  }

  /// Cleans [raw] and returns it, or null if the result fails [isValid].
  static String? cleanOrNull(String raw) {
    final t = clean(raw);
    return isValid(t) ? t : null;
  }
}
