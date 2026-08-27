/// Resolves Catechism paragraph numbers to official scborromeo.org pages.
class CccLinkResolver {
  CccLinkResolver._();

  /// Last numbered paragraph in the second edition Catechism.
  static const int maxParagraph = 2865;

  static bool isValidParagraph(int paragraph) {
    return paragraph >= 1 && paragraph <= maxParagraph;
  }

  static String paragraphUrl(int paragraph) {
    return 'https://www.scborromeo.org/ccc/para/$paragraph.htm';
  }

  static final RegExp _paragraphPattern = RegExp(
    r'(?:CCC|Catechism|paragraph|§|para\.?)\s*#?\s*(\d{3,4})\b',
    caseSensitive: false,
  );

  static int? extractParagraphNumber(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _paragraphPattern.firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!);

    // Link label like "1422" with nearby catechism context in href
    if (text.contains('vatican.va') || text.toLowerCase().contains('catechism')) {
      final bare = RegExp(r'\b(\d{4})\b').firstMatch(text);
      if (bare != null) return int.tryParse(bare.group(1)!);
    }
    return null;
  }

  static bool looksLikeCatechismReference(String href, String linkText) {
    if (_paragraphPattern.hasMatch(linkText)) return true;

    final combined = '${href.toLowerCase()} ${linkText.toLowerCase()}';
    if (combined.contains('scborromeo.org/ccc')) return true;
    return combined.contains('vatican.va') &&
        (combined.contains('catechism') ||
            combined.contains('ccc') ||
            _paragraphPattern.hasMatch(linkText));
  }

  /// scborromeo hosts one page per paragraph; avoids article-level gaps in
  /// legacy chapter files (e.g. §956 lives between p1s2c3a8 and p2s1c1a1).
  static Uri? resolve(String href, String linkText) {
    final paragraph =
        extractParagraphNumber(linkText) ?? extractParagraphNumber(href);
    if (paragraph == null || !isValidParagraph(paragraph)) {
      return null;
    }

    if (looksLikeCatechismReference(href, linkText)) {
      return Uri.parse(paragraphUrl(paragraph));
    }

    return null;
  }
}
