import 'dart:typed_data';

import 'package:carrywise_app/services/ticket_check_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The flight ticket check on Add Trip: the traveler's name and the trip's
/// dates must be on the uploaded ticket.
void main() {
  final departure = DateTime(2030, 6, 22);

  group('dates in the usual ticket formats', () {
    for (final text in [
      'BOARDING PASS LOS LHR BA075 22JUN 14A', // boarding pass, no year
      'Flight date: 22 JUN 2030',
      'DATE 22JUN30',
      'Departure: June 22, 2030',
      'Depart Jun 22 2030 14:30',
      'Date de départ : 22 juin 2030',
      'Salida: 22 de junio de 2030',
      'Abflug 22. Juni 2030',
      '2030-06-22T14:30',
      '22/06/2030',
      '22.06.2030',
      '06/22/2030',
      '22/06/30',
    ]) {
      test(text, () {
        expect(TicketCheckService.dateOnTicket(text, departure), isTrue);
      });
    }
  });

  group('a different date does not match', () {
    for (final text in [
      'BOARDING PASS 23JUN',
      'DATE 22JUN25', // same day, another year
      'Flight date: 22 JUL 2030',
      'Departure: June 22, 2029',
      '2030-06-23',
      '21/06/2030',
      'Seat 14A Gate 22 Boarding 06:30', // numbers that are not a date
      'No date at all',
    ]) {
      test(text, () {
        expect(TicketCheckService.dateOnTicket(text, departure), isFalse);
      });
    }
  });

  group('names', () {
    test('surname/first name, with or without a title', () {
      for (final text in [
        'KALU/AMARA MS',
        'KALU/AMARAMS',
        'Passenger: Amara Kalu',
        'NAME OF PASSENGER KALU AMARA MRS',
      ]) {
        expect(
          TicketCheckService.nameOnTicket(text, 'Amara'),
          isTrue,
          reason: text,
        );
        expect(
          TicketCheckService.nameOnTicket(text, 'Kalu'),
          isTrue,
          reason: text,
        );
      }
    });

    test('accents and case are ignored', () {
      expect(
        TicketCheckService.nameOnTicket(
          'PASSENGER DUPONT/JEAN ERIC MR',
          'Jean-Éric',
        ),
        isTrue,
      );
    });

    test('another person does not match', () {
      expect(TicketCheckService.nameOnTicket('KOLA/AMARA MS', 'Kalu'), isFalse);
      // A name only as part of a longer word does not count.
      expect(
        TicketCheckService.nameOnTicket('KALUMBA/JOHN MR', 'Kalu'),
        isFalse,
      );
    });
  });

  group('any of the names', () {
    test('one of several first or last names is enough', () {
      expect(
        TicketCheckService.anyNameOnTicket('KALU/AMARA MS', 'Amara Grace'),
        isTrue,
      );
      expect(
        TicketCheckService.anyNameOnTicket('KALU/GRACE MS', 'Amara Grace'),
        isTrue,
      );
      expect(
        TicketCheckService.anyNameOnTicket('OKONKWO/AMARA MS', 'Kalu-Okonkwo'),
        isTrue,
      );
    });

    test('none of them: no match', () {
      expect(
        TicketCheckService.anyNameOnTicket('KALU/JOY MS', 'Amara Grace'),
        isFalse,
      );
    });

    test('an initial alone does not count', () {
      expect(
        TicketCheckService.anyNameOnTicket('KALU/A MS', 'Amara A.'),
        isFalse,
      );
    });
  });

  group('check', () {
    Future<TicketCheckResult> check(
      String? text, {
      Map<String, dynamic>? profile = const {
        'first_name': 'Amara',
        'last_name': 'Kalu',
      },
      DateTime? arrival,
    }) =>
        TicketCheckService(
          readText: (_, _) async => text,
          loadProfile: () async => profile,
        ).check(
          bytes: Uint8List(1),
          fileName: 'ticket.jpg',
          departure: departure,
          arrival: arrival ?? departure,
        );

    test('name and date on the ticket: passed', () async {
      expect(
        await check('BOARDING PASS KALU/AMARAMS LOS LHR 22JUN BA075'),
        TicketCheckResult.passed,
      );
    });

    test('someone else\'s ticket: name mismatch', () async {
      expect(
        await check('BOARDING PASS OKAFOR/DANIEL MR 22JUN'),
        TicketCheckResult.nameMismatch,
      );
    });

    test('one first name and one last name of several: passed', () async {
      expect(
        await check(
          'BOARDING PASS OKONKWO/GRACE MS 22JUN',
          profile: const {
            'first_name': 'Amara Grace',
            'last_name': 'Kalu Okonkwo',
          },
        ),
        TicketCheckResult.passed,
      );
    });

    test('a first name but none of the last names: name mismatch', () async {
      expect(
        await check(
          'BOARDING PASS ADEYEMI/GRACE MS 22JUN',
          profile: const {
            'first_name': 'Amara Grace',
            'last_name': 'Kalu Okonkwo',
          },
        ),
        TicketCheckResult.nameMismatch,
      );
    });

    test('another day: date mismatch', () async {
      expect(
        await check('BOARDING PASS KALU/AMARA MS 25JUN'),
        TicketCheckResult.dateMismatch,
      );
    });

    test('nothing readable', () async {
      expect(await check(''), TicketCheckResult.unreadable);
      expect(await check(null), TicketCheckResult.unreadable);
    });

    test('no profile name yet: only the date is checked', () async {
      expect(
        await check('BOARDING PASS SOMEONE 22JUN', profile: const {}),
        TicketCheckResult.unverifiable,
      );
    });

    test('arrival the next day: fine on a boarding pass (one date)', () async {
      expect(
        await check(
          'KALU/AMARA MS 22JUN LOS LHR',
          arrival: DateTime(2030, 6, 23),
        ),
        TicketCheckResult.passed,
      );
    });

    test('an itinerary showing both dates must match both', () async {
      final arrival = DateTime(2030, 6, 23);
      expect(
        await check(
          'Amara Kalu  Depart 22 Jun 2030 LOS  Arrive 23 Jun 2030 LHR',
          arrival: arrival,
        ),
        TicketCheckResult.passed,
      );
      expect(
        await check(
          'Amara Kalu  Depart 22 Jun 2030 LOS  Arrive 24 Jun 2030 LHR',
          arrival: arrival,
        ),
        TicketCheckResult.dateMismatch,
      );
    });
  });
}
