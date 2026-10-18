package com.carrywise.carrywise_app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.Rect
import android.media.ExifInterface
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

// local_auth shows the Face / fingerprint prompt as a fragment, so the host
// activity must be a FlutterFragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    private val background = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /// Fast detector with eye-open probabilities, for live camera frames.
    private val liveDetector: FaceDetector by lazy {
        FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                .build()
        )
    }

    /// The rotation camera frames were last found upright at. Starts from the
    /// sensor orientation Flutter passes in; the others are tried once if no
    /// face is found.
    private var frameRotation: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Identity checks with ML Kit. Channel "nata/id_text":
        // - "recognizeText" { path } -> String: the text on the image
        // - "textBoxes" { path } -> { words: [{ text, line, x, y, w, h }],
        //   barcodes: [{ x, y, w, h }] }: each word read and each barcode
        //   found, in the upright image's pixels (to blur parts of a ticket)
        // - "detectFace" { path } -> Boolean: whether it shows a human face
        // - "toJpeg" { path, maxSide } -> bytes: the image upright, scaled down
        //   to at most maxSide px, as JPEG (for the face match)
        // - "analyzeFrame" { bytes, width, height, rotation } -> { faces, yaw,
        //   eyeOpen }: one NV21 camera frame, for the liveness check. yaw is
        //   in degrees; eyeOpen is ML Kit's eye-open probability (0 to 1).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nata/id_text")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "analyzeFrame" -> analyzeFrame(
                        call.argument<ByteArray>("bytes")!!,
                        call.argument<Int>("width")!!,
                        call.argument<Int>("height")!!,
                        call.argument<Int>("rotation") ?: 0,
                        result,
                    )
                    "toJpeg" -> {
                        val path = call.argument<String>("path")!!
                        val maxSide = call.argument<Int>("maxSide") ?: 1600
                        background.execute {
                            val jpeg = try {
                                toJpeg(path, maxSide)
                            } catch (e: Exception) {
                                null
                            }
                            main.post {
                                if (jpeg != null) result.success(jpeg)
                                else result.error("bad_image", "Could not encode JPEG", null)
                            }
                        }
                    }
                    "recognizeText", "detectFace", "textBoxes" -> {
                        val image = try {
                            InputImage.fromFilePath(
                                this,
                                Uri.fromFile(File(call.argument<String>("path")!!)),
                            )
                        } catch (e: Exception) {
                            result.error("bad_image", e.message, null)
                            return@setMethodCallHandler
                        }
                        if (call.method == "textBoxes") {
                            textBoxes(image, result)
                        } else if (call.method == "detectFace") {
                            val detector = FaceDetection.getClient()
                            detector.process(image)
                                .addOnSuccessListener { result.success(it.isNotEmpty()) }
                                .addOnFailureListener { result.error("face_failed", it.message, null) }
                                .addOnCompleteListener { detector.close() }
                        } else {
                            val recognizer =
                                TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                            recognizer.process(image)
                                .addOnSuccessListener { result.success(it.text) }
                                .addOnFailureListener { result.error("ocr_failed", it.message, null) }
                                .addOnCompleteListener { recognizer.close() }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun textBoxes(image: InputImage, result: MethodChannel.Result) {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { text ->
                val words = mutableListOf<Map<String, Any>>()
                var line = 0
                for (block in text.textBlocks) {
                    for (textLine in block.lines) {
                        for (element in textLine.elements) {
                            val rect = element.boundingBox ?: continue
                            words.add(box(rect) + mapOf("text" to element.text, "line" to line))
                        }
                        line++
                    }
                }
                val scanner = BarcodeScanning.getClient()
                scanner.process(image)
                    .addOnSuccessListener { codes ->
                        result.success(
                            mapOf(
                                "words" to words,
                                "barcodes" to codes.mapNotNull { it.boundingBox?.let(::box) },
                            )
                        )
                    }
                    // Without barcodes the words are still worth returning.
                    .addOnFailureListener {
                        result.success(mapOf("words" to words, "barcodes" to emptyList<Any>()))
                    }
                    .addOnCompleteListener { scanner.close() }
            }
            .addOnFailureListener { result.error("ocr_failed", it.message, null) }
            .addOnCompleteListener { recognizer.close() }
    }

    private fun box(r: Rect): Map<String, Any> = mapOf(
        "x" to r.left.toDouble(),
        "y" to r.top.toDouble(),
        "w" to r.width().toDouble(),
        "h" to r.height().toDouble(),
    )

    private fun analyzeFrame(
        nv21: ByteArray,
        width: Int,
        height: Int,
        sensorRotation: Int,
        result: MethodChannel.Result,
    ) {
        val first = frameRotation ?: sensorRotation
        val rotations = listOf(first) + listOf(270, 90, 0, 180).filter { it != first }

        fun attempt(i: Int) {
            if (i == rotations.size) {
                result.success(mapOf("faces" to 0))
                return
            }
            val image = InputImage.fromByteArray(
                nv21, width, height, rotations[i], InputImage.IMAGE_FORMAT_NV21,
            )
            liveDetector.process(image)
                .addOnSuccessListener { faces ->
                    if (faces.isEmpty()) {
                        attempt(i + 1)
                        return@addOnSuccessListener
                    }
                    frameRotation = rotations[i]
                    // The largest face is the user's.
                    val face = faces.maxByOrNull { it.boundingBox.width() }!!
                    val left = face.leftEyeOpenProbability
                    val right = face.rightEyeOpenProbability
                    result.success(
                        mapOf(
                            "faces" to faces.size,
                            "yaw" to face.headEulerAngleY.toDouble(),
                            "eyeOpen" to if (left != null && right != null) {
                                ((left + right) / 2).toDouble()
                            } else null,
                        )
                    )
                }
                .addOnFailureListener { result.error("face_failed", it.message, null) }
        }
        attempt(0)
    }

    /// Decodes the image at [path] (JPEG, PNG, HEIC...), turns it upright from
    /// its EXIF orientation and scales it to at most [maxSide] px.
    private fun toJpeg(path: String, maxSide: Int): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSide) sample *= 2
        var bitmap = BitmapFactory.decodeFile(
            path, BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: throw IllegalArgumentException("Could not decode $path")

        val degrees = when (
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL,
            )
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val scale = min(1f, maxSide.toFloat() / max(bitmap.width, bitmap.height))
        if (degrees != 0f || scale < 1f) {
            val matrix = Matrix().apply {
                postScale(scale, scale)
                postRotate(degrees)
            }
            bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        }
        return ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it)
            it.toByteArray()
        }
    }
}
