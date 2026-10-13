import Flutter
import UIKit
import CoreML
import CoreVideo
import Vision

/// Identity checks with Apple's Vision framework. Channel "nata/id_text":
/// - "recognizeText" { path } -> String: the text on the image
/// - "detectFace" { path } -> Bool: whether the image shows a human face
/// - "toJpeg" { path, maxSide } -> bytes: the image upright, scaled down to
///   at most maxSide px, as JPEG (for the face match: HEIC/PNG/huge photos)
/// - "analyzeFrame" { bytes, width, height, bytesPerRow } -> { faces, yaw,
///   eyeOpen }: one BGRA camera frame, for the liveness check. yaw is in
///   degrees; eyeOpen is 0 (closed) to 1 (open), from the eye landmarks.
enum IdTextRecognizer {
  /// The orientation camera frames were last found upright in. The camera
  /// plugin rotates frames to the device orientation, so .up should do, but
  /// the others are tried once if no face is found.
  private static var frameOrientation: CGImagePropertyOrientation = .up

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "nata/id_text", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      let reply: (Any) -> Void = { value in DispatchQueue.main.async { result(value) } }
      switch call.method {
      case "recognizeText", "detectFace", "toJpeg":
        guard let path = args["path"] as? String,
              let image = UIImage(contentsOfFile: path),
              let cgImage = image.cgImage else {
          result(FlutterError(code: "bad_image", message: "Could not open image", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          switch call.method {
          case "recognizeText":
            reply(recognizeText(cgImage, CGImagePropertyOrientation(image.imageOrientation)))
          case "detectFace":
            reply(detectFace(cgImage, CGImagePropertyOrientation(image.imageOrientation)))
          default:
            let maxSide = CGFloat(args["maxSide"] as? Int ?? 1600)
            reply(jpeg(image, maxSide: maxSide) ?? FlutterError(
              code: "bad_image", message: "Could not encode JPEG", details: nil))
          }
        }
      case "analyzeFrame":
        guard let data = args["bytes"] as? FlutterStandardTypedData,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int,
              let bytesPerRow = args["bytesPerRow"] as? Int,
              let buffer = pixelBuffer(data.data, width, height, bytesPerRow) else {
          result(FlutterError(code: "bad_frame", message: "Unsupported camera frame", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async { reply(analyze(buffer)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func recognizeText(_ image: CGImage, _ orientation: CGImagePropertyOrientation) -> Any {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // Names are not dictionary words; don't let autocorrect "fix" them.
    request.usesLanguageCorrection = false
    prepare(request)
    do {
      try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
      return (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
    } catch {
      return visionError(error)
    }
  }

  private static func detectFace(_ image: CGImage, _ orientation: CGImagePropertyOrientation) -> Any {
    let request = VNDetectFaceRectanglesRequest()
    prepare(request)
    do {
      try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
      return !(request.results ?? []).isEmpty
    } catch {
      return visionError(error)
    }
  }

  private static func jpeg(_ image: UIImage, maxSide: CGFloat) -> FlutterStandardTypedData? {
    let longSide = max(image.size.width, image.size.height)
    let scale = min(1, maxSide / longSide)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    // Drawing applies the EXIF orientation, so the JPEG comes out upright.
    let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    return resized.jpegData(compressionQuality: 0.85).map(FlutterStandardTypedData.init(bytes:))
  }

  private static func analyze(_ buffer: CVPixelBuffer) -> Any {
    var orientations: [CGImagePropertyOrientation] = [frameOrientation]
    orientations += [.up, .leftMirrored, .right, .rightMirrored].filter { $0 != frameOrientation }
    for orientation in orientations {
      let faces = VNDetectFaceRectanglesRequest()
      if #available(iOS 15.0, *) { faces.revision = VNDetectFaceRectanglesRequestRevision3 }
      let landmarks = VNDetectFaceLandmarksRequest()
      prepare(faces)
      prepare(landmarks)
      do {
        try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation)
          .perform([faces, landmarks])
      } catch {
        return visionError(error)
      }
      let found = faces.results ?? []
      if found.isEmpty { continue }
      frameOrientation = orientation
      // The largest face is the user's.
      let face = found.max { $0.boundingBox.width < $1.boundingBox.width }!
      let yaw = face.yaw.map { $0.doubleValue * 180 / .pi }
      let marked = (landmarks.results ?? []).max { $0.boundingBox.width < $1.boundingBox.width }
      return [
        "faces": found.count,
        "yaw": yaw as Any,
        "eyeOpen": marked.flatMap(eyeOpenness) as Any,
      ]
    }
    return ["faces": 0]
  }

  /// 0 (closed) to 1 (open) from the eye landmarks' height/width ratio,
  /// averaged over both eyes: about 0.3 open, under 0.15 closed.
  private static func eyeOpenness(_ face: VNFaceObservation) -> Double? {
    guard let left = face.landmarks?.leftEye, let right = face.landmarks?.rightEye else {
      return nil
    }
    func ratio(_ eye: VNFaceLandmarkRegion2D) -> Double? {
      let points = eye.normalizedPoints
      guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
            let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(),
            maxX > minX else { return nil }
      return Double((maxY - minY) / (maxX - minX))
    }
    guard let l = ratio(left), let r = ratio(right) else { return nil }
    let open = 0.28, closed = 0.12
    return min(1, max(0, ((l + r) / 2 - closed) / (open - closed)))
  }

  /// A BGRA pixel buffer holding a copy of one camera frame.
  private static func pixelBuffer(_ data: Data, _ width: Int, _ height: Int, _ bytesPerRow: Int) -> CVPixelBuffer? {
    guard data.count >= bytesPerRow * height else { return nil }
    var buffer: CVPixelBuffer?
    guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                              nil, &buffer) == kCVReturnSuccess, let buffer else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
    let destRow = CVPixelBufferGetBytesPerRow(buffer)
    data.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
      for y in 0..<height {
        memcpy(base + y * destRow, src.baseAddress! + y * bytesPerRow, min(destRow, bytesPerRow))
      }
    }
    return buffer
  }

  private static func visionError(_ error: Error) -> FlutterError {
    FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil)
  }

  /// The simulator has no GPU/Neural Engine for Vision's models ("Could not
  /// create inference context"): run them on the CPU there.
  private static func prepare(_ request: VNRequest) {
    #if targetEnvironment(simulator)
    if #available(iOS 17.0, *) {
      guard let cpu = MLComputeDevice.allComputeDevices.first(where: {
        if case .cpu = $0 { return true } else { return false }
      }) else { return }
      if let stages = try? request.supportedComputeStageDevices {
        for stage in stages.keys { request.setComputeDevice(cpu, for: stage) }
      }
    } else {
      request.usesCPUOnly = true
    }
    #endif
  }
}

private extension CGImagePropertyOrientation {
  init(_ o: UIImage.Orientation) {
    switch o {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
