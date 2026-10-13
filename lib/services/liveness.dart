import 'dart:math';

/// What the face detector saw in one camera frame.
class FaceFrame {
  /// How many faces are in the frame.
  final int faces;

  /// Head turn in degrees (0 = facing the camera). The sign depends on the
  /// platform and the camera's mirroring, so the liveness check never relies
  /// on it: it asks the user to turn both ways.
  final double? yaw;

  /// 0 (eyes closed) to 1 (eyes open); null if it couldn't be measured.
  final double? eyeOpen;

  const FaceFrame({required this.faces, this.yaw, this.eyeOpen});

  factory FaceFrame.fromMap(Map<Object?, Object?> map) => FaceFrame(
    faces: (map['faces'] as num?)?.toInt() ?? 0,
    yaw: (map['yaw'] as num?)?.toDouble(),
    eyeOpen: (map['eyeOpen'] as num?)?.toDouble(),
  );
}

/// The actions that prove a live person is in front of the camera (a printed
/// photo or a still on a screen can't blink or turn its head).
enum LivenessChallenge { blink, turnHead }

/// What the user should be told to do next.
enum LivenessPrompt {
  /// No face in the frame: "Position your face in the oval".
  noFace,

  /// More than one face: "Only you should be in the frame".
  multipleFaces,

  /// "Blink slowly".
  blink,

  /// "Turn your head to the left, then to the right".
  turnHead,

  /// Challenges done: "Look straight at the camera" for the selfie.
  lookStraight,

  /// Ready: take the selfie now.
  done,
}

/// Runs the liveness challenges over a stream of [FaceFrame]s. The order of
/// the challenges is random, so a recorded video of an earlier run won't
/// follow the prompts.
class LivenessSession {
  LivenessSession({List<LivenessChallenge>? challenges, Random? random})
    : challenges =
          challenges ??
          (List.of(LivenessChallenge.values)..shuffle(random ?? Random()));

  final List<LivenessChallenge> challenges;

  /// Eyes count as closed under this and open above [eyesOpen]; the gap
  /// avoids flickering between the two.
  static const eyesClosed = 0.3;
  static const eyesOpen = 0.6;

  /// A turn counts past this many degrees each way.
  static const turnDegrees = 20.0;

  /// Facing the camera means within this many degrees.
  static const straightDegrees = 10.0;

  /// Frames in a row the user must hold still, facing the camera, before the
  /// selfie is taken.
  static const steadyFrames = 3;

  int _index = 0;
  bool _sawEyesOpen = false;
  bool _sawEyesClosed = false;
  bool _turnedOneWay = false;
  bool _turnedOtherWay = false;
  int _steady = 0;
  LivenessPrompt _prompt = LivenessPrompt.noFace;

  LivenessPrompt get prompt => _prompt;

  /// The challenge in progress, or null once all are done.
  LivenessChallenge? get current =>
      _index < challenges.length ? challenges[_index] : null;

  /// How many challenges are done (for a progress indicator).
  int get completed => _index;

  bool get isDone => _prompt == LivenessPrompt.done;

  /// Feeds one frame; returns the prompt to show.
  LivenessPrompt add(FaceFrame frame) {
    if (isDone) return _prompt;
    if (frame.faces == 0) return _prompt = LivenessPrompt.noFace;
    if (frame.faces > 1) {
      _steady = 0;
      return _prompt = LivenessPrompt.multipleFaces;
    }

    switch (current) {
      case LivenessChallenge.blink:
        final eye = frame.eyeOpen;
        if (eye != null) {
          if (eye > eyesOpen) {
            if (_sawEyesClosed) return _next();
            _sawEyesOpen = true;
          } else if (eye < eyesClosed && _sawEyesOpen) {
            _sawEyesClosed = true;
          }
        }
        return _prompt = LivenessPrompt.blink;
      case LivenessChallenge.turnHead:
        final yaw = frame.yaw;
        if (yaw != null) {
          if (yaw > turnDegrees) _turnedOneWay = true;
          if (yaw < -turnDegrees) _turnedOtherWay = true;
          if (_turnedOneWay && _turnedOtherWay) return _next();
        }
        return _prompt = LivenessPrompt.turnHead;
      case null:
        final facing = (frame.yaw ?? 0).abs() < straightDegrees;
        final eyesOk = frame.eyeOpen == null || frame.eyeOpen! > eyesOpen;
        _steady = facing && eyesOk ? _steady + 1 : 0;
        return _prompt = _steady >= steadyFrames
            ? LivenessPrompt.done
            : LivenessPrompt.lookStraight;
    }
  }

  LivenessPrompt _next() {
    _index++;
    return _prompt = switch (current) {
      LivenessChallenge.blink => LivenessPrompt.blink,
      LivenessChallenge.turnHead => LivenessPrompt.turnHead,
      null => LivenessPrompt.lookStraight,
    };
  }
}
