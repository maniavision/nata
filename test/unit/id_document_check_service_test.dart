import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/services/id_document_check_service.dart';
import 'package:carrywise_app/services/verification_service.dart';

void main() {
  group('IdDocumentCheckService.nameAppearsIn', () {
    const idText = '''
REPUBLIQUE DU CAMEROUN
CARTE NATIONALE D'IDENTITE
NOM / SURNAME
MBALLA
PRENOMS / GIVEN NAMES
JEAN ERIC
''';

    test('finds names regardless of case', () {
      expect(IdDocumentCheckService.nameAppearsIn(idText, 'Mballa'), isTrue);
      expect(IdDocumentCheckService.nameAppearsIn(idText, 'jean'), isTrue);
    });

    test('ignores accents and hyphens', () {
      expect(IdDocumentCheckService.nameAppearsIn(idText, 'Jean-Éric'), isTrue);
      expect(
        IdDocumentCheckService.nameAppearsIn('NOM: NDJOCKÉ', 'Ndjocke'),
        isTrue,
      );
    });

    test('requires whole words, not substrings', () {
      expect(IdDocumentCheckService.nameAppearsIn(idText, 'Ball'), isFalse);
      expect(IdDocumentCheckService.nameAppearsIn('FREDERIC', 'Eric'), isFalse);
    });

    test('every word of a compound name must be present', () {
      expect(
        IdDocumentCheckService.nameAppearsIn(idText, 'Jean Paul'),
        isFalse,
      );
    });

    test('reads names from a passport MRZ line', () {
      const mrz = 'P<CMRDUPONT<<MARIE<CLAIRE<<<<<<<<<<<<<<<<<<<';
      expect(IdDocumentCheckService.nameAppearsIn(mrz, 'Dupont'), isTrue);
      expect(IdDocumentCheckService.nameAppearsIn(mrz, 'Marie-Claire'), isTrue);
      expect(IdDocumentCheckService.nameAppearsIn(mrz, 'Pont'), isFalse);
    });

    test('empty name never matches', () {
      expect(IdDocumentCheckService.nameAppearsIn(idText, '  '), isFalse);
    });
  });

  group('IdDocumentCheckService.keywordGroupsIn', () {
    test('counts labels in English, French and Spanish', () {
      expect(
        IdDocumentCheckService.keywordGroupsIn(
          'Passport / Passeport / Pasaporte\n'
          'Surname / Nom / Apellidos\n'
          'Date of birth / Date de naissance / Fecha de nacimiento',
        ),
        3, // document, surname, date of birth: each group counts once
      );
    });

    test('ignores accents and apostrophes in labels', () {
      expect(
        IdDocumentCheckService.keywordGroupsIn(
          "CARTE D'IDENTITÉ  Nationalité: CAMEROUNAISE",
        ),
        2,
      );
    });

    test('matches whole words only', () {
      // "NOMBRE" inside "RENOMBRE" or "SEX" inside "SEXTANT" must not count.
      expect(IdDocumentCheckService.keywordGroupsIn('RENOMBRE SEXTANT'), 0);
    });

    test('recognizes residence cards', () {
      // Text read from a scanned UK residence card (both sides).
      expect(
        IdDocumentCheckService.keywordGroupsIn(
          'RESIDENCE CARD\nNIAMA MISSOUELE\nPLACE AND DATE OF ISSUE\n'
          'DATE AND PLACE OF BIRTH\nSEX\nNATIONALITY',
        ),
        greaterThanOrEqualTo(IdDocumentCheckService.minKeywords),
      );
    });

    test('a receipt has no ID labels', () {
      expect(
        IdDocumentCheckService.keywordGroupsIn('TOTAL 12.50 THANK YOU VISA'),
        0,
      );
    });
  });

  group('IdDocumentCheckService.mentionsType', () {
    bool mentions(String text, IdDocumentType type) =>
        IdDocumentCheckService.mentionsType(text, type);

    // Text as read from real IDs (see the uploads tested on the simulator).
    const usPassport =
        'Passport No./ No du Passeport / No. de Pasaporte\n'
        'Surname / Nom / Apellidos';
    const marylandLicense = "MARYLAND\nDriver's License\nDL\nGiven names";
    const ukResidenceCard =
        'DATE AND PLACE OF BIRTH\nSEX\nNATIONALITY\n'
        'CRGBRRE08162365<<<<..\nNIAMA<MISSOUELE<<THIERRY<ARMEL';

    test('a passport names itself, in any language', () {
      expect(mentions(usPassport, IdDocumentType.passport), isTrue);
      expect(mentions('PASSEPORT', IdDocumentType.passport), isTrue);
      expect(mentions('Pasaporte', IdDocumentType.passport), isTrue);
    });

    test("a driver's license names itself, in any language", () {
      expect(mentions(marylandLicense, IdDocumentType.driversLicense), isTrue);
      expect(
        mentions('PERMIS DE CONDUIRE', IdDocumentType.driversLicense),
        isTrue,
      );
      expect(
        mentions('Licencia de Conducir', IdDocumentType.driversLicense),
        isTrue,
      );
      expect(
        mentions('UK DRIVING LICENCE', IdDocumentType.driversLicense),
        isTrue,
      );
    });

    test('a national ID names itself, in any language', () {
      expect(
        mentions("CARTE NATIONALE D'IDENTITÉ", IdDocumentType.nationalId),
        isTrue,
      );
      expect(
        mentions('Documento Nacional de Identidad', IdDocumentType.nationalId),
        isTrue,
      );
      expect(
        mentions('CÉDULA DE CIUDADANÍA', IdDocumentType.nationalId),
        isTrue,
      );
    });

    test('passport MRZ counts even if the word was misread', () {
      const mrz = 'P<USANIAMA<MISSOUELE<<FORTUNE<CHRISTIAN<<<<<';
      expect(mentions(mrz, IdDocumentType.passport), isTrue);
      expect(mentions(mrz, IdDocumentType.nationalId), isFalse);
    });

    test('ID-card MRZ counts for a national ID (residence card)', () {
      expect(mentions(ukResidenceCard, IdDocumentType.nationalId), isTrue);
      expect(mentions(ukResidenceCard, IdDocumentType.passport), isFalse);
    });

    test("one ID type's words don't pass for another", () {
      expect(mentions(usPassport, IdDocumentType.driversLicense), isFalse);
      expect(mentions(usPassport, IdDocumentType.nationalId), isFalse);
      expect(mentions(marylandLicense, IdDocumentType.passport), isFalse);
      expect(mentions(marylandLicense, IdDocumentType.nationalId), isFalse);
    });

    test('ordinary lines are not mistaken for an MRZ', () {
      expect(mentions('PLACE OF BIRTH', IdDocumentType.passport), isFalse);
      expect(mentions('ISSUE DATE', IdDocumentType.nationalId), isFalse);
    });
  });

  group('IdDocumentCheckService.check', () {
    final bytes = Uint8List(0);
    const passportText =
        'PASSPORT SURNAME MBALLA GIVEN NAMES JEAN DATE OF BIRTH 01 JAN 1990';

    IdDocumentCheckService build({
      String? text = passportText,
      bool? face = true,
      Map<String, dynamic>? profile = const {
        'first_name': 'Jean',
        'last_name': 'Mballa',
      },
    }) => IdDocumentCheckService(
      readText: (_, _) async => text,
      detectFace: (_, _) async => face,
      loadProfile: () async => profile,
    );

    Future<IdCheckResult> run(
      IdDocumentCheckService s, {
      IdDocumentType type = IdDocumentType.passport,
    }) => s.check(bytes: bytes, fileName: 'id.jpg', idType: type);

    test('passed when labels, name and face are all present', () async {
      expect(await run(build()), IdCheckResult.passed);
    });

    test('notAnId when fewer than 2 ID labels are found', () async {
      expect(
        await run(build(text: 'PASSPORT MBALLA JEAN')),
        IdCheckResult.notAnId,
      );
    });

    test('wrongType when the ID is not the selected type', () async {
      expect(
        await run(build(), type: IdDocumentType.driversLicense),
        IdCheckResult.wrongType,
      );
      expect(
        await run(build(), type: IdDocumentType.nationalId),
        IdCheckResult.wrongType,
      );
    });

    test('the type is checked before the name', () async {
      expect(
        await run(
          build(text: passportText.replaceAll('MBALLA', 'NGONO')),
          type: IdDocumentType.driversLicense,
        ),
        IdCheckResult.wrongType,
      );
    });

    test('nameMismatch when only one name is on the ID', () async {
      expect(
        await run(build(text: passportText.replaceAll('MBALLA', 'NGONO'))),
        IdCheckResult.nameMismatch,
      );
    });

    test('noFace when no face is detected', () async {
      expect(await run(build(face: false)), IdCheckResult.noFace);
    });

    test('unreadable when no text could be read', () async {
      expect(await run(build(text: null)), IdCheckResult.unreadable);
      expect(await run(build(text: '  ')), IdCheckResult.unreadable);
    });

    test('unverifiable when face detection could not run', () async {
      expect(await run(build(face: null)), IdCheckResult.unverifiable);
    });

    test('unverifiable when the profile has no name', () async {
      expect(
        await run(build(profile: {'first_name': 'Jean', 'last_name': null})),
        IdCheckResult.unverifiable,
      );
    });
  });
}
