import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img; // Pre-processing utility

// Mock result model for sandbox developer testing
class MockResult {
  final String disease;
  final double confidence;

  MockResult({required this.disease, required this.confidence});
}

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({Key? super.key}) : super(key: super);

  @override
  State<DiseaseDetectionScreen> createState() => _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false;
  bool _isMockMode = true; // STUB: Bypasses native camera access during emulator testing

  // State holdings
  XFile? _capturedImage;
  MockResult? _result;
  Map<String, String> _diseaseNames = {};
  Map<String, String> _treatmentMap = {};

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
    _initializeCamera();
  }

  // Load local Bengali configs dynamically
  Future<void> _loadConfigurations() async {
    try {
      final namesJson = await rootBundle.loadString('assets/config/bengali_disease_names.json');
      final treatmentsJson = await rootBundle.loadString('assets/config/treatment_map.json');
      
      setState(() {
        _diseaseNames = Map<String, String>.from(json.decode(namesJson));
        _treatmentMap = Map<String, String>.from(json.decode(treatmentsJson));
      });
    } catch (e) {
      debugPrint("Failed to load disease dictionary assets: $e");
      // Hardcoded fallback maps if assets are missing
      _diseaseNames = {
        "healthy": "সুস্থ ফসল (Healthy)",
        "brown_spot": "বাদামি দাগ রোগ (Brown Spot)",
        "rice_blast": "ব্লাস্ট রোগ (Rice Blast)",
        "bacterial_leaf_blight": "ব্যাকটেরিয়াল ব্লাইট (Leaf Blight)"
      };
      _treatmentMap = {
        "healthy": "আপনার ফসল সুস্থ ও সবল রয়েছে। সুষম সার ও নিয়মিত সেচ ব্যবস্থাপনা বজায় রাখুন।",
        "brown_spot": "ইউরিয়া সারের অতিরিক্ত প্রয়োগ বন্ধ করুন এবং পটাশ সারের মাত্রা বাড়িয়ে দিন। আক্রমণ তীব্র হলে ম্যানকোজেব বা প্রোপিকোনাজল স্প্রে করুন।",
        "rice_blast": "নাইট্রোজেন অতিরিক্ত দেবেন না এবং জমিতে পানি জমিয়ে রাখুন। আক্রমণ বেশি হলে ট্রাইসাইক্লাজল স্প্রে করুন।"
      };
    }
  }

  // Initialize device cameras
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (!mounted) return;
        
        setState(() {
          _isCameraInitialized = true;
          _isMockMode = false; // Disable mock if native camera succeeds
        });
      }
    } catch (e) {
      debugPrint("Native camera initialization failed: $e. Reverting to Mock sandbox.");
      setState(() {
        _isMockMode = true;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // Pre-process raw capture (resize 224x224 RGB, normalize array float [0,1])
  // STUB: Bypasses physical disk overhead in parallel builds
  Future<List<List<List<List<double>>>>> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final rawImage = img.decodeImage(bytes);
    if (rawImage == null) throw Exception("Failed to decode image");

    // 1. Downsample to 224x224
    final resizedImage = img.copyResize(rawImage, width: 224, height: 224);

    // 2. Format to standard normalized float dimensions: [1, 224, 224, 3]
    var inputTensor = List.generate(
      1,
      (_) => List.generate(
        224,
        (_) => List.generate(
          224,
          (_) => List.filled(3, 0.0),
        ),
      ),
    );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        // Normalize channel bytes [0-255] to float [0,1]
        inputTensor[0][y][x][0] = pixel.r / 255.0; // Red
        inputTensor[0][y][x][1] = pixel.g / 255.0; // Green
        inputTensor[0][y][x][2] = pixel.b / 255.0; // Blue
      }
    }

    return inputTensor;
  }

  // Triggers inference pipelines
  Future<void> _analyzeLeafImage() async {
    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    // Simulate preprocessing and computation latency (WOW factor shimmer loaders)
    await Future.delayed(const Duration(milliseconds: 1800));

    // STUB: Replace with real tflite_flutter inference when model delivered
    // Return mock result for UI testing:
    final mockResult = MockResult(disease: "brown_spot", confidence: 0.87);

    setState(() {
      _isAnalyzing = false;
      _result = mockResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "পাতা রোগ নির্ণয় (Leaf Doctor)",
          style: TextStyle(fontFamily: "NotoSansBengali", fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade900,
        actions: [
          // Toggle between live and mock sandbox mode
          IconButton(
            icon: Icon(
              _isMockMode ? Icons.bug_report : Icons.camera_alt,
              color: _isMockMode ? Colors.orangeAccent : Colors.white,
            ),
            tooltip: _isMockMode ? "Mock Mode Active" : "Camera Active",
            onPressed: () {
              setState(() {
                _isMockMode = !_isMockMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  _isMockMode ? "মক স্যান্ডবক্স মোড সক্রিয় করা হয়েছে।" : "লাইভ ক্যামেরা মোড সক্রিয় করা হয়েছে।",
                  style: const TextStyle(fontFamily: "NotoSansBengali"),
                ),
                duration: const Duration(seconds: 1),
              ));
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // ─── CAMERA VIEWFINDER / MOCK PREVIEW ───────────────────────────────
          Positioned.fill(
            child: (_isCameraInitialized && !_isMockMode)
                ? CameraPreview(_cameraController!)
                : _buildMockCameraViewfinder(),
          ),

          // ─── GLASSMORPHIC LEAF VIEW OVERLAY FRAME ──────────────────────────
          if (!_isAnalyzing && _result == null)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.shade400, width: 3.0),
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: Center(
                  child: Text(
                    "রোগাক্রান্ত পাতার অংশটি ফ্রেমের ভিতরে রাখুন",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "NotoSansBengali",
                      color: Colors.white.withOpacity(0.9),
                      backgroundColor: Colors.black45,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ),
            ),

          // ─── CAPTURE BUTTON BLOCK ──────────────────────────────────────────
          if (_result == null && !_isAnalyzing)
            Positioned(
              bottom: 40.0,
              left: 0,
              right: 0,
              child: Center(
                child: InkWell(
                  onTap: _analyzeLeafImage,
                  borderRadius: BorderRadius.circular(40.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600.withOpacity(0.85),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))
                      ],
                    ),
                    child: const Icon(Icons.camera, size: 48.0, color: Colors.white),
                  ),
                ),
              ),
            ),

          // ─── WOW SHIMMER LOADER / ANALYZING STATE ──────────────────────────
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.green.shade400, strokeWidth: 5.0),
                      const SizedBox(height: 24.0),
                      const Text(
                        "বিশ্লেষণ করা হচ্ছে...",
                        style: TextStyle(
                          fontFamily: "NotoSansBengali",
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ─── INTERACTIVE ADVISORY SLIDE-UP SHEET ───────────────────────────
          if (_result != null)
            _buildResultSlideSheet(context, screenHeight),
        ],
      ),
    );
  }

  // Builds a responsive graphic placeholder for standard sandboxing
  Widget _buildMockCameraViewfinder() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 72.0, color: Colors.green.shade300.withOpacity(0.5)),
            const SizedBox(height: 16.0),
            const Text(
              "মক সিমুলেশন ভিউফাইন্ডার সক্রিয়",
              style: TextStyle(
                fontFamily: "NotoSansBengali",
                color: Colors.white70,
                fontSize: 16.0,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              "নিচে ক্যাপচার বোতামে চাপুন।",
              style: TextStyle(
                fontFamily: "NotoSansBengali",
                color: Colors.white.withOpacity(0.5),
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Premium, sliding glassmorphic layout compiling advisories
  Widget _buildResultSlideSheet(BuildContext context, double screenHeight) {
    final String diseaseKey = _result!.disease;
    final String title = _diseaseNames[diseaseKey] ?? "অজানা রোগ (Unknown Disease)";
    final String treatment = _treatmentMap[diseaseKey] ?? "সুষম সার ব্যবস্থাপনা অনুসরণ করুন ও কৃষি অফিসে পরামর্শ করুন।";
    final double confidence = _result!.confidence;
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
              // Slide bar indicator
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

              // Title Section
              Text(
                "বিশ্লেষণের ফলাফল",
                style: TextStyle(
                  fontFamily: "NotoSansBengali",
                  color: Colors.green.shade900,
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: "NotoSansBengali",
                  color: Colors.black87,
                  fontSize: 22.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16.0),

              // Confidence Level Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "সঠিকতার হার (Confidence):",
                    style: TextStyle(fontFamily: "NotoSansBengali", color: Colors.grey, fontSize: 13.0),
                  ),
                  Text(
                    "${(confidence * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontFamily: "NotoSansBengali",
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

              // Low Confidence Warning Alert
              if (isLowConfidence)
                Container(
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
                          "নিশ্চিত নয় — অনুগ্রহ করে ছবি কৃষি অফিসে দেখান",
                          style: TextStyle(
                            fontFamily: "NotoSansBengali",
                            color: Colors.black87,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isLowConfidence) const SizedBox(height: 20.0),

              // Treatment Section Card
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
                      "প্রতিকার ও পরামর্শ:",
                      style: TextStyle(
                        fontFamily: "NotoSansBengali",
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      treatment,
                      style: const TextStyle(
                        fontFamily: "NotoSansBengali",
                        color: Colors.black87,
                        fontSize: 14.0,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // Recapture buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  "পুনরায় ছবি তুলুন",
                  style: TextStyle(fontFamily: "NotoSansBengali", color: Colors.white, fontSize: 16.0),
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
}
