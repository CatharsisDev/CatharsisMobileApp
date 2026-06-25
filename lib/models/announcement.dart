class Announcement {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final DateTime date;
  final String body;

  const Announcement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.body,
  });
}

/// Master list of in-app announcements — newest first.
/// Add a new entry here whenever you ship a notable update.
final List<Announcement> kAnnouncements = [
  Announcement(
    id: 'circle_mode_v1',
    emoji: '⭕',
    title: 'Introducing Circle',
    subtitle: 'A new way to play Catharsis — together.',
    date: DateTime(2026, 6, 25),
    body:
        'Catharsis Circle is bringing the questions you always wanted to ask to your loved ones. '  
        'Start a session, share a code, and go through questions together - up to 4 people at once. '
        'See where your answers match, where they differ, and learn something new about each other.\n\n'
        'Perfect for a quiet night in, a road trip, a picnic or home party or really any moment when you want to go a little deeper than small talk.\n\n'
  ),
];
