import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'liveness.dart';
import 'verification_service.dart';

/// The outcome of comparing the selfie with the ID photo
/// (`verify-identity` edge function, AWS Rekognition CompareFaces).
enum FaceMatchVerdict {
  /// Same person: the user is now verified.
  match,

  /// Different person, or too unsure; the user can try again.
  noMatch,

  /// No face found in the selfie or on the ID image.
  noFace,

  /// Out of attempts: the verification stays pending for a person to review.
  manualReview;

  static FaceMatchVerdict fromJson(String? value) => switch (value) {
    'match' => match,
    'no_match' => noMatch,
    'no_face' => noFace,
    _ => manualReview,
  };
}

class FaceMatchResult {
  final FaceMatchVerdict verdict;

  /// Rekognition's similarity, 0 to 100 (null when no faces were compared).
  final double? similarity;

  /// Face matches the user may still try.
  final int attemptsLeft;

  const FaceMatchResult({
    required this.verdict,
    this.similarity,
    this.attemptsLeft = 0,
  });

  factory FaceMatchResult.fromJson(Map<String, dynamic> json) =>
      FaceMatchResult(
        verdict: FaceMatchVerdict.fromJson(json['verdict'] as String?),
        similarity: (json['similarity'] as num?)?.toDouble(),
        attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 0,
      );
}

/// The selfie side of identity verification: analyses camera frames for the
/// liveness check, uploads the selfie and asks the server to match it with
/// the ID photo.
///
/// Both images go to the private `identity-documents` bucket under the
/// user's folder, at the fixed names the edge function reads.
class FaceVerificationService {
  /// The ID page showing the user's face, as JPEG (see
  /// IdDocumentCheckService.faceImage).
  static const idFaceFile = 'id_face.jpg';
  static const selfieFile = 'selfie.jpg';

  static const _channel = MethodChannel('nata/id_text');

  Future<void> uploadIdFace(Uint8List jpeg) =>
      VerificationService().uploadDocument(
        bytes: jpeg,
        fileName: idFaceFile,
        mimeType: 'image/jpeg',
      );

  Future<void> uploadSelfie(Uint8List jpeg) =>
      VerificationService().uploadDocument(
        bytes: jpeg,
        fileName: selfieFile,
        mimeType: 'image/jpeg',
      );

  /// Runs the face match on the server; it also marks the user verified on a
  /// match and counts the attempts.
  Future<FaceMatchResult> verify() async {
    final response = await Supabase.instance.client.functions.invoke(
      'verify-identity',
    );
    return FaceMatchResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// What the face detector sees in one camera frame: BGRA on iOS, NV21 on
  /// Android. Null if it couldn't be analysed.
  Future<FaceFrame?> analyzeFrame(
    CameraImage image,
    int sensorOrientation,
  ) async {
    try {
      final plane = image.planes.first;
      final map = await _channel
          .invokeMethod<Map<Object?, Object?>>('analyzeFrame', {
            'bytes': plane.bytes,
            'width': image.width,
            'height': image.height,
            'bytesPerRow': plane.bytesPerRow,
            'rotation': sensorOrientation,
          });
      return map == null ? null : FaceFrame.fromMap(map);
    } catch (e) {
      debugPrint('[FaceVerificationService] analyzeFrame error: $e');
      return null;
    }
  }

  /// The selfie at [path] upright and at most 1280 px, as JPEG.
  Future<Uint8List?> selfieJpeg(String path) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('toJpeg', {
        'path': path,
        'maxSide': 1280,
      });
    } catch (e) {
      debugPrint('[FaceVerificationService] toJpeg error: $e');
      return null;
    }
  }
}
