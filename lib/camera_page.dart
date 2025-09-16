import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  List<Face> _faces = [];

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true, // aktifkan contour
        enableClassification: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _startCamera();
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _startCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final faces = await _processCameraImage(
          image,
          frontCamera.sensorOrientation,
        );
        if (!mounted) return;
        setState(() => _faces = faces);
      } finally {
        _isDetecting = false;
      }
    });
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height * 3 ~/ 2);
    int pos = 0;

    for (int row = 0; row < height; row++) {
      int rowStart = row * yPlane.bytesPerRow;
      for (int col = 0; col < width; col++) {
        nv21[pos++] = yPlane.bytes[rowStart + col];
      }
    }

    final chromaHeight = (height / 2).floor();
    final chromaWidth = (width / 2).floor();
    for (int row = 0; row < chromaHeight; row++) {
      int uRowStart = row * uPlane.bytesPerRow;
      int vRowStart = row * vPlane.bytesPerRow;
      for (int col = 0; col < chromaWidth; col++) {
        nv21[pos++] = vPlane.bytes[vRowStart + col];
        nv21[pos++] = uPlane.bytes[uRowStart + col];
      }
    }
    return nv21;
  }

  Future<List<Face>> _processCameraImage(
    CameraImage image,
    int sensorOrientation,
  ) async {
    Uint8List bytes;
    InputImageFormat inputImageFormat;

    if (Platform.isAndroid && image.planes.length >= 3) {
      bytes = _convertYUV420ToNV21(image);
      inputImageFormat = InputImageFormat.nv21;
    } else {
      final bytesBuilder = BytesBuilder();
      for (final p in image.planes) {
        bytesBuilder.add(p.bytes);
      }
      bytes = bytesBuilder.takeBytes();
      inputImageFormat = InputImageFormat.bgra8888;
    }

    InputImageRotation rotation = InputImageRotation.rotation0deg;
    if (sensorOrientation == 90) rotation = InputImageRotation.rotation90deg;
    if (sensorOrientation == 180) rotation = InputImageRotation.rotation180deg;
    if (sensorOrientation == 270) rotation = InputImageRotation.rotation270deg;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: inputImageFormat,
      bytesPerRow: image.planes.isNotEmpty
          ? image.planes[0].bytesPerRow
          : image.width,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
    return await _faceDetector.processImage(inputImage);
  }

  bool _hasValidFace() {
    for (final face in _faces) {
      final rect = face.boundingBox;
      if (rect.width > 50 && rect.height > 50) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasFace = _hasValidFace();

    return Scaffold(
      appBar: AppBar(title: const Text('Camera Page')),
      body: Center(
        child:
            _cameraController == null || !_cameraController!.value.isInitialized
            ? const CircularProgressIndicator()
            : Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_cameraController!),
                  CustomPaint(
                    painter: FacePainter(
                      faces: _faces,
                      imageSize: Size(
                        _cameraController!.value.previewSize!.height,
                        _cameraController!.value.previewSize!.width,
                      ),
                    ),
                  ),
                  if (hasFace)
                    const Positioned(
                      top: 16,
                      left: 16,
                      child: Chip(
                        label: Text(
                          "Wajah Terdeteksi ✅",
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    )
                  else
                    const Positioned(
                      top: 16,
                      left: 16,
                      child: Chip(
                        label: Text(
                          "Wajah Belum Terdeteksi ❌",
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  FacePainter({required this.faces, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paintRect = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintPoint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (final face in faces) {
      // 1. Bounding box
      final r = face.boundingBox;
      final rect = Rect.fromLTRB(
        size.width - (r.right * scaleX),
        r.top * scaleY,
        size.width - (r.left * scaleX),
        r.bottom * scaleY,
      );
      canvas.drawOval(rect, paintRect);

      // 2. Landmark: mata dan hidung
      final landmarks = face.landmarks;
      final landmarkTypes = [
        FaceLandmarkType.leftEye,
        FaceLandmarkType.rightEye,
        FaceLandmarkType.noseBase,
      ];

      for (final type in landmarkTypes) {
        final landmark = landmarks[type];
        if (landmark != null) {
          final px = size.width - (landmark.position.x * scaleX);
          final py = landmark.position.y * scaleY;
          canvas.drawCircle(Offset(px, py), 4, paintPoint);
        }
      }

      // 3. Contour bibir
      final lipContours = [
        FaceContourType.upperLipTop,
        FaceContourType.upperLipBottom,
        FaceContourType.lowerLipTop,
        FaceContourType.lowerLipBottom,
      ];

      if (face.contours != null) {
        for (final contourType in lipContours) {
          final contour = face.contours![contourType];
          if (contour != null) {
            for (final point in contour.points) {
              final px = size.width - (point.x * scaleX);
              final py = point.y * scaleY;
              canvas.drawCircle(Offset(px, py), 2, paintPoint);
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) =>
      oldDelegate.faces != faces;
}
