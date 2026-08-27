/// Builds stable Bible Gateway NABRE passage URLs for Scripture references.
class ScriptureLinkResolver {
  ScriptureLinkResolver._();

  static const _nabrePassageBase = 'https://www.biblegateway.com/passage/';

  static final RegExp _referencePattern = RegExp(
    r'\b(\d\s+[A-Za-z]+(?:\s+[A-Za-z]+)?|Song\s+of\s+Songs|Song\s+of\s+Solomon|[A-Za-z]+(?:\s+of\s+[A-Za-z]+)?|[A-Za-z]+)\s+(\d{1,3})(?::(\d{1,3})(?:\s*[–—-]\s*(\d{1,3}))?)?\b',
  );

  static const Set<String> _books = {
    'genesis',
    'exodus',
    'leviticus',
    'numbers',
    'deuteronomy',
    'joshua',
    'judges',
    'ruth',
    '1 samuel',
    '2 samuel',
    '1 kings',
    '2 kings',
    '1 chronicles',
    '2 chronicles',
    'ezra',
    'nehemiah',
    'tobit',
    'judith',
    'esther',
    '1 maccabees',
    '2 maccabees',
    'job',
    'psalm',
    'psalms',
    'proverbs',
    'ecclesiastes',
    'song of songs',
    'song of solomon',
    'wisdom',
    'sirach',
    'ecclesiasticus',
    'isaiah',
    'jeremiah',
    'lamentations',
    'baruch',
    'ezekiel',
    'daniel',
    'hosea',
    'joel',
    'amos',
    'obadiah',
    'jonah',
    'micah',
    'nahum',
    'habakkuk',
    'zephaniah',
    'haggai',
    'zechariah',
    'malachi',
    'matthew',
    'mark',
    'luke',
    'john',
    'acts',
    'romans',
    '1 corinthians',
    '2 corinthians',
    'galatians',
    'ephesians',
    'philippians',
    'colossians',
    '1 thessalonians',
    '2 thessalonians',
    '1 timothy',
    '2 timothy',
    'titus',
    'philemon',
    'hebrews',
    'james',
    '1 peter',
    '2 peter',
    '1 john',
    '2 john',
    '3 john',
    'jude',
    'revelation',
    'apocalypse',
  };

  /// Returns a Bible Gateway NABRE URL when [reference] looks like Scripture.
  static Uri? buildNabrePassageUri(String reference) {
    final normalized = _normalizeReference(reference);
    if (normalized == null) return null;

    return Uri.parse(
      '$_nabrePassageBase?search=${_encodeSearch(normalized)}&version=NABRE',
    );
  }

  /// True when [text] matches a known biblical book and chapter/verse pattern.
  static bool looksLikeScriptureReference(String text) {
    return _normalizeReference(text) != null;
  }

  static String? _normalizeReference(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final match = _referencePattern.firstMatch(trimmed);
    if (match == null) return null;
    if (match.start != 0 || match.end != trimmed.length) return null;

    final book = _canonicalBook(match.group(1)!);
    if (!_books.contains(book)) return null;

    final chapter = match.group(2)!;
    final verse = match.group(3);
    final endVerse = match.group(4);

    final displayBook = book == 'psalms' ? 'Psalm' : _titleCaseBook(match.group(1)!);

    if (verse == null) {
      return '$displayBook $chapter';
    }
    if (endVerse != null) {
      return '$displayBook $chapter:$verse-$endVerse';
    }
    return '$displayBook $chapter:$verse';
  }

  static String _encodeSearch(String reference) {
    return reference.replaceAll(' ', '+').replaceAll(':', '%3A');
  }

  static String _canonicalBook(String book) {
    return book.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String _titleCaseBook(String book) {
    final normalized = book.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (RegExp(r'^\d\s').hasMatch(normalized)) {
      final parts = normalized.split(RegExp(r'\s+'));
      return '${parts.first} ${_capitalizeWords(parts.sublist(1).join(' '))}';
    }
    return _capitalizeWords(normalized);
  }

  static String _capitalizeWords(String value) {
    return value
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.toLowerCase() == 'of') return 'of';
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
