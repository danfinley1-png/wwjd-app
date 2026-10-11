import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/models/saint_video.dart';

void main() {
  group('SaintSegment', () {
    test('empty creates placeholder with correct order', () {
      final seg = SaintSegment.empty(3);
      expect(seg.order, 3);
      expect(seg.hasVideo, isFalse);
      expect(seg.videoUrl, isEmpty);
    });

    test('fromMap clamps order to 1–8', () {
      final seg = SaintSegment.fromMap({'order': 99, 'title': 't', 'script': '', 'videoUrl': '', 'durationSec': 15, 'caption': ''}, 2);
      expect(seg.order, 8);
    });

    test('copyWith updates videoUrl only', () {
      final seg = SaintSegment.empty(1);
      final updated = seg.copyWith(videoUrl: 'https://storage.example.com/saints/a/seg-1.mp4');
      expect(updated.hasVideo, isTrue);
      expect(updated.order, 1);
    });

    test('toMap round-trips cleanly', () {
      final seg = SaintSegment(
        order: 4,
        title: 'Miracles',
        script: 'Script text',
        videoUrl: 'https://example.com/seg-4.mp4',
        durationSec: 15,
        caption: 'A miracle story.',
      );
      final map = seg.toMap();
      expect(map['order'], 4);
      expect(map['title'], 'Miracles');
      expect(map['videoUrl'], 'https://example.com/seg-4.mp4');
    });
  });

  group('SaintEntry', () {
    test('draft has 8 empty segments', () {
      final entry = SaintEntry.draft(id: 'st-joseph', name: 'St. Joseph');
      expect(entry.segments, hasLength(SaintSegment.count));
      expect(entry.isPublished, isFalse);
      expect(entry.canPublish, isFalse);
      expect(entry.playableSegments, isEmpty);
    });

    test('canPublish requires all 8 clips', () {
      final segs = List<SaintSegment>.generate(SaintSegment.count, (i) {
        return SaintSegment.empty(i + 1).copyWith(
          videoUrl: 'https://example.com/saints/s/seg-${i + 1}.mp4',
        );
      });
      final entry = SaintEntry(
        id: 'st-x',
        name: 'St. X',
        feastDay: '',
        summary: '',
        segments: segs,
        status: SaintPublishStatus.draft,
      );
      expect(entry.canPublish, isTrue);
    });

    test('slugify produces lowercase-hyphenated id', () {
      expect(SaintEntry.slugify('St. Francis of Assisi'), 'st-francis-of-assisi');
      expect(SaintEntry.slugify('Maximilian Kolbe'), 'maximilian-kolbe');
    });

    test('slugify rejects empty name', () {
      expect(() => SaintEntry.slugify('   '), throwsArgumentError);
    });

    test('splitScriptPaste on --- separator', () {
      final raw = List.generate(8, (i) => 'Part ${i + 1} text.').join('\n---\n');
      final parts = SaintEntry.splitScriptPaste(raw);
      expect(parts, hasLength(8));
      expect(parts.first, 'Part 1 text.');
    });

    test('splitScriptPaste caps at 8 parts', () {
      final raw = List.generate(12, (i) => 'Segment $i').join('\n\n');
      final parts = SaintEntry.splitScriptPaste(raw);
      expect(parts.length, lessThanOrEqualTo(8));
    });

    test('storageObjectPath is correct', () {
      expect(
        SaintEntry.storageObjectPath('st-therese', 3),
        'saints/st-therese/seg-3.mp4',
      );
    });

    test('inferredFeastLandscapeStoragePath from portrait URL', () {
      const portrait =
          'https://firebasestorage.googleapis.com/v0/b/wwjd-di-e36ce.firebasestorage.app/o/Saints%2F2026-09-23-pio-pietrelcina%2Fportrait.mp4?alt=media&token=x';
      final entry = SaintEntry(
        id: 'pio-pietrelcina',
        firestoreSlug: 'pio-pietrelcina',
        name: 'St. Pio',
        feastDay: '',
        summary: '',
        segments: SaintEntry.emptySegments(),
        status: SaintPublishStatus.published,
        videoPortraitUrl: portrait,
        publishedFlag: true,
        sortDate: '2026-09-23',
      );
      expect(
        entry.inferredFeastLandscapeStoragePath,
        'Saints/2026-09-23-pio-pietrelcina/landscape.mp4',
      );
    });

    test('fromMap padds missing segments', () {
      final map = {
        'name': 'Test Saint',
        'feastDay': '',
        'summary': '',
        'segments': [
          {'order': 1, 'title': 'Pt 1', 'script': '', 'videoUrl': '', 'durationSec': 15, 'caption': ''},
        ],
        'status': 'draft',
      };
      final entry = SaintEntry.fromMap('test', map);
      expect(entry.segments, hasLength(8));
    });
  });

  group('SaintPublishStatus', () {
    test('label and firestoreValue round-trip', () {
      expect(SaintPublishStatus.draft.firestoreValue, 'draft');
      expect(saintStatusFromFirestore('published'), SaintPublishStatus.published);
      expect(saintStatusFromFirestore(null), SaintPublishStatus.draft);
    });
  });
}
