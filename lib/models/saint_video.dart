import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/saint_media_url.dart';

/// Firestore-backed saint video series. Video bytes live in Storage, not the app.
enum SaintPublishStatus {
  draft,
  published,
}

extension SaintPublishStatusLabels on SaintPublishStatus {
  String get label {
    switch (this) {
      case SaintPublishStatus.draft:
        return 'Draft';
      case SaintPublishStatus.published:
        return 'Published';
    }
  }

  String get firestoreValue {
    switch (this) {
      case SaintPublishStatus.draft:
        return 'draft';
      case SaintPublishStatus.published:
        return 'published';
    }
  }
}

SaintPublishStatus saintStatusFromFirestore(String? value) {
  return value == 'published'
      ? SaintPublishStatus.published
      : SaintPublishStatus.draft;
}

/// Timed caption line (burned-in video may still list lines for accessibility).
class SaintCaptionCue {
  const SaintCaptionCue({
    required this.startSec,
    required this.endSec,
    required this.text,
  });

  final double startSec;
  final double endSec;
  final String text;

  factory SaintCaptionCue.fromMap(Map<String, dynamic> map) {
    return SaintCaptionCue(
      startSec: _numToDouble(map['startSec']),
      endSec: _numToDouble(map['endSec']),
      text: map['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'startSec': startSec,
        'endSec': endSec,
        'text': text.trim(),
      };

  static double _numToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// One clip in an 8-segment saint series (about 15 seconds each).
class SaintSegment {
  static const int count = 8;
  static const int defaultDurationSec = 15;
  static const int maxScriptLength = 4000;
  static const int maxTitleLength = 120;
  static const int maxCaptionLength = 500;

  final int order;
  final String title;
  final String script;
  final String videoUrl;
  final int durationSec;
  final String caption;

  const SaintSegment({
    required this.order,
    required this.title,
    required this.script,
    required this.videoUrl,
    required this.durationSec,
    required this.caption,
  });

  bool get hasVideo => videoUrl.trim().isNotEmpty;

  factory SaintSegment.empty(int order) {
    return SaintSegment(
      order: order,
      title: 'Part $order',
      script: '',
      videoUrl: '',
      durationSec: defaultDurationSec,
      caption: '',
    );
  }

  factory SaintSegment.fromMap(Map<String, dynamic> map, int fallbackOrder) {
    final rawOrder = map['order'];
    final order = rawOrder is int
        ? rawOrder
        : int.tryParse(rawOrder?.toString() ?? '') ?? fallbackOrder;
    final rawDuration = map['durationSec'];
    final duration = rawDuration is int
        ? rawDuration
        : int.tryParse(rawDuration?.toString() ?? '') ?? defaultDurationSec;
    return SaintSegment(
      order: order.clamp(1, count),
      title: map['title']?.toString() ?? 'Part $fallbackOrder',
      script: map['script']?.toString() ?? '',
      videoUrl: map['videoUrl']?.toString() ?? '',
      durationSec: duration.clamp(1, 120),
      caption: map['caption']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order': order,
      'title': title.trim(),
      'script': script.trim(),
      'videoUrl': videoUrl.trim(),
      'durationSec': durationSec,
      'caption': caption.trim(),
    };
  }

  SaintSegment copyWith({
    int? order,
    String? title,
    String? script,
    String? videoUrl,
    int? durationSec,
    String? caption,
  }) {
    return SaintSegment(
      order: order ?? this.order,
      title: title ?? this.title,
      script: script ?? this.script,
      videoUrl: videoUrl ?? this.videoUrl,
      durationSec: durationSec ?? this.durationSec,
      caption: caption ?? this.caption,
    );
  }
}

/// `saints/{saintId}` metadata. Never embeds video bytes.
class SaintEntry {
  static const String collectionName = 'saints';
  static const String listPath = '/saints';
  static const String pathPrefix = '/saints';

  static const int maxNameLength = 120;
  static const int maxFeastDayLength = 80;
  static const int maxSummaryLength = 2000;

  final String id;
  final String name;
  final String feastDay;
  final String summary;
  final List<SaintSegment> segments;
  final SaintPublishStatus status;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Feast-day film fields (`saints/{slug}` feast schema).
  final int? feastMonth;
  final int? feastDayOfMonth;
  final String rank;
  final String quote;
  final String patronage;
  final String prayLine;
  final int? durationSec;
  final String? videoPortraitUrl;
  final String? videoLandscapeUrl;
  final String? posterPortraitUrl;
  final String? posterLandscapeUrl;
  final List<SaintCaptionCue> captionCues;
  final bool? publishedFlag;
  final String? sortDate;

  /// Firestore `slug` field (may differ from document id).
  final String firestoreSlug;

  const SaintEntry({
    required this.id,
    required this.name,
    required this.feastDay,
    required this.summary,
    required this.segments,
    required this.status,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
    this.feastMonth,
    this.feastDayOfMonth,
    this.rank = '',
    this.quote = '',
    this.patronage = '',
    this.prayLine = '',
    this.durationSec,
    this.videoPortraitUrl,
    this.videoLandscapeUrl,
    this.posterPortraitUrl,
    this.posterLandscapeUrl,
    this.captionCues = const [],
    this.publishedFlag,
    this.sortDate,
    this.firestoreSlug = '',
  });

  /// URL segment for `/saints/:slug` — prefers Firestore `slug`, else document id.
  String get slug {
    final s = firestoreSlug.trim();
    if (s.isNotEmpty) return s;
    return id;
  }

  /// Firestore document id (`saints/{id}`).
  String get documentId => id;

  bool get isFeastFilm {
    final portrait = videoPortraitUrl?.trim();
    final landscape = videoLandscapeUrl?.trim();
    return (portrait != null && portrait.isNotEmpty) ||
        (landscape != null && landscape.isNotEmpty);
  }

  String get feastDayLabel => feastDay;

  static String watchPath(String routeSlug) => '$pathPrefix/$routeSlug';

  static String storageObjectPath(String saintId, int order) =>
      '$collectionName/$saintId/seg-$order.mp4';

  /// Feast upload layout: `Saints/{sortDate}-{slug}/portrait.mp4` (Storage; Firestore stays `saints/`).
  static String feastStorageFolder(String sortDate, String slug) =>
      'Saints/$sortDate-$slug';

  /// When [videoLandscapeUrl] is unset, infer `Saints/…/landscape.mp4` from portrait or [sortDate].
  String? get inferredFeastLandscapeStoragePath {
    final explicit = videoLandscapeUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      final path = SaintMediaUrl.storagePathFromDownloadUrl(explicit);
      if (path != null) return path;
    }
    final portraitPath =
        SaintMediaUrl.storagePathFromDownloadUrl(videoPortraitUrl ?? '');
    if (portraitPath != null && portraitPath.endsWith('/portrait.mp4')) {
      return portraitPath.replaceFirst('/portrait.mp4', '/landscape.mp4');
    }
    final sd = sortDate?.trim();
    if (sd != null && sd.isNotEmpty) {
      return '${feastStorageFolder(sd, slug)}/landscape.mp4';
    }
    return null;
  }

  bool get isPublished =>
      publishedFlag == true || status == SaintPublishStatus.published;

  bool get canPublish =>
      name.trim().isNotEmpty &&
      segments.length == SaintSegment.count &&
      segments.every((s) => s.hasVideo);

  List<SaintSegment> get playableSegments {
    final ordered = [...segments]..sort((a, b) => a.order.compareTo(b.order));
    return ordered.where((s) => s.hasVideo).toList();
  }

  factory SaintEntry.draft({
    required String id,
    required String name,
    String feastDay = '',
    String summary = '',
  }) {
    return SaintEntry(
      id: id,
      name: name,
      feastDay: feastDay,
      summary: summary,
      segments: emptySegments(),
      status: SaintPublishStatus.draft,
    );
  }

  static List<SaintSegment> emptySegments() {
    return List<SaintSegment>.generate(
      SaintSegment.count,
      (i) => SaintSegment.empty(i + 1),
    );
  }

  /// Splits a pasted 8-part script on `---` or blank lines. Never treats text as video.
  static List<String> splitScriptPaste(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    var parts = trimmed.split(RegExp(r'\n\s*---+\s*\n'));
    if (parts.length < 2) {
      parts = trimmed.split(RegExp(r'\n\s*\n+'));
    }
    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .take(SaintSegment.count)
        .toList();
  }

  static String slugify(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length < 2) {
      throw ArgumentError('Enter a saint name that can become a URL id.');
    }
    return slug.length > 80 ? slug.substring(0, 80).replaceAll(RegExp(r'-+$'), '') : slug;
  }

  factory SaintEntry.fromMap(String id, Map<String, dynamic> map) {
    final rawSegments = map['segments'];
    final parsed = <SaintSegment>[];
    if (rawSegments is List) {
      for (var i = 0; i < rawSegments.length && i < SaintSegment.count; i++) {
        final item = rawSegments[i];
        if (item is Map<String, dynamic>) {
          parsed.add(SaintSegment.fromMap(item, i + 1));
        } else if (item is Map) {
          parsed.add(SaintSegment.fromMap(Map<String, dynamic>.from(item), i + 1));
        }
      }
    }
    while (parsed.length < SaintSegment.count) {
      parsed.add(SaintSegment.empty(parsed.length + 1));
    }
    parsed.sort((a, b) => a.order.compareTo(b.order));

    final rawCaptions = map['captions'];
    final cues = <SaintCaptionCue>[];
    if (rawCaptions is List) {
      for (final item in rawCaptions) {
        if (item is Map<String, dynamic>) {
          cues.add(SaintCaptionCue.fromMap(item));
        } else if (item is Map) {
          cues.add(SaintCaptionCue.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final publishedRaw = map['published'];
    final bool? publishedFlag = publishedRaw is bool ? publishedRaw : null;

    final feastMonthRaw = map['feastMonth'];
    final feastDayRaw = map['feastDay'];
    int? feastMonth;
    int? feastDayOfMonth;
    if (feastMonthRaw is int) {
      feastMonth = feastMonthRaw;
    } else if (feastMonthRaw != null) {
      feastMonth = int.tryParse(feastMonthRaw.toString());
    }
    if (feastDayRaw is int) {
      feastDayOfMonth = feastDayRaw;
    } else if (feastDayRaw != null) {
      feastDayOfMonth = int.tryParse(feastDayRaw.toString());
    }

    var feastDayLabel = map['feastDay']?.toString() ?? '';
    if (feastDayLabel.isEmpty && feastMonth != null && feastDayOfMonth != null) {
      feastDayLabel = '$feastMonth/$feastDayOfMonth';
    }

    final status = publishedFlag == true
        ? SaintPublishStatus.published
        : saintStatusFromFirestore(map['status']?.toString());

    final firestoreSlug = map['slug']?.toString().trim() ?? '';

    return SaintEntry(
      id: id,
      firestoreSlug: firestoreSlug,
      name: map['name']?.toString() ?? '',
      feastDay: feastDayLabel,
      summary: map['summary']?.toString() ?? '',
      segments: parsed,
      status: status,
      publishedAt: _parseTimestamp(map['publishedAt']),
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      feastMonth: feastMonth,
      feastDayOfMonth: feastDayOfMonth,
      rank: map['rank']?.toString() ?? '',
      quote: map['quote']?.toString() ?? '',
      patronage: map['patronage']?.toString() ?? '',
      prayLine: map['prayLine']?.toString() ?? '',
      durationSec: _parseInt(map['durationSec']),
      videoPortraitUrl: _optionalMediaUrl(map['videoPortraitUrl']),
      videoLandscapeUrl: _optionalMediaUrl(map['videoLandscapeUrl']),
      posterPortraitUrl: _optionalMediaUrl(map['posterPortraitUrl']),
      posterLandscapeUrl: _optionalMediaUrl(map['posterLandscapeUrl']),
      captionCues: cues,
      publishedFlag: publishedFlag,
      sortDate: map['sortDate']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  /// Rejects empty strings and literal "..." placeholders from bad seeds.
  static String? _optionalMediaUrl(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return null;
    if (s == '...' || s == '…') return null;
    return s;
  }

  Map<String, dynamic> toMap({
    required String updatedByUid,
    String? createdByUid,
    bool publishing = false,
    bool unpublishing = false,
  }) {
    return {
      'name': name.trim(),
      'feastDay': feastDay.trim(),
      'summary': summary.trim(),
      'segments': segments.map((s) => s.toMap()).toList(),
      'status': publishing
          ? SaintPublishStatus.published.firestoreValue
          : unpublishing
              ? SaintPublishStatus.draft.firestoreValue
              : status.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
      if (createdByUid != null) 'createdByUid': createdByUid,
      if (createdByUid != null) 'createdAt': FieldValue.serverTimestamp(),
      if (publishing) 'publishedAt': FieldValue.serverTimestamp(),
      if (unpublishing) 'publishedAt': FieldValue.delete(),
    };
  }

  SaintEntry copyWith({
    String? name,
    String? feastDay,
    String? summary,
    List<SaintSegment>? segments,
    SaintPublishStatus? status,
    DateTime? publishedAt,
    String? videoPortraitUrl,
    bool? publishedFlag,
  }) {
    return SaintEntry(
      id: id,
      name: name ?? this.name,
      feastDay: feastDay ?? this.feastDay,
      summary: summary ?? this.summary,
      segments: segments ?? this.segments,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      feastMonth: feastMonth,
      feastDayOfMonth: feastDayOfMonth,
      rank: rank,
      quote: quote,
      patronage: patronage,
      prayLine: prayLine,
      durationSec: durationSec,
      videoPortraitUrl: videoPortraitUrl ?? this.videoPortraitUrl,
      videoLandscapeUrl: videoLandscapeUrl,
      posterPortraitUrl: posterPortraitUrl,
      posterLandscapeUrl: posterLandscapeUrl,
      captionCues: captionCues,
      publishedFlag: publishedFlag ?? this.publishedFlag,
      sortDate: sortDate,
      firestoreSlug: firestoreSlug,
    );
  }

  String askWwjdPrompt() {
    final shortName = name.replaceFirst(RegExp(r'^St\.\s*'), '').trim();
    return 'What would Jesus have me learn from St. $shortName today?';
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
