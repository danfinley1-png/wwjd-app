import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/saints/saint_calendar.dart';
import 'package:wwjd_app/models/saint_video.dart';

SaintEntry _feast({
  required String id,
  required int month,
  required int day,
  String sortDate = '',
}) {
  return SaintEntry(
    id: id,
    name: id,
    feastDay: '',
    summary: '',
    segments: SaintEntry.emptySegments(),
    status: SaintPublishStatus.draft,
    feastMonth: month,
    feastDayOfMonth: day,
    publishedFlag: true,
    videoPortraitUrl: 'https://example.com/v.mp4',
    sortDate: sortDate.isEmpty ? '2026-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}' : sortDate,
  );
}

void main() {
  setUpAll(SaintCalendar.ensureInitialized);

  test('Sep 23 selects Pio as today', () {
    final ref = DateTime.utc(2026, 9, 23, 16);
    final pio = _feast(id: 'pio-pietrelcina', month: 9, day: 23);
    final claver = _feast(id: 'peter-claver', month: 9, day: 9);
    expect(SaintCalendar.isFeastToday(pio, ref), isTrue);
    expect(SaintCalendar.isFeastToday(claver, ref), isFalse);
    expect(SaintCalendar.saintForToday([pio, claver], ref)?.slug, 'pio-pietrelcina');
  });

  test('Before Sep 23 Claver is past; Pio is upcoming', () {
    final ref = DateTime.utc(2026, 9, 10, 16);
    final pio = _feast(id: 'pio-pietrelcina', month: 9, day: 23);
    final claver = _feast(id: 'peter-claver', month: 9, day: 9);
    expect(SaintCalendar.saintForToday([pio, claver], ref), isNull);
    expect(SaintCalendar.nextUpcomingSaint([pio, claver], ref)?.slug, 'pio-pietrelcina');
    expect(SaintCalendar.daysUntilFeast(pio, ref), 12);
  });

  test('Sep 29 selects Holy Archangels as today', () {
    final ref = DateTime.utc(2026, 9, 29, 16);
    final archangels = _feast(id: 'holy-archangels', month: 9, day: 29);
    final pio = _feast(id: 'pio-pietrelcina', month: 9, day: 23);
    expect(SaintCalendar.isFeastToday(archangels, ref), isTrue);
    expect(SaintCalendar.saintForToday([pio, archangels], ref)?.slug, 'holy-archangels');
  });
}
