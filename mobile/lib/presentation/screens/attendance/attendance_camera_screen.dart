import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/presentation/providers/attendance_provider.dart';

class AttendanceCameraScreen extends ConsumerStatefulWidget {
  final int classId;
  final String mode; // 'scan' (initial) or 'verify' (surprise checks)
  const AttendanceCameraScreen({super.key, required this.classId, required this.mode});

  @override
  ConsumerState<AttendanceCameraScreen> createState() => _AttendanceCameraScreenState();
}

class _AttendanceCameraScreenState extends ConsumerState<AttendanceCameraScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInit = false;
  bool _isLoading = false;
  String _errorMsg = '';

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
      
      // Select back-facing camera if available
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCamera,
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

  Future<void> _captureAndUpload() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isLoading = true);

    try {
      final XFile pictureFile = await _controller!.takePicture();
      
      // Prepare Multipart file upload
      final bytes = await pictureFile.readAsBytes();
      final formData = FormData.fromMap({
        'class_id': widget.classId,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'classroom_frame.jpg',
        ),
      });

      final dio = ref.read(dioProvider);
      
      // Select endpoint matching mode (initial vs surprise check)
      final url = widget.mode == 'verify' 
          ? '/attendance/verify-scan' 
          : '/attendance/scan';

      final response = await dio.post(url, data: formData);

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mode == 'verify' 
                ? "Surprise classroom verification processed!" 
                : "Classroom bulk scan attendance processed!"),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh logs cache
        ref.invalidate(attendanceLogsProvider(widget.classId));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String msg = "Scan execution failed. Please retry.";
        if (e is DioException && e.response?.data != null) {
          try {
            msg = e.response!.data['error']['message'] as String;
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Classroom Scanner")),
        body: Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red))),
      );
    }

    if (!_isInit || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Classroom Scanner")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == 'verify' ? "Surprise Verify Scan" : "Initial Attendance Scan"),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Matching face prints & validating liveness...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Stack(
              children: [
                // 1. LIVE CAMERA FULL PREVIEW
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),
                
                // 2. RECTANGULAR GRID FRAMING OVERLAY
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.teal.withAlpha(120),
                        width: 20,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 320,
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 20,
                              left: 20,
                              child: Text(
                                "FRAME CLASSROOM GRID",
                                style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. CAPTURE TRIGGER BUTTON BAR
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      onPressed: _captureAndUpload,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1B365D),
                      child: const Icon(Icons.camera_rounded, size: 36),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
