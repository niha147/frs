import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/presentation/providers/student_portal_provider.dart';

class SelfAttendanceScanScreen extends ConsumerStatefulWidget {
  final int classId;
  const SelfAttendanceScanScreen({super.key, required this.classId});

  @override
  ConsumerState<SelfAttendanceScanScreen> createState() => _SelfAttendanceScanScreenState();
}

class _SelfAttendanceScanScreenState extends ConsumerState<SelfAttendanceScanScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInit = false;
  bool _isLoading = false;
  String _errorMsg = '';
  int _currentStep = 0;
  
  // Geofence simulation settings for testing on emulator/device
  bool _simulateInsideGeofence = true; 

  final List<String> _guidedPrompts = [
    'Look straight into the camera',
    'Blink your eyes twice',
    'Smile for liveness verification',
    'Hold steady. Capturing face...',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMsg = "No cameras detected on this device.");
        return;
      }
      
      // Select front-facing camera
      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = "Failed to open camera: ${e.toString()}");
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _nextGuidedStep() async {
    if (_currentStep < _guidedPrompts.length - 1) {
      setState(() => _currentStep++);
    } else {
      await _submitSelfAttendance();
    }
  }

  Future<void> _submitSelfAttendance() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isLoading = true);

    try {
      final XFile pictureFile = await _controller!.takePicture();
      final bytes = await pictureFile.readAsBytes();

      // Retrieve device signature
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('simulated_device_id') ?? 'unknown_device_id';

      // Mock coordinates matching the backend geofence test:
      // Valid coordinates match the class coordinate; invalid coordinates are set outside the 50m radius.
      final double lat = _simulateInsideGeofence ? 12.9716 : 12.9850;
      final double lon = _simulateInsideGeofence ? 77.5946 : 77.6100;

      final formData = FormData.fromMap({
        'class_id': widget.classId,
        'latitude': lat,
        'longitude': lon,
        'device_id': deviceId,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'selfie.jpg',
        ),
      });

      final dio = ref.read(dioProvider);
      final response = await dio.post('/attendance/self-scan', data: formData);

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Attendance recorded successfully via Selfie Scan!"),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(studentSummaryProvider);
        ref.invalidate(studentHistoryProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String msg = "Self scan verification failed.";
        if (e is DioException && e.response?.data != null) {
          try {
            msg = e.response!.data['detail'] ?? e.response!.data['error']['message'] as String;
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Self Recognition")),
        body: Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red))),
      );
    }

    if (!_isInit || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Self Recognition")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Verify Presence"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text(
                    "Validating face profile & geofence location...",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Live camera preview
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),
                
                // Face Oval framing overlay
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 340,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.teal.withAlpha(200),
                          width: 4,
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(130, 170),
                        ),
                      ),
                    ),
                  ),
                ),

                // Liveness guide instruction card
                Positioned(
                  top: 20,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.black.withAlpha(200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.teal, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "LIVENESS INSTRUCTION",
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _guidedPrompts[_currentStep],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Mock location toggle for testing geofencing
                Positioned(
                  bottom: 120,
                  left: 20,
                  right: 20,
                  child: Card(
                    color: Colors.black.withAlpha(180),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Mock Location:",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          DropdownButton<bool>(
                            value: _simulateInsideGeofence,
                            dropdownColor: Colors.black87,
                            style: const TextStyle(color: Colors.tealAccent, fontSize: 13),
                            underline: Container(),
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text("Inside Classroom (PASS)"),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text("Outside Classroom (FAIL)"),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _simulateInsideGeofence = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Execution/Verification Step Action Button
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      onPressed: _nextGuidedStep,
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      child: Text(
                        _currentStep == _guidedPrompts.length - 1 ? "Scan" : "Next",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
