import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/services/liveness.dart';

void main() {
  FaceFrame face({double yaw = 0, double? eyes = 0.9, int faces = 1}) =>
      FaceFrame(faces: faces, yaw: yaw, eyeOpen: eyes);

  LivenessSession session(List<LivenessChallenge> challenges) =>
      LivenessSession(challenges: challenges);

  void blink(LivenessSession s) {
    s.add(face(eyes: 0.9));
    s.add(face(eyes: 0.05));
    s.add(face(eyes: 0.9));
  }

  void turn(LivenessSession s) {
    s.add(face(yaw: 25));
    s.add(face(yaw: -25));
  }

  void holdStill(LivenessSession s) {
    for (var i = 0; i < LivenessSession.steadyFrames; i++) {
      s.add(face());
    }
  }

  group('LivenessSession', () {
    test('asks for a face until there is exactly one', () {
      final s = session([LivenessChallenge.blink]);
      expect(s.add(face(faces: 0)), LivenessPrompt.noFace);
      expect(s.add(face(faces: 2)), LivenessPrompt.multipleFaces);
      expect(s.add(face()), LivenessPrompt.blink);
    });

    test('a blink is open, closed, open again', () {
      final s = session([LivenessChallenge.blink]);
      s.add(face(eyes: 0.9));
      expect(s.add(face(eyes: 0.05)), LivenessPrompt.blink);
      expect(s.add(face(eyes: 0.9)), LivenessPrompt.lookStraight);
    });

    test('eyes closed from the start are not a blink', () {
      final s = session([LivenessChallenge.blink]);
      s.add(face(eyes: 0.05));
      s.add(face(eyes: 0.05));
      expect(s.add(face(eyes: 0.9)), LivenessPrompt.blink);
    });

    test('half-closed eyes do not count', () {
      final s = session([LivenessChallenge.blink]);
      s.add(face(eyes: 0.9));
      s.add(face(eyes: 0.45));
      expect(s.add(face(eyes: 0.9)), LivenessPrompt.blink);
    });

    test('a head turn needs both directions, in any order', () {
      final s = session([LivenessChallenge.turnHead]);
      expect(s.add(face(yaw: -30)), LivenessPrompt.turnHead);
      expect(s.add(face(yaw: 5)), LivenessPrompt.turnHead);
      expect(s.add(face(yaw: 30)), LivenessPrompt.lookStraight);
    });

    test('a small turn does not count', () {
      final s = session([LivenessChallenge.turnHead]);
      s.add(face(yaw: 12));
      expect(s.add(face(yaw: -12)), LivenessPrompt.turnHead);
    });

    test('finishes after the challenges and holding still', () {
      final s = session([LivenessChallenge.blink, LivenessChallenge.turnHead]);
      blink(s);
      expect(s.prompt, LivenessPrompt.turnHead);
      expect(s.completed, 1);
      turn(s);
      expect(s.prompt, LivenessPrompt.lookStraight);
      expect(s.isDone, isFalse);
      holdStill(s);
      expect(s.isDone, isTrue);
    });

    test('looking away restarts the hold-still count', () {
      final s = session([LivenessChallenge.turnHead]);
      turn(s);
      s.add(face());
      s.add(face());
      s.add(face(yaw: 25));
      expect(s.prompt, LivenessPrompt.lookStraight);
      holdStill(s);
      expect(s.isDone, isTrue);
    });

    test('the selfie waits for open eyes', () {
      final s = session([LivenessChallenge.turnHead]);
      turn(s);
      for (var i = 0; i < 5; i++) {
        s.add(face(eyes: 0.1));
      }
      expect(s.isDone, isFalse);
    });

    test('losing the face keeps the progress made', () {
      final s = session([LivenessChallenge.blink, LivenessChallenge.turnHead]);
      blink(s);
      expect(s.add(face(faces: 0)), LivenessPrompt.noFace);
      expect(s.add(face()), LivenessPrompt.turnHead);
      expect(s.completed, 1);
    });

    test('works when eye openness is unavailable (head turn only)', () {
      final s = session([LivenessChallenge.turnHead]);
      s.add(const FaceFrame(faces: 1, yaw: 25));
      s.add(const FaceFrame(faces: 1, yaw: -25));
      for (var i = 0; i < LivenessSession.steadyFrames; i++) {
        s.add(const FaceFrame(faces: 1, yaw: 0));
      }
      expect(s.isDone, isTrue);
    });

    test('runs every challenge once, in a random order', () {
      final orders = {
        for (var seed = 0; seed < 20; seed++)
          LivenessSession(random: Random(seed)).challenges.join(),
      };
      expect(orders.length, 2);
      expect(
        LivenessSession().challenges.toSet(),
        LivenessChallenge.values.toSet(),
      );
    });
  });

  group('FaceFrame.fromMap', () {
    test('reads what the native side returns', () {
      final f = FaceFrame.fromMap({'faces': 1, 'yaw': -12.5, 'eyeOpen': 0.8});
      expect(f.faces, 1);
      expect(f.yaw, -12.5);
      expect(f.eyeOpen, 0.8);
    });

    test('no face: only a count', () {
      final f = FaceFrame.fromMap({'faces': 0});
      expect(f.faces, 0);
      expect(f.yaw, isNull);
      expect(f.eyeOpen, isNull);
    });
  });
}
