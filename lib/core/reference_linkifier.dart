import 'ccc_link_resolver.dart';
import 'scripture_link_resolver.dart';

/// Ensures Scripture and CCC citations in WWJD markdown are active hyperlinks.
class ReferenceLinkifier {
  ReferenceLinkifier._();

  static final RegExp _markdownLinkPattern = RegExp(r'\[([^\]]*)\]\(([^)]*)\)');

  static final RegExp _cccBarePattern = RegExp(
    r'\b(CCC|Catechism(?:\s+of\s+the\s+Catholic\s+Church)?)(?:\s*(?:§|#|paragraph|para\.?))?\s*(\d{3,4})\b',
    caseSensitive: false,
  );

  static final RegExp _scriptureBarePattern = RegExp(
    r'\b(\d\s+[A-Za-z]+(?:\s+[A-Za-z]+)?|Song\s+of\s+Songs|Song\s+of\s+Solomon|[A-Za-z]+(?:\s+of\s+[A-Za-z]+)?|[A-Za-z]+)\s+(\d{1,3})(?::(\d{1,3})(?:\s*[–—-]\s*(\d{1,3}))?)?\b',
  );

  static String linkify(String markdown) {
    final rewrittenLinks = _rewriteExistingLinks(markdown);
    return _linkifyPlainSegments(rewrittenLinks);
  }

  static String _rewriteExistingLinks(String markdown) {
    return markdown.replaceAllMapped(_markdownLinkPattern, (match) {
      final label = match.group(1)!;
      final href = match.group(2)!;
      return _rewriteMarkdownLink(label, href);
    });
  }

  static String _rewriteMarkdownLink(String label, String href) {
    final cccParagraph =
        CccLinkResolver.extractParagraphNumber(label) ??
            CccLinkResolver.extractParagraphNumber(href);
    if (cccParagraph != null &&
        CccLinkResolver.isValidParagraph(cccParagraph) &&
        (CccLinkResolver.looksLikeCatechismReference(href, label) ||
            _cccBarePattern.hasMatch(label))) {
      return '[$label](${CccLinkResolver.paragraphUrl(cccParagraph)})';
    }

    if (_isGenericCatechismHomepage(href) && cccParagraph == null) {
      return label;
    }

    if (_looksLikeBibleGateway(href)) {
      final uri = ScriptureLinkResolver.buildNabrePassageUri(
        _scriptureReferenceFromLink(label, href),
      );
      if (uri != null) {
        return '[$label]($uri)';
      }
    }

    if (ScriptureLinkResolver.looksLikeScriptureReference(label)) {
      final uri = ScriptureLinkResolver.buildNabrePassageUri(label);
      if (uri != null) {
        return '[$label]($uri)';
      }
    }

    return '[$label]($href)';
  }

  static String _linkifyPlainSegments(String markdown) {
    final buffer = StringBuffer();
    var index = 0;

    for (final match in _markdownLinkPattern.allMatches(markdown)) {
      if (match.start > index) {
        buffer.write(_linkifyPlainText(markdown.substring(index, match.start)));
      }
      buffer.write(match.group(0));
      index = match.end;
    }

    if (index < markdown.length) {
      buffer.write(_linkifyPlainText(markdown.substring(index)));
    }

    return buffer.toString();
  }

  static String _linkifyPlainText(String text) {
    var output = text;

    output = output.replaceAllMapped(_cccBarePattern, (match) {
      final label = '${match.group(1)!} ${match.group(2)!}';
      final paragraph = int.parse(match.group(2)!);
      if (!CccLinkResolver.isValidParagraph(paragraph)) {
        return match.group(0)!;
      }
      return '[$label](${CccLinkResolver.paragraphUrl(paragraph)})';
    });

    output = output.replaceAllMapped(_scriptureBarePattern, (match) {
      final reference = match.group(0)!;
      if (!ScriptureLinkResolver.looksLikeScriptureReference(reference)) {
        return reference;
      }
      final uri = ScriptureLinkResolver.buildNabrePassageUri(reference);
      if (uri == null) return reference;
      return '[$reference]($uri)';
    });

    return output;
  }

  static bool _looksLikeBibleGateway(String href) {
    final lower = href.toLowerCase();
    return lower.contains('biblegateway.com/passage');
  }

  static bool _isGenericCatechismHomepage(String href) {
    final lower = href.toLowerCase();
    return lower.contains('vatican.va') &&
        (lower.contains('_index.htm') ||
            lower.endsWith('/index.html') ||
            lower.contains('/archive/eng0015/'));
  }

  static String _scriptureReferenceFromLink(String label, String href) {
    final uri = Uri.tryParse(href);
    final search = uri?.queryParameters['search'];
    if (search != null && search.trim().isNotEmpty) {
      return search.replaceAll('+', ' ');
    }
    return label;
  }
}
