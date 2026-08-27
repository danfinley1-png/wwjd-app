import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/catholic_prayers/catholic_prayer_catalog.dart';
import 'package:wwjd_app/core/prayer_link.dart';

void main() {
  group('CatholicPrayerCatalog', () {
    test('includes expanded prayer library entries', () {
      const expectedIds = [
        'holy_rosary',
        'benediction',
        'litany_of_the_saints',
      ];

      for (final id in expectedIds) {
        expect(CatholicPrayerCatalog.byId(id), isNotNull, reason: id);
      }
    });

    test('search finds rosary, benediction, and litany entries', () {
      expect(CatholicPrayerCatalog.search('rosary').map((p) => p.id), contains('holy_rosary'));
      expect(CatholicPrayerCatalog.search('benediction').map((p) => p.id), contains('benediction'));
      expect(CatholicPrayerCatalog.search('litany of the saints').map((p) => p.id),
          contains('litany_of_the_saints'));
    });

    test('rosary entry lists all four mystery sets', () {
      final rosary = CatholicPrayerCatalog.byId('holy_rosary')!;
      expect(rosary.body, contains('JOYFUL MYSTERIES'));
      expect(rosary.body, contains('SORROWFUL MYSTERIES'));
      expect(rosary.body, contains('GLORIOUS MYSTERIES'));
      expect(rosary.body, contains('LUMINOUS MYSTERIES'));
      expect(rosary.body, contains('The Annunciation'));
      expect(rosary.body, contains('The Institution of the Eucharist'));
    });

    test('benediction entry includes standard adoration prayers', () {
      final benediction = CatholicPrayerCatalog.byId('benediction')!;
      expect(benediction.body, contains('O SALUTARIS HOSTIA'));
      expect(benediction.body, contains('TANTUM ERGO'));
      expect(benediction.body, contains('DIVINE PRAISES'));
    });

    test('includes requested starter prayers', () {
      const expectedIds = [
        'our_father',
        'hail_mary',
        'glory_be',
        'apostles_creed',
        'angelus',
        'regina_caeli',
        'memorare',
        'salve_regina',
        'act_of_contrition',
        'anima_christi',
        'come_holy_spirit',
        'prayer_to_st_michael',
        'guardian_angel',
        'morning_offering',
        'grace_before_meals',
      ];

      for (final id in expectedIds) {
        expect(CatholicPrayerCatalog.byId(id), isNotNull, reason: id);
      }
    });

    test('search filters by display name', () {
      final results = CatholicPrayerCatalog.search('hail');
      expect(results.map((p) => p.id), contains('hail_mary'));
      expect(results.map((p) => p.id), contains('salve_regina'));
    });

    test('search returns all prayers when query is empty', () {
      expect(
        CatholicPrayerCatalog.search('').length,
        CatholicPrayerCatalog.prayers.length,
      );
    });

    test('sortedByTitle is alphabetical', () {
      final titles =
          CatholicPrayerCatalog.sortedByTitle.map((p) => p.displayName).toList();
      final sorted = List<String>.from(titles)..sort();
      expect(titles, sorted);
    });
  });

  group('PrayerLink', () {
    test('builds stable web-friendly paths', () {
      expect(PrayerLink.path('hail_mary'), '/prayer/hail_mary');
      expect(PrayerLink.path('holy_rosary'), '/prayer/holy_rosary');
      expect(PrayerLink.url('litany_of_the_saints'), contains('/prayer/litany_of_the_saints'));
    });
  });
}
