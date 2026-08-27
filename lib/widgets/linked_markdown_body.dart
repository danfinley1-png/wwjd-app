import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/external_link.dart';

/// Renders WWJD markdown with tappable external links (Scripture, CCC, etc.).
class LinkedMarkdownBody extends StatelessWidget {
  const LinkedMarkdownBody({
    super.key,
    required this.data,
    this.styleSheet,
  });

  final String data;
  final MarkdownStyleSheet? styleSheet;

  static MarkdownStyleSheet defaultStyleSheet() {
    return MarkdownStyleSheet(
      p: const TextStyle(fontSize: 16, height: 1.55),
      a: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: prepareWwjdMarkdownForDisplay(data),
      onTapLink: (text, href, title) {
        if (href != null) {
          launchExternalLink(context, href, linkText: text);
        }
      },
      styleSheet: styleSheet ?? defaultStyleSheet(),
    );
  }
}
