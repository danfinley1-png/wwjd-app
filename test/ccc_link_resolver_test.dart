import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/ccc_link_resolver.dart';

void main() {
  group('CccLinkResolver', () {
    test('956 resolves to dedicated paragraph page, not article 8', () {
      final wrongUrl =
          'https://www.vatican.va/content/catechism/en/part_one/section_two/chapter_three/article_8.html';
      final uri = CccLinkResolver.resolve(wrongUrl, 'CCC 956');

      expect(uri, isNotNull);
      expect(uri!.toString(), 'https://www.scborromeo.org/ccc/para/956.htm');
    });

    test('1422 resolves to dedicated paragraph page', () {
      final wrongUrl =
          'https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_two/article_5/the_anointing_of_the_sick.html';
      final uri = CccLinkResolver.resolve(wrongUrl, 'CCC 1422');

      expect(uri, isNotNull);
      expect(uri!.toString(), 'https://www.scborromeo.org/ccc/para/1422.htm');
    });

    test('1499 resolves to dedicated paragraph page', () {
      final url =
          'https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_two/article_5/the_anointing_of_the_sick.html';
      final uri = CccLinkResolver.resolve(url, 'CCC 1499');

      expect(uri, isNotNull);
      expect(uri!.toString(), 'https://www.scborromeo.org/ccc/para/1499.htm');
    });

    test('extracts paragraph from link label', () {
      expect(CccLinkResolver.extractParagraphNumber('CCC 1422'), 1422);
      expect(CccLinkResolver.extractParagraphNumber('Catechism paragraph 2290'), 2290);
    });

    test('returns null for non-catechism links', () {
      expect(
        CccLinkResolver.resolve(
          'https://www.biblegateway.com/passage/?search=John+3%3A16',
          'John 3:16',
        ),
        isNull,
      );
    });

    test('returns null for out-of-range paragraph numbers', () {
      expect(
        CccLinkResolver.resolve(
          'https://www.vatican.va/content/catechism/en/index.html',
          'CCC 3000',
        ),
        isNull,
      );
    });
  });
}
