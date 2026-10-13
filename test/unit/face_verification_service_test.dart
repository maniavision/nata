import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/services/face_verification_service.dart';

void main() {
  group('FaceMatchResult.fromJson', () {
    test('a match', () {
      final r = FaceMatchResult.fromJson({
        'verdict': 'match',
        'similarity': 97.31,
        'attemptsLeft': 2,
      });
      expect(r.verdict, FaceMatchVerdict.match);
      expect(r.similarity, 97.31);
      expect(r.attemptsLeft, 2);
    });

    test('every verdict the edge function sends', () {
      expect(FaceMatchVerdict.fromJson('no_match'), FaceMatchVerdict.noMatch);
      expect(FaceMatchVerdict.fromJson('no_face'), FaceMatchVerdict.noFace);
      expect(
        FaceMatchVerdict.fromJson('manual_review'),
        FaceMatchVerdict.manualReview,
      );
    });

    test('anything unexpected falls back to manual review', () {
      expect(FaceMatchVerdict.fromJson(null), FaceMatchVerdict.manualReview);
      expect(FaceMatchVerdict.fromJson('???'), FaceMatchVerdict.manualReview);
    });

    test('missing fields', () {
      final r = FaceMatchResult.fromJson({'verdict': 'no_face'});
      expect(r.similarity, isNull);
      expect(r.attemptsLeft, 0);
    });
  });
}
