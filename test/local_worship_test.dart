import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/spiritual_nourishment/local_worship/models/location_profile_kind.dart';
import 'package:wwjd_app/spiritual_nourishment/local_worship/models/parish.dart';
import 'package:wwjd_app/spiritual_nourishment/local_worship/models/parish_schedule.dart';
import 'package:wwjd_app/spiritual_nourishment/local_worship/models/worship_preferences.dart';
import 'package:wwjd_app/spiritual_nourishment/local_worship/services/mass_times_links.dart';
import 'package:wwjd_app/spiritual_nourishment/local_worship/services/parish_ranking.dart';

void main() {
  group('LocationProfileKind', () {
    test('active profiles are neighborhood and school', () {
      expect(
        LocationProfileKind.active.map((k) => k.id),
        ['neighborhood', 'school'],
      );
      expect(LocationProfileKind.work.id, 'work');
      expect(LocationProfileKind.travel.id, 'travel');
    });

    test('school is a manual chapel template without location lookup', () {
      expect(LocationProfileKind.neighborhood.usesLocationLookup, isTrue);
      expect(LocationProfileKind.school.usesLocationLookup, isFalse);
      expect(LocationProfileKind.school.tabLabel, 'My School');
      expect(
        LocationProfileKind.school.templateIntro,
        contains('organization administrator'),
      );
    });
  });

  group('ParishSchedule', () {
    test('keeps every template row as Not listed when empty', () {
      const schedule = ParishSchedule();
      expect(schedule.rows.map((r) => r.label), [
        'Mass times',
        'Communion service',
        'Confession',
        'Holy Days',
        'Eucharistic Adoration',
        'Open for prayer / church open hours',
        'Perpetual adoration',
      ]);
      expect(
        schedule.rows.every((r) => r.value == ParishSchedule.notListed),
        isTrue,
      );
    });

    test('maps MassTimes worship times into the template', () {
      final schedule = ParishSchedule.fromWorshipTimes([
        {
          'day_of_week': '0',
          'time_start': '1/1/1900 10:00:00 AM',
          'time_end': null,
          'language': 'English',
          'service_typename': 'Weekend',
          'is_perpetual': false,
          'comment': '',
        },
        {
          'day_of_week': '6',
          'time_start': '1/1/1900 4:00:00 PM',
          'service_typename': 'Confession',
          'language': 'English',
          'is_perpetual': false,
        },
        {
          'day_of_week': '99',
          'time_start': '1/1/1900 12:00:00 AM',
          'service_typename': 'Adoration',
          'is_perpetual': true,
          'comment': 'Chapel',
        },
      ]);

      expect(schedule.massTimes, contains('Sunday 10:00 AM'));
      expect(schedule.confession, contains('Saturday 4:00 PM'));
      expect(schedule.communionService, ParishSchedule.notListed);
      expect(schedule.eucharisticAdoration, contains('Perpetual'));
      expect(schedule.eucharisticAdoration, contains('Chapel'));
      expect(schedule.perpetualAdoration, ParishSchedule.perpetualLabel);
      expect(schedule.offersPerpetualAdoration, isTrue);
    });

    test('fills Adoration as Perpetual from MassTimes Adorations + is_perpetual', () {
      final schedule = ParishSchedule.fromWorshipTimes([
        {
          'comment': 'Perpetual Adoration',
          'day_of_week': null,
          'is_perpetual': true,
          'language': null,
          'service_typename': 'Adorations',
          'time_end': '',
          'time_start': '',
        },
        {
          'day_of_week': 'Sunday',
          'time_start': '10:00:00',
          'service_typename': 'Weekend',
          'is_perpetual': false,
        },
        {
          'day_of_week': 'Saturday',
          'time_start': '15:30:00',
          'time_end': '16:00:00',
          'service_typename': 'Confessions',
          'is_perpetual': false,
        },
        {
          'day_of_week': 'Monday',
          'time_start': '09:00:00',
          'service_typename': 'Holy Days',
          'is_perpetual': false,
          'comment': 'When a Holy Day falls on Monday',
        },
      ]);

      expect(schedule.eucharisticAdoration, ParishSchedule.perpetualLabel);
      expect(schedule.perpetualAdoration, ParishSchedule.perpetualLabel);
      expect(schedule.offersPerpetualAdoration, isTrue);
      expect(schedule.massTimes, contains('Sunday 10:00 AM'));
      expect(schedule.confession, contains('Saturday 3:30 PM'));
      expect(schedule.holyDays, contains('Monday 9:00 AM'));
    });

    test('treats empty-clock perpetual Adoration as Perpetual, not Not listed', () {
      final schedule = ParishSchedule.fromWorshipTimes([
        {
          'service_typename': 'Adoration',
          'is_perpetual': 'true',
          'day_of_week': '99',
          'time_start': '1/1/1900 12:00:00 AM',
          'time_end': '',
          'comment': '',
        },
      ]);
      expect(schedule.eucharisticAdoration, ParishSchedule.perpetualLabel);
      expect(schedule.offersPerpetualAdoration, isTrue);
    });

    test('keeps non-perpetual Adoration hours and does not mark perpetual', () {
      final schedule = ParishSchedule.fromWorshipTimes([
        {
          'service_typename': 'Adorations',
          'is_perpetual': false,
          'day_of_week': 'Thursday',
          'time_start': '18:30:00',
          'time_end': '20:00:00',
          'comment': '',
        },
      ]);
      expect(schedule.eucharisticAdoration, contains('Thursday 6:30 PM'));
      expect(schedule.eucharisticAdoration, isNot(contains('Perpetual')));
      expect(schedule.perpetualAdoration, ParishSchedule.notListed);
      expect(schedule.offersPerpetualAdoration, isFalse);
    });

    test('keeps extra Adoration hours when MassTimes also marks perpetual', () {
      final schedule = ParishSchedule.fromWorshipTimes([
        {
          'service_typename': 'Adorations',
          'is_perpetual': true,
          'comment': 'Perpetual',
          'time_start': '',
          'time_end': '',
        },
        {
          'service_typename': 'Adorations',
          'is_perpetual': false,
          'day_of_week': 'Monday',
          'time_start': '08:00:00',
          'time_end': '08:30:00',
        },
      ]);
      expect(schedule.eucharisticAdoration, startsWith('Perpetual'));
      expect(schedule.eucharisticAdoration, contains('Monday 8:00 AM'));
      expect(schedule.offersPerpetualAdoration, isTrue);
    });

    test('does not treat Perpetual Help or Always-livestreamed Mass as adoration', () {
      final schedule = ParishSchedule.fromWorshipTimes([
        {
          'service_typename': 'Devotions',
          'is_perpetual': false,
          'day_of_week': 'Tuesday',
          'time_start': '11:30:00',
          'comment': 'Our Mother of Perpetual Help Devotion and Mass',
        },
        {
          'service_typename': 'Weekend',
          'is_perpetual': false,
          'day_of_week': 'Sunday',
          'time_start': '10:00:00',
          'comment': 'Always livestreamed',
        },
      ]);
      expect(schedule.offersPerpetualAdoration, isFalse);
      expect(schedule.eucharisticAdoration, ParishSchedule.notListed);
      expect(schedule.massTimes, contains('Sunday 10:00 AM'));
    });

    test('reads 24-hour and Always wording on Adoration services', () {
      expect(
        ParishSchedule.fromWorshipTimes([
          {
            'service_typename': 'Adorations',
            'is_perpetual': false,
            'comment': '24-hour chapel',
            'time_start': '',
            'time_end': '',
          },
        ]).offersPerpetualAdoration,
        isTrue,
      );
      expect(
        ParishSchedule.fromWorshipTimes([
          {
            'service_typename': 'Adoration',
            'is_perpetual': false,
            'comment': 'Always',
            'time_start': '',
            'time_end': '',
          },
        ]).eucharisticAdoration,
        ParishSchedule.perpetualLabel,
      );
    });

    test('parses 24-hour MassTimes clocks instead of language-only lines', () {
      final schedule = ParishSchedule.fromWorshipTimes([
        {
          'day_of_week': 0,
          'time_start': '1/1/1900 8:00:00',
          'time_end': '',
          'language': 'English',
          'service_typename': 'Weekend',
          'is_perpetual': false,
        },
        {
          'day_of_week': 'Sunday',
          'time_start': '1900-01-01T10:30:00',
          'language': 'English',
          'service_typename': 'Mass',
          'is_perpetual': false,
        },
        {
          'day_of_week': '99',
          'time_start': '1/1/1900 12:00:00 AM',
          'language': 'English',
          'service_typename': 'Weekend',
          'is_perpetual': false,
          'comment': '',
        },
      ]);

      expect(schedule.massTimes, contains('Sunday 8:00 AM'));
      expect(schedule.massTimes, contains('Sunday 10:30 AM'));
      expect(
        schedule.massTimes.split('\n'),
        everyElement(isNot(equals('(English)'))),
      );
      expect(
        ParishSchedule.formatWorshipTimeLine({
          'language': 'English',
          'service_typename': 'Weekend',
          'day_of_week': '99',
          'time_start': '1/1/1900 12:00:00 AM',
        }),
        isNull,
      );
    });

    test('omits English tags and keeps other languages with the time', () {
      expect(
        ParishSchedule.formatWorshipTimeLine({
          'day_of_week': '0',
          'time_start': '1/1/1900 17:00:00',
          'language': 'English',
          'service_typename': 'Weekend',
        }),
        'Sunday 5:00 PM',
      );
      expect(
        ParishSchedule.formatWorshipTimeLine({
          'day_of_week': '0',
          'time_start': '1/1/1900 12:00:00',
          'language': 'Spanish',
          'service_typename': 'Weekend',
        }),
        'Sunday 12:00 PM (Spanish)',
      );
    });
  });

  group('ParishRanking', () {
    Parish parish(String name, double miles, {String? id}) {
      return Parish(id: id, name: name, address: '$name St', distanceMiles: miles);
    }

    test('lists My Parish first then the next three closest', () {
      final nearby = [
        parish('St. Mary', 0.4, id: '1'),
        parish('St. Joseph', 0.8, id: '2'),
        parish('Holy Cross', 1.1, id: '3'),
        parish('St. Anne', 2.0, id: '4'),
        parish('Sacred Heart', 3.5, id: '5'),
      ];
      final featured = ParishRanking.featuredParishes(
        nearby: nearby,
        myParish: parish('Holy Cross', 1.1, id: '3'),
      );

      expect(featured.first.name, 'Holy Cross');
      expect(featured.first.isMyParish, isTrue);
      expect(featured.skip(1).map((p) => p.name), [
        'St. Mary',
        'St. Joseph',
        'St. Anne',
      ]);
    });

    test('picks the closest perpetual adoration chapel even if farther', () {
      final nearby = [
        Parish(
          name: 'St. Mary',
          address: '1 Main',
          distanceMiles: 0.5,
          schedule: const ParishSchedule(),
        ),
        Parish(
          name: 'Adoration Chapel',
          address: '9 Oak',
          distanceMiles: 12.4,
          schedule: const ParishSchedule(perpetualAdoration: 'Always open'),
        ),
      ];
      final chapel = ParishRanking.closestPerpetualAdoration(nearby);
      expect(chapel?.name, 'Adoration Chapel');
      expect(chapel?.isPerpetualAdorationChapel, isTrue);
    });

    test('picks perpetual adoration from the Adoration row MassTimes listing', () {
      final nearby = [
        Parish(
          name: 'St. Mary',
          address: '1 Main',
          distanceMiles: 0.4,
          schedule: const ParishSchedule(
            eucharisticAdoration: 'Thursday 6:30 PM–8:00 PM',
          ),
        ),
        Parish(
          name: 'St. Ambrose',
          address: '2 Elm',
          distanceMiles: 8.2,
          schedule: const ParishSchedule(
            eucharisticAdoration: 'Perpetual',
            perpetualAdoration: 'Perpetual',
          ),
        ),
      ];
      final chapel = ParishRanking.closestPerpetualAdoration(nearby);
      expect(chapel?.name, 'St. Ambrose');
    });
  });

  group('MassTimesLinks', () {
    test('builds a location deep link without scraping', () {
      final uri = MassTimesLinks.nearbyMap(
        latitude: 40.7589,
        longitude: -73.9851,
        searchQuery: '350 Fifth Avenue, New York, NY',
      );
      expect(uri.host, 'masstimes.org');
      expect(uri.path, '/map');
      expect(uri.queryParameters['lat'], '40.75890');
      expect(uri.queryParameters['lng'], '-73.98510');
      expect(uri.queryParameters['SearchQueryTerm'], contains('Fifth Avenue'));
    });
  });

  group('WorshipPreferences', () {
    test('stores neighborhood and school separately', () {
      const neighborhood = LocationProfileState(
        addressText: '10 Home St',
        latitude: 1,
        longitude: 2,
      );
      const school = LocationProfileState(addressText: '20 Campus Rd');
      final prefs = const WorshipPreferences()
          .withProfile(LocationProfileKind.neighborhood, neighborhood)
          .withProfile(LocationProfileKind.school, school);

      expect(prefs.forKind(LocationProfileKind.neighborhood).addressText, '10 Home St');
      expect(prefs.forKind(LocationProfileKind.school).addressText, '20 Campus Rd');
    });

    test('merge keeps account values and fills guest gaps', () {
      final account = WorshipPreferences(profiles: {
        'neighborhood': const LocationProfileState(addressText: 'Account Home'),
      });
      final guest = WorshipPreferences(profiles: {
        'neighborhood': const LocationProfileState(addressText: 'Guest Home'),
        'school': const LocationProfileState(addressText: 'Guest School'),
      });
      final merged = WorshipPreferences.mergePreferringExisting(account, guest);
      expect(merged.forKind(LocationProfileKind.neighborhood).addressText, 'Account Home');
      expect(merged.forKind(LocationProfileKind.school).addressText, 'Guest School');
    });

    test('persists user-edited parish schedules', () {
      const parish = Parish(id: '9', name: 'St. Mary', address: '1 Main');
      final edited = parish.copyWith(
        schedule: const ParishSchedule(
          massTimes: 'Sunday 9:00 AM\nSunday 11:00 AM',
          confession: 'Saturday 3:30 PM',
        ),
      );
      final prefs = const WorshipPreferences()
          .withProfile(
            LocationProfileKind.neighborhood,
            const LocationProfileState().withScheduleOverride(
              parish,
              edited.schedule,
            ),
          );
      final roundTrip = WorshipPreferences.fromMap(prefs.toMap());
      expect(
        roundTrip
            .forKind(LocationProfileKind.neighborhood)
            .displayParish(parish)
            .schedule
            .massTimes,
        'Sunday 9:00 AM\nSunday 11:00 AM',
      );
    });
  });
}
