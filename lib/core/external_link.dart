import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ccc_link_resolver.dart';
import 'reference_linkifier.dart';
import 'scripture_link_resolver.dart';
/// Converts AI/markdown hrefs into absolute https URLs for external sites.
Uri? normalizeExternalUri(String raw) {
  var href = raw.trim();
  if (href.isEmpty) return null;

  Uri? uri = Uri.tryParse(href);
  if (uri == null) return null;

  if (uri.hasScheme) {
    if (uri.scheme == 'http' || uri.scheme == 'https') return uri;
    return null;
  }

  if (href.startsWith('//')) {
    return Uri.parse('https:$href');
  }

  if (href.startsWith('www.')) {
    return Uri.parse('https://$href');
  }

  if (href.startsWith('/content/') || href.startsWith('/archive/')) {
    return Uri.parse('https://www.vatican.va$href');
  }

  if (href.contains('vatican.va')) {
    final cleaned = href.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('https://$cleaned');
  }

  if (href.contains('biblegateway.com')) {
    final cleaned = href.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('https://$cleaned');
  }

  return null;
}

/// Rewrites common relative Vatican/Bible links in markdown before display.
String normalizeMarkdownExternalLinks(String markdown) {
  var text = markdown;

  text = text.replaceAllMapped(
    RegExp(r'\]\((/content/[^)\s]+)\)', caseSensitive: false),
    (m) => '](https://www.vatican.va${m[1]})',
  );

  text = text.replaceAllMapped(
    RegExp(r'\]\((/archive/[^)\s]+)\)', caseSensitive: false),
    (m) => '](https://www.vatican.va${m[1]})',
  );

  text = text.replaceAllMapped(
    RegExp(r'\]\((www\.vatican\.va[^)\s]*)\)', caseSensitive: false),
    (m) => '](https://${m[1]})',
  );

  text = text.replaceAllMapped(
    RegExp(r'\]\((www\.biblegateway\.com[^)\s]*)\)', caseSensitive: false),
    (m) => '](https://${m[1]})',
  );

  return text;
}

/// Normalizes markdown and linkifies Scripture / CCC references for display.
String prepareWwjdMarkdownForDisplay(String markdown) {
  return ReferenceLinkifier.linkify(normalizeMarkdownExternalLinks(markdown));
}

Future<void> launchExternalLink(
  BuildContext context,
  String raw, {
  String? linkText,
}) async {
  final cccUri = CccLinkResolver.resolve(raw, linkText ?? raw);
  final scriptureUri = ScriptureLinkResolver.buildNabrePassageUri(
    linkText ?? raw,
  );
  final uri = cccUri ?? normalizeExternalUri(raw) ?? scriptureUri;
  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $raw')),
      );
    }
    return;
  }

  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_blank' : null,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $uri')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $uri')),
      );
    }
  }
}
