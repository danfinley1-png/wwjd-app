import 'package:cloud_firestore/cloud_firestore.dart';



import 'reflection_source.dart';



/// A private journal thread owned by one user; contains many [ReflectionEntry] items.

class ReflectionThread {

  const ReflectionThread({

    required this.id,

    this.title,

    this.createdAt,

    this.updatedAt,

    this.entryCount = 0,

    this.lastEntryPreview,

    this.userId,

    this.linkedQuestionText,

    this.linkedResponseText,

    this.linkedGiftId,

    this.linkedJourneyId,

    this.linkedSourceTitle,

    this.source,

  });



  final String id;

  final String? title;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  final int entryCount;

  final String? lastEntryPreview;

  final String? userId;



  /// Original Seeking God's Wisdom question when saved from a session.

  final String? linkedQuestionText;



  /// WWJD response text for wisdom-session threads (private, for source navigation).

  final String? linkedResponseText;



  /// Sharing My Gifts activity id when saved from an activity.

  final String? linkedGiftId;



  /// Walk Together journey id when saved from a shared journey.

  final String? linkedJourneyId;



  /// Display title of the linked gift or journey.

  final String? linkedSourceTitle;



  /// e.g. [ReflectionSource.manual], [ReflectionSource.wisdomSession].

  final String? source;



  String get displayTitle {

    final trimmed = title?.trim();

    if (trimmed != null && trimmed.isNotEmpty) return trimmed;

    final preview = lastEntryPreview?.trim();

    if (preview != null && preview.isNotEmpty) {

      return preview.length > 60 ? '${preview.substring(0, 60)}…' : preview;

    }

    return 'Reflection';

  }



  String? get sourceLabel {

    if (!ReflectionSource.hasNavigableSource(source)) return null;

    return ReflectionSource.label(source);

  }



  factory ReflectionThread.fromMap(String id, Map<String, dynamic> map) {

    return ReflectionThread(

      id: id,

      title: map['title']?.toString(),

      createdAt: _parseTimestamp(map['createdAt']),

      updatedAt: _parseTimestamp(map['updatedAt']),

      entryCount: map['entryCount'] as int? ?? 0,

      lastEntryPreview: map['lastEntryPreview']?.toString(),

      userId: map['userId']?.toString(),

      linkedQuestionText: map['linkedQuestionText']?.toString(),

      linkedResponseText: map['linkedResponseText']?.toString(),

      linkedGiftId: map['linkedGiftId']?.toString(),

      linkedJourneyId: map['linkedJourneyId']?.toString(),

      linkedSourceTitle: map['linkedSourceTitle']?.toString(),

      source: map['source']?.toString(),

    );

  }



  Map<String, dynamic> toMap() {

    return {

      if (title != null) 'title': title!.trim().isEmpty ? null : title!.trim(),

      'entryCount': entryCount,

      if (lastEntryPreview != null) 'lastEntryPreview': lastEntryPreview,

      if (userId != null) 'userId': userId,

      if (linkedQuestionText != null && linkedQuestionText!.trim().isNotEmpty)

        'linkedQuestionText': linkedQuestionText!.trim(),

      if (linkedResponseText != null && linkedResponseText!.trim().isNotEmpty)

        'linkedResponseText': linkedResponseText!.trim(),

      if (linkedGiftId != null && linkedGiftId!.trim().isNotEmpty)

        'linkedGiftId': linkedGiftId!.trim(),

      if (linkedJourneyId != null && linkedJourneyId!.trim().isNotEmpty)

        'linkedJourneyId': linkedJourneyId!.trim(),

      if (linkedSourceTitle != null && linkedSourceTitle!.trim().isNotEmpty)

        'linkedSourceTitle': linkedSourceTitle!.trim(),

      if (source != null && source!.trim().isNotEmpty) 'source': source!.trim(),

      'updatedAt': FieldValue.serverTimestamp(),

    };

  }



  ReflectionThread copyWith({

    String? title,

    DateTime? createdAt,

    DateTime? updatedAt,

    int? entryCount,

    String? lastEntryPreview,

    String? userId,

    String? linkedQuestionText,

    String? linkedResponseText,

    String? linkedGiftId,

    String? linkedJourneyId,

    String? linkedSourceTitle,

    String? source,

  }) {

    return ReflectionThread(

      id: id,

      title: title ?? this.title,

      createdAt: createdAt ?? this.createdAt,

      updatedAt: updatedAt ?? this.updatedAt,

      entryCount: entryCount ?? this.entryCount,

      lastEntryPreview: lastEntryPreview ?? this.lastEntryPreview,

      userId: userId ?? this.userId,

      linkedQuestionText: linkedQuestionText ?? this.linkedQuestionText,

      linkedResponseText: linkedResponseText ?? this.linkedResponseText,

      linkedGiftId: linkedGiftId ?? this.linkedGiftId,

      linkedJourneyId: linkedJourneyId ?? this.linkedJourneyId,

      linkedSourceTitle: linkedSourceTitle ?? this.linkedSourceTitle,

      source: source ?? this.source,

    );

  }



  static DateTime? _parseTimestamp(dynamic value) {

    if (value == null) return null;

    if (value is Timestamp) return value.toDate();

    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());

  }

}

