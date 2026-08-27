import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/reference_linkifier.dart';
import 'package:wwjd_app/core/scripture_link_resolver.dart';

void main() {
  group('ScriptureLinkResolver', () {
    test('builds NABRE Bible Gateway URL with proper encoding', () {
      final uri = ScriptureLinkResolver.buildNabrePassageUri('Psalm 10:17-18');

      expect(uri, isNotNull);
      expect(
        uri.toString(),
        'https://www.biblegateway.com/passage/?search=Psalm+10%3A17-18&version=NABRE',
      );
    });

    test('builds URL for numbered epistle reference', () {
      final uri = ScriptureLinkResolver.buildNabrePassageUri('1 Corinthians 6:9-10');

      expect(uri, isNotNull);
      expect(
        uri.toString(),
        'https://www.biblegateway.com/passage/?search=1+Corinthians+6%3A9-10&version=NABRE',
      );
    });

    test('rejects non-scripture text', () {
      expect(
        ScriptureLinkResolver.buildNabrePassageUri('Kingdom Challenge'),
        isNull,
      );
    });
  });

  group('ReferenceLinkifier', () {
    test('linkifies bare CCC references', () {
      const input = 'See also CCC 2331 for related teaching.';
      final output = ReferenceLinkifier.linkify(input);

      expect(
        output,
        'See also [CCC 2331](https://www.scborromeo.org/ccc/para/2331.htm) for related teaching.',
      );
    });

    test('linkifies bare Scripture references', () {
      const input = 'Further light from John 3:16.';
      final output = ReferenceLinkifier.linkify(input);

      expect(output, contains('[John 3:16](https://www.biblegateway.com/passage/'));
      expect(output, contains('version=NABRE'));
    });

    test('rewrites existing Bible Gateway links to NABRE', () {
      const input =
          '[John 3:16](https://www.biblegateway.com/passage/?search=John+3%3A16&version=ESV)';
      final output = ReferenceLinkifier.linkify(input);

      expect(output, contains('version=NABRE'));
      expect(output, isNot(contains('version=ESV')));
    });

    test('rewrites Vatican CCC article links to paragraph pages', () {
      const input =
          '[CCC 1422](https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_two/article_5/the_anointing_of_the_sick.html)';
      final output = ReferenceLinkifier.linkify(input);

      expect(
        output,
        '[CCC 1422](https://www.scborromeo.org/ccc/para/1422.htm)',
      );
    });

    test('does not double-link existing markdown links', () {
      const input =
          '[Psalm 23:1](https://www.biblegateway.com/passage/?search=Psalm+23%3A1&version=NABRE)';
      final output = ReferenceLinkifier.linkify(input);

      expect(output, input);
    });
  });
}
