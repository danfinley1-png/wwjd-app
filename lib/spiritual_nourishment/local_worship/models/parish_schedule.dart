/// One row in the parish worship-times template. Always shown, even when empty.
class ScheduleRow {
  const ScheduleRow({required this.label, required this.value});

  final String label;
  final String value;

  bool get isListed => value.trim().isNotEmpty && value != ParishSchedule.notListed;
}

/// Extensible schedule template used on every parish card and adoration result.
class ParishSchedule {
  const ParishSchedule({
    this.massTimes = notListed,
    this.communionService = notListed,
    this.confession = notListed,
    this.holyDays = notListed,
    this.eucharisticAdoration = notListed,
    this.openForPrayer = notListed,
    this.perpetualAdoration = notListed,
  });

  static const String notListed = 'Not listed';
  static const String perpetualLabel = 'Perpetual';

  final String massTimes;
  final String communionService;
  final String confession;
  final String holyDays;
  final String eucharisticAdoration;
  final String openForPrayer;
  final String perpetualAdoration;

  ParishSchedule copyWith({
    String? massTimes,
    String? communionService,
    String? confession,
    String? holyDays,
    String? eucharisticAdoration,
    String? openForPrayer,
    String? perpetualAdoration,
  }) {
    return ParishSchedule(
      massTimes: massTimes ?? this.massTimes,
      communionService: communionService ?? this.communionService,
      confession: confession ?? this.confession,
      holyDays: holyDays ?? this.holyDays,
      eucharisticAdoration: eucharisticAdoration ?? this.eucharisticAdoration,
      openForPrayer: openForPrayer ?? this.openForPrayer,
      perpetualAdoration: perpetualAdoration ?? this.perpetualAdoration,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'massTimes': massTimes,
      'communionService': communionService,
      'confession': confession,
      'holyDays': holyDays,
      'eucharisticAdoration': eucharisticAdoration,
      'openForPrayer': openForPrayer,
      'perpetualAdoration': perpetualAdoration,
    };
  }

  factory ParishSchedule.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ParishSchedule();
    return ParishSchedule(
      massTimes: _display(map['massTimes']?.toString()),
      communionService: _display(map['communionService']?.toString()),
      confession: _display(map['confession']?.toString()),
      holyDays: _display(map['holyDays']?.toString()),
      eucharisticAdoration: _display(map['eucharisticAdoration']?.toString()),
      openForPrayer: _display(map['openForPrayer']?.toString()),
      perpetualAdoration: _display(map['perpetualAdoration']?.toString()),
    );
  }

  bool get offersPerpetualAdoration =>
      signalsPerpetualAdoration(perpetualAdoration) ||
      signalsPerpetualAdoration(eucharisticAdoration);

  List<ScheduleRow> get rows => [
        ScheduleRow(label: 'Mass times', value: _display(massTimes)),
        ScheduleRow(label: 'Communion service', value: _display(communionService)),
        ScheduleRow(label: 'Confession', value: _display(confession)),
        ScheduleRow(label: 'Holy Days', value: _display(holyDays)),
        ScheduleRow(
          label: 'Eucharistic Adoration',
          value: _display(eucharisticAdoration),
        ),
        ScheduleRow(
          label: 'Open for prayer / church open hours',
          value: _display(openForPrayer),
        ),
        ScheduleRow(
          label: 'Perpetual adoration',
          value: _display(perpetualAdoration),
        ),
      ];

  static String _display(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? notListed : trimmed;
  }

  factory ParishSchedule.fromWorshipTimes(Iterable<dynamic>? rawTimes) {
    if (rawTimes == null) return const ParishSchedule();

    final mass = <String>[];
    final communion = <String>[];
    final confession = <String>[];
    final holyDays = <String>[];
    final adorationHours = <String>[];
    final open = <String>[];
    var foundPerpetualAdoration = false;

    for (final entry in rawTimes) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final type = (map['service_typename'] ?? map['serviceType'] ?? '')
          .toString()
          .toLowerCase();
      final comment = (map['comment'] ?? '').toString();
      final isAdoration = _isAdorationService(type);
      final perpetual = isPerpetualAdorationEntry(
        isPerpetualFlag: map['is_perpetual'],
        serviceType: type,
        comment: comment,
        isAdorationService: isAdoration,
      );

      if (perpetual) {
        foundPerpetualAdoration = true;
        final extra = formatWorshipTimeLine(
          _withoutPerpetualOnlyComment(map, comment),
        );
        if (extra != null) adorationHours.add(extra);
        continue;
      }

      final line = formatWorshipTimeLine(map);
      if (line == null) continue;

      if (_matchesAny(type, const [
        'confession',
        'reconciliation',
        'penance',
      ])) {
        confession.add(line);
      } else if (_matchesAny(type, const ['communion'])) {
        communion.add(line);
      } else if (_matchesAny(type, const ['holy day', 'holy-day'])) {
        holyDays.add(line);
      } else if (isAdoration) {
        adorationHours.add(line);
      } else if (_matchesAny(type, const [
        'open',
        'visit',
        'prayer',
        'church open',
      ])) {
        open.add(line);
      } else if (_matchesAny(type, const [
        'weekend',
        'weekday',
        'mass',
        'vigil',
        'sunday',
      ])) {
        mass.add(line);
      }
    }

    final adorationLines = <String>[
      if (foundPerpetualAdoration) perpetualLabel,
      ...adorationHours,
    ];

    return ParishSchedule(
      massTimes: _join(mass),
      communionService: _join(communion),
      confession: _join(confession),
      holyDays: _join(holyDays),
      eucharisticAdoration: _join(adorationLines),
      openForPrayer: _join(open),
      perpetualAdoration:
          foundPerpetualAdoration ? perpetualLabel : notListed,
    );
  }

  /// MassTimes Adoration / Adorations (and similar) service types.
  static bool _isAdorationService(String type) {
    return _matchesAny(type, const [
      'adoration',
      'exposition',
      'benediction',
    ]);
  }

  /// Case-insensitive perpetual-adoration signals from MassTimes structured fields.
  ///
  /// Matches: Perpetual, Perpetual Adoration, 24 hour / 24-hour / 24hr, Always
  /// (Always only on an Adoration service). Does not treat “Perpetual Help”
  /// devotions as perpetual adoration.
  static bool isPerpetualAdorationEntry({
    required dynamic isPerpetualFlag,
    required String serviceType,
    required String comment,
    required bool isAdorationService,
  }) {
    if (!isAdorationService) return false;
    if (_truthyFlag(isPerpetualFlag)) return true;
    return textSignalsPerpetualAdoration('$serviceType $comment');
  }

  static bool signalsPerpetualAdoration(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.toLowerCase() == notListed.toLowerCase()) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower == 'no' || lower == 'not offered') return false;
    return textSignalsPerpetualAdoration(trimmed);
  }

  static bool textSignalsPerpetualAdoration(String text) {
    final lower = text.toLowerCase();
    if (lower.trim().isEmpty) return false;
    final withoutHelp = lower.replaceAll(
      RegExp(r'perpetual\s+help|mother of perpetual help|\bolph\b'),
      ' ',
    );
    if (RegExp(r'\bperpetual\b').hasMatch(withoutHelp)) return true;
    if (RegExp(r'\b24[\s\-]?hours?\b|\b24hr\b|\b24 hrs?\b').hasMatch(withoutHelp)) {
      return true;
    }
    if (RegExp(r'\balways\b').hasMatch(withoutHelp) &&
        !RegExp(r'livestream|live[\s\-]?stream|streamed').hasMatch(withoutHelp)) {
      return true;
    }
    return false;
  }

  static bool _truthyFlag(dynamic value) {
    if (value == true || value == 1) return true;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == 'yes' || text == '1';
  }

  static Map<String, dynamic> _withoutPerpetualOnlyComment(
    Map<String, dynamic> map,
    String comment,
  ) {
    if (!textSignalsPerpetualAdoration(comment)) return map;
    final leftover = comment
        .replaceAll(
          RegExp(
            r'perpetual(\s+adoration)?|24[\s\-]?hours?|24hr|24 hrs?|\balways\b(\s+open)?',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (leftover.isEmpty) {
      return {...map, 'comment': ''};
    }
    return map;
  }

  static String _join(List<String> lines) =>
      lines.isEmpty ? notListed : lines.join('\n');

  static bool _matchesAny(String type, List<String> needles) {
    for (final needle in needles) {
      if (type.contains(needle)) return true;
    }
    return false;
  }

  /// Builds a readable line from a MassTimes `church_worship_times` entry.
  static String? formatWorshipTimeLine(Map<String, dynamic> map) {
    final start = map['time_start']?.toString() ?? map['timeStart']?.toString();
    final end = map['time_end']?.toString() ?? map['timeEnd']?.toString();
    final day = dayName(map['day_of_week'] ?? map['dayOfWeek']);
    final comment = map['comment']?.toString().trim() ?? '';

    if (_isPlaceholderTime(start, end) && comment.isEmpty && day.isEmpty) {
      return null;
    }

    final parts = <String>[];
    if (day.isNotEmpty) parts.add(day);

    final startLabel = formatApiClock(start);
    final endLabel = formatApiClock(end);
    if (startLabel.isNotEmpty &&
        endLabel.isNotEmpty &&
        startLabel != endLabel &&
        !_isMidnightClock(endLabel)) {
      parts.add('$startLabel–$endLabel');
    } else if (startLabel.isNotEmpty && !_isPlaceholderClock(startLabel, endLabel)) {
      parts.add(startLabel);
    }

    if (comment.isNotEmpty) parts.add('— $comment');

    final hasTimeOrDay = day.isNotEmpty ||
        (startLabel.isNotEmpty && !_isPlaceholderClock(startLabel, endLabel)) ||
        comment.isNotEmpty;
    if (!hasTimeOrDay) return null;

    final language = map['language']?.toString().trim() ?? '';
    if (language.isNotEmpty &&
        hasTimeOrDay &&
        language.toLowerCase() != 'english') {
      parts.add('($language)');
    }

    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static String dayName(dynamic dayOfWeek) {
    if (dayOfWeek == null) return '';
    if (dayOfWeek is num) return _dayFromIndex(dayOfWeek.round());

    final value = dayOfWeek.toString().trim();
    if (value.isEmpty || value == '99') return '';

    final asInt = int.tryParse(value.split('.').first);
    if (asInt != null) return _dayFromIndex(asInt);

    final lower = value.toLowerCase();
    if (lower.startsWith('sun')) return 'Sunday';
    if (lower.startsWith('mon')) return 'Monday';
    if (lower.startsWith('tue')) return 'Tuesday';
    if (lower.startsWith('wed')) return 'Wednesday';
    if (lower.startsWith('thu')) return 'Thursday';
    if (lower.startsWith('fri')) return 'Friday';
    if (lower.startsWith('sat')) return 'Saturday';
    return '';
  }

  static String _dayFromIndex(int index) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    if (index >= 0 && index <= 6) return days[index];
    if (index == 7) return 'Sunday';
    return '';
  }

  static String formatApiClock(String? raw) {
    if (raw == null) return '';
    final text = raw.trim();
    if (text.isEmpty) return '';

    final ampm = RegExp(
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AP]M)',
      caseSensitive: false,
    ).firstMatch(text);
    if (ampm != null) {
      return _clock(int.parse(ampm.group(1)!), int.parse(ampm.group(2)!), ampm.group(4));
    }

    final iso = RegExp(r'T(\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(text);
    if (iso != null) {
      return _clock(int.parse(iso.group(1)!), int.parse(iso.group(2)!), null);
    }

    final dated = RegExp(
      r'(?:\d{1,4}[/-]\d{1,2}[/-]\d{1,4}|\d{4}-\d{2}-\d{2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(text);
    if (dated != null) {
      return _clock(int.parse(dated.group(1)!), int.parse(dated.group(2)!), null);
    }

    final bare = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(text);
    if (bare != null) {
      return _clock(int.parse(bare.group(1)!), int.parse(bare.group(2)!), null);
    }

    return '';
  }

  static String _clock(int hour, int minute, String? ampmRaw) {
    var h = hour;
    final minuteLabel = minute.toString().padLeft(2, '0');
    if (ampmRaw != null && ampmRaw.isNotEmpty) {
      final ampm = ampmRaw.toUpperCase().startsWith('P') ? 'PM' : 'AM';
      if (h == 0) h = 12;
      return '$h:$minuteLabel $ampm';
    }

    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$minuteLabel $ampm';
  }

  static bool _isPlaceholderTime(String? start, String? end) {
    return _isMidnightValue(start) &&
        (end == null || end.trim().isEmpty || _isMidnightValue(end));
  }

  static bool _isPlaceholderClock(String startLabel, String endLabel) {
    return _isMidnightClock(startLabel) &&
        (endLabel.isEmpty || _isMidnightClock(endLabel));
  }

  static bool _isMidnightClock(String label) =>
      label.toUpperCase() == '12:00 AM';

  static bool _isMidnightValue(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final upper = value.toUpperCase();
    if (upper.contains('12:00:00 AM') ||
        (upper.contains('12:00 AM') && !upper.contains('12:00 PM'))) {
      return true;
    }
    if (RegExp(r'\b00:00(?::00)?\b').hasMatch(value)) return true;
    return formatApiClock(value) == '12:00 AM';
  }
}
