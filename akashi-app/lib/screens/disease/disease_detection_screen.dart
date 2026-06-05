import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DiseaseResult {
  final String classKey;
  final String diseaseName;
  final double confidence;

  const DiseaseResult({
    required this.classKey,
    required this.diseaseName,
    required this.confidence,
  });
}

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  State<DiseaseDetectionScreen> createState() => _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen> with WidgetsBindingObserver {
  static const String _modelAssetPath = 'assets/models/disease_model.tflite';
  static const String _classLabelsAssetPath = 'assets/models/class_labels.json';
  static const String _bengaliNamesAssetPath = 'assets/models/bengali_disease_names.json';
  static const String _treatmentAssetPath = 'assets/config/treatment_map.json';
  static const List<int> _expectedInputShape = [1, 224, 224, 3];
  static const List<int> _expectedOutputShape = [1, 19];

  CameraController? _cameraController;
  Interpreter? _interpreter;
  List<CameraDescription>? _cameras;
  List<String> _classLabels = [];
  Map<String, String> _diseaseNames = {};
  Map<String, String> _treatmentMap = {};

  bool _isCameraInitialized = false;
  bool _isModelReady = false;
  bool _isAnalyzing = false;
  String? _modelError;

  XFile? _capturedImage;
  DiseaseResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadModelAndConfigurations();
    _initializeCamera();
  }

  Future<void> _loadModelAndConfigurations() async {
    try {
      final labelsJson = await rootBundle.loadString(_classLabelsAssetPath);
      final namesJson = await rootBundle.loadString(_bengaliNamesAssetPath);
      final treatmentsJson = await rootBundle.loadString(_treatmentAssetPath);
      final interpreter = await Interpreter.fromAsset(_modelAssetPath);

      // Print/check input and output tensor details to confirm types
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      debugPrint('TFLite Model Input Tensor: type=${inputTensor.type}, shape=${inputTensor.shape}');
      debugPrint('TFLite Model Output Tensor: type=${outputTensor.type}, shape=${outputTensor.shape}');

      if (!mounted) {
        interpreter.close();
        return;
      }

      setState(() {
        _classLabels = List<String>.from(json.decode(labelsJson));
        _diseaseNames = Map<String, String>.from(json.decode(namesJson));
        _treatmentMap = Map<String, String>.from(json.decode(treatmentsJson));
        _interpreter = interpreter;
        _isModelReady = true;
        _modelError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelReady = false;
        _modelError = 'মডেল লোড করা যায়নি';
      });
      debugPrint('Failed to load TFLite disease model assets: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Native camera initialization failed: $e');
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up camera resources
      await cameraController.dispose();
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize camera
      _initializeCamera();
    }
  }

  Future<Uint8List> _preprocessImage(File imageFile) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Disease model is not loaded');
    }

    final bytes = await imageFile.readAsBytes();
    final rawImage = img.decodeImage(bytes);
    if (rawImage == null) {
      throw StateError('ছবিটি পড়া যায়নি');
    }

    // Explicitly resize image to 224x224 as required by the new model
    final resizedImage = img.copyResize(rawImage, width: 224, height: 224);

    // Build the Uint8List for input shape [1, 224, 224, 3]
    final inputBytes = Uint8List(1 * 224 * 224 * 3);
    var bufferIndex = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        inputBytes[bufferIndex++] = pixel.r.toInt().clamp(0, 255);
        inputBytes[bufferIndex++] = pixel.g.toInt().clamp(0, 255);
        inputBytes[bufferIndex++] = pixel.b.toInt().clamp(0, 255);
      }
    }

    return inputBytes;
  }

  Future<void> _captureAndAnalyzeLeafImage() async {
    if (!_isModelReady || _interpreter == null) {
      _showSnack(_modelError ?? 'মডেল এখনো প্রস্তুত নয়');
      return;
    }

    if (!_isCameraInitialized || _cameraController == null) {
      _showSnack('ক্যামেরা প্রস্তুত নয়');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    try {
      final image = await _cameraController!.takePicture();
      final result = await _runInference(File(image.path));

      if (!mounted) return;
      setState(() {
        _capturedImage = image;
        _result = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      debugPrint('Disease inference failed: $e');
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });
      _showSnack('ছবি বিশ্লেষণ করা যায়নি');
    }
  }

  Future<DiseaseResult> _runInference(File imageFile) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Disease model is not loaded');
    }

    final input = await _preprocessImage(imageFile);
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputClassCount = outputShape.isNotEmpty ? outputShape.last : _classLabels.length;
    final output = [List<double>.filled(outputClassCount, 0.0)];

    interpreter.run(input, output);

    final scores = output.first;
    var bestIndex = 0;
    var bestScore = scores.first;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestIndex = i;
        bestScore = scores[i];
      }
    }

    if (bestIndex >= _classLabels.length) {
      throw StateError('Model output index $bestIndex has no class label');
    }

    final classKey = _classLabels[bestIndex];
    return DiseaseResult(
      classKey: classKey,
      diseaseName: _diseaseNames[classKey] ?? 'অজানা রোগ (Unknown Disease)',
      confidence: bestScore.clamp(0.0, 1.0).toDouble(),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'NotoSansBengali')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _treatmentKeyForClass(String classKey) {
    const explicitMap = {
      'Rice_healthy': 'healthy',
      'Rice_brown_spot': 'brown_spot',
      'Rice_leaf_blast': 'rice_blast',
      'Rice_bacterial_leaf_blight': 'bacterial_leaf_blight',
    };

    return explicitMap[classKey] ?? classKey.toLowerCase().replaceAll('___', '_').replaceAll(' ', '_');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'পাতা রোগ নির্ণয় (Leaf Doctor)',
          style: TextStyle(fontFamily: 'NotoSansBengali', fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade900,
        actions: [
          IconButton(
            icon: Icon(
              _isModelReady ? Icons.memory : Icons.error_outline,
              color: _isModelReady ? Colors.white : Colors.orangeAccent,
            ),
            tooltip: _isModelReady ? 'Model Ready' : (_modelError ?? 'Model Not Ready'),
            onPressed: () => _showSnack(_isModelReady ? 'মডেল প্রস্তুত' : (_modelError ?? 'মডেল প্রস্তুত নয়')),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _isCameraInitialized && _cameraController != null
                ? CameraPreview(_cameraController!)
                : _buildCameraUnavailableView(),
          ),
          if (!_isAnalyzing && _result == null) _buildLeafFrame(),
          if (_result == null && !_isAnalyzing) _buildCaptureButton(),
          if (_isAnalyzing) _buildAnalyzingOverlay(),
          if (_result != null) _buildResultSlideSheet(),
        ],
      ),
    );
  }

  Widget _buildCameraUnavailableView() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_photography, size: 72.0, color: Colors.green.shade300.withOpacity(0.5)),
            const SizedBox(height: 16.0),
            const Text(
              'ক্যামেরা প্রস্তুত নয়',
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                color: Colors.white70,
                fontSize: 16.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeafFrame() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade400, width: 3.0),
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: Center(
          child: Text(
            'রোগাক্রান্ত পাতার অংশটি ফ্রেমের ভিতরে রাখুন',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              color: Colors.white.withOpacity(0.9),
              backgroundColor: Colors.black45,
              fontSize: 14.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 40.0,
      left: 0,
      right: 0,
      child: Center(
        child: InkWell(
          onTap: _captureAndAnalyzeLeafImage,
          borderRadius: BorderRadius.circular(40.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: (_isModelReady && _isCameraInitialized ? Colors.green.shade600 : Colors.grey.shade700)
                  .withOpacity(0.85),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.camera, size: 48.0, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green.shade400, strokeWidth: 5.0),
              const SizedBox(height: 24.0),
              const Text(
                'বিশ্লেষণ করা হচ্ছে...',
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultSlideSheet() {
    final result = _result!;
    final String treatmentKey = _treatmentKeyForClass(result.classKey);
    final String treatment = _treatmentMap[treatmentKey] ??
        'সুষম সার ব্যবস্থাপনা অনুসরণ করুন ও কৃষি অফিসে পরামর্শ করুন।';
    final double confidence = result.confidence;
    final bool isLowConfidence = confidence < 0.60;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.0)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20.0, offset: Offset(0, -5))
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            children: [
              Center(
                child: Container(
                  width: 50.0,
                  height: 5.0,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              Text(
                'বিশ্লেষণের ফলাফল',
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  color: Colors.green.shade900,
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                isLowConfidence ? 'নিশ্চিত নয় — কৃষি অফিসে ছবি দেখান' : result.diseaseName,
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  color: Colors.black87,
                  fontSize: 22.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'সঠিকতার হার (Confidence):',
                    style: TextStyle(fontFamily: 'NotoSansBengali', color: Colors.grey, fontSize: 13.0),
                  ),
                  Text(
                    '${(confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      color: isLowConfidence ? Colors.orange.shade700 : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              LinearProgressIndicator(
                value: confidence,
                backgroundColor: Colors.grey.shade200,
                color: isLowConfidence ? Colors.orange : Colors.green.shade600,
                minHeight: 8.0,
                borderRadius: BorderRadius.circular(4.0),
              ),
              const SizedBox(height: 20.0),
              if (!isLowConfidence)
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'প্রতিকার ও পরামর্শ:',
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.0,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      Text(
                        treatment,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          color: Colors.black87,
                          fontSize: 14.0,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'পুনরায় ছবি তুলুন',
                  style: TextStyle(fontFamily: 'NotoSansBengali', color: Colors.white, fontSize: 16.0),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                ),
                onPressed: () {
                  setState(() {
                    _result = null;
                    _capturedImage = null;
                  });
                },
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLowConfidenceWarning() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700),
          const SizedBox(width: 12.0),
          const Expanded(
            child: Text(
              'নিশ্চিত নয় - অনুগ্রহ করে ছবি কৃষি অফিসে দেখান',
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                color: Colors.black87,
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
