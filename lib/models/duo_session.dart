import 'package:cloud_firestore/cloud_firestore.dart';

enum DuoSessionStatus { waiting, active, complete, cancelled }

/// A single card in a duo session.
/// New flow: players write reflections, then explicitly choose 'matched'/'differed'.
/// Legacy flow (old sessions): match was inferred from hostSwipe == guestSwipe.
class DuoCard {
  final String questionText;
  final String questionCategory;

  // ── Legacy swipe fields (kept for backward-compat reading old sessions) ──
  final String? hostSwipe;   // 'like' | 'pass' | null
  final String? guestSwipe;

  // ── New flow fields ──────────────────────────────────────────────────────
  final String hostReflection;
  final String guestReflection;
  final String? hostMatchChoice;  // 'matched' | 'differed' | null
  final String? guestMatchChoice;

  const DuoCard({
    required this.questionText,
    required this.questionCategory,
    this.hostSwipe,
    this.guestSwipe,
    this.hostReflection = '',
    this.guestReflection = '',
    this.hostMatchChoice,
    this.guestMatchChoice,
  });

  // ── Derived state ────────────────────────────────────────────────────────

  bool get reflectionsComplete =>
      hostReflection.isNotEmpty && guestReflection.isNotEmpty;

  /// Card fully done. New sessions need reflections + choices; legacy only swipes.
  bool get isComplete {
    // If either player has recorded a match choice, use new-flow logic
    if (hostMatchChoice != null || guestMatchChoice != null) {
      return reflectionsComplete &&
          hostMatchChoice != null &&
          guestMatchChoice != null;
    }
    // Legacy: both swipes present
    return hostSwipe != null && guestSwipe != null;
  }

  /// Both players explicitly chose 'matched' (new flow),
  /// or both chose the same swipe (legacy).
  bool get isMatch {
    if (hostMatchChoice != null || guestMatchChoice != null) {
      return isComplete &&
          hostMatchChoice == 'matched' &&
          guestMatchChoice == 'matched';
    }
    return isComplete && hostSwipe == guestSwipe;
  }

  /// Both players explicitly chose 'differed'.
  bool get bothDiffered =>
      isComplete &&
      hostMatchChoice == 'differed' &&
      guestMatchChoice == 'differed';

  /// Players disagreed on their choice (one matched, one differed).
  bool get hasMixedVote =>
      isComplete && !isMatch && !bothDiffered && hostMatchChoice != null;

  /// Not a clean match.
  bool get isSplit => isComplete && !isMatch;

  /// The "effective decision" for each player — prefers match choice, falls
  /// back to legacy swipe so summary tiles can render consistently.
  String? get hostDecision => hostMatchChoice ?? hostSwipe;
  String? get guestDecision => guestMatchChoice ?? guestSwipe;

  DuoCard copyWith({
    String? hostSwipe,
    String? guestSwipe,
    String? hostReflection,
    String? guestReflection,
    String? hostMatchChoice,
    String? guestMatchChoice,
  }) =>
      DuoCard(
        questionText: questionText,
        questionCategory: questionCategory,
        hostSwipe: hostSwipe ?? this.hostSwipe,
        guestSwipe: guestSwipe ?? this.guestSwipe,
        hostReflection: hostReflection ?? this.hostReflection,
        guestReflection: guestReflection ?? this.guestReflection,
        hostMatchChoice: hostMatchChoice ?? this.hostMatchChoice,
        guestMatchChoice: guestMatchChoice ?? this.guestMatchChoice,
      );

  Map<String, dynamic> toMap() => {
        'questionText': questionText,
        'questionCategory': questionCategory,
        'hostSwipe': hostSwipe,
        'guestSwipe': guestSwipe,
        'hostReflection': hostReflection,
        'guestReflection': guestReflection,
        'hostMatchChoice': hostMatchChoice,
        'guestMatchChoice': guestMatchChoice,
      };

  factory DuoCard.fromMap(Map<String, dynamic> m) => DuoCard(
        questionText: m['questionText'] as String? ?? '',
        questionCategory: m['questionCategory'] as String? ?? '',
        hostSwipe: m['hostSwipe'] as String?,
        guestSwipe: m['guestSwipe'] as String?,
        hostReflection: m['hostReflection'] as String? ?? '',
        guestReflection: m['guestReflection'] as String? ?? '',
        hostMatchChoice: m['hostMatchChoice'] as String?,
        guestMatchChoice: m['guestMatchChoice'] as String?,
      );
}

/// The full duo session document stored in Firestore at duoSessions/{sessionCode}.
class DuoSession {
  final String sessionCode;
  final String hostUid;
  final String hostName;
  final String? guestUid;
  final String? guestName;
  final DuoSessionStatus status;
  final List<DuoCard> cards;
  final DateTime createdAt;

  const DuoSession({
    required this.sessionCode,
    required this.hostUid,
    required this.hostName,
    this.guestUid,
    this.guestName,
    required this.status,
    required this.cards,
    required this.createdAt,
  });

  bool get hasGuest => guestUid != null && guestUid!.isNotEmpty;
  bool get isWaiting => status == DuoSessionStatus.waiting;
  bool get isActive => status == DuoSessionStatus.active;
  bool get isComplete => status == DuoSessionStatus.complete;

  /// Index of the first card not yet fully completed by both players.
  /// Returns -1 when all cards are done.
  int get currentCardIndex {
    for (int i = 0; i < cards.length; i++) {
      if (!cards[i].isComplete) return i;
    }
    return -1;
  }

  bool get allCardsComplete => currentCardIndex == -1;

  List<DuoCard> get matchedCards => cards.where((c) => c.isMatch).toList();
  List<DuoCard> get splitCards => cards.where((c) => c.isSplit).toList();

  DuoSession copyWith({
    String? guestUid,
    String? guestName,
    DuoSessionStatus? status,
    List<DuoCard>? cards,
  }) =>
      DuoSession(
        sessionCode: sessionCode,
        hostUid: hostUid,
        hostName: hostName,
        guestUid: guestUid ?? this.guestUid,
        guestName: guestName ?? this.guestName,
        status: status ?? this.status,
        cards: cards ?? this.cards,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'hostUid': hostUid,
        'hostName': hostName,
        'guestUid': guestUid,
        'guestName': guestName,
        'status': status.name,
        // Store as a map keyed by string index so Firestore dot-notation
        // field updates (e.g. "cards.2.hostMatchChoice") work correctly.
        'cards': {
          for (int i = 0; i < cards.length; i++) '$i': cards[i].toMap(),
        },
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory DuoSession.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;

    final cardsRaw = m['cards'];
    List<DuoCard> rawCards;
    if (cardsRaw is Map) {
      final sorted = cardsRaw.entries.toList()
        ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
      rawCards = sorted
          .map((e) => DuoCard.fromMap(Map<String, dynamic>.from(e.value as Map)))
          .toList();
    } else if (cardsRaw is List) {
      rawCards = cardsRaw
          .map((c) => DuoCard.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList();
    } else {
      rawCards = [];
    }

    final statusStr = m['status'] as String? ?? 'waiting';
    return DuoSession(
      sessionCode: doc.id,
      hostUid: m['hostUid'] as String? ?? '',
      hostName: m['hostName'] as String? ?? 'Host',
      guestUid: m['guestUid'] as String?,
      guestName: m['guestName'] as String?,
      status: DuoSessionStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => DuoSessionStatus.waiting,
      ),
      cards: rawCards,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
