import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/presentation/providers/student_provider.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  final String? studentId;
  const RegistrationScreen({super.key, this.studentId});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInit = false;
  bool _isLoading = false;
  String _errorMsg = '';
  int _currentStep = 0;

  final List<String> _guidedPrompts = [
    'Look straight at the camera',
    'Slowly turn your head LEFT',
    'Slowly turn your head RIGHT',
    'Tilt your head slightly UP',
    'Hold steady. Capturing face print...',
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMsg = 'No cameras found on this device.');
        return;
      }
      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) setState(() => _isInit = true);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Camera error: ${e.toString()}');
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
      await _captureAndRegister();
    }
  }

  Future<void> _captureAndRegister() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (widget.studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No student ID provided for enrollment.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final XFile pictureFile = await _controller!.takePicture();
      final bytes = await pictureFile.readAsBytes();

      final formData = FormData.fromMap({
        'is_primary': 'true',
        'blink_simulated': 'true',
        'yaw_simulated': 'true',
        'smile_simulated': 'true',
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'face_register.jpg',
        ),
      });

      final dio = ref.read(dioProvider);

      // Correct endpoint: POST /students/{student_id}/faces  →  returns 201 Created
      final response = await dio.post(
        '/students/${widget.studentId}/faces',
        data: formData,
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric enrollment finished successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(studentListProvider.notifier).refresh();
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('FACE REGISTRATION EXCEPTION: $e');
      if (mounted) {
        String msg = 'Enrollment failed: ${e.toString()}';
        if (e is DioException && e.response?.data != null) {
          try {
            msg = e.response!.data['detail'] as String? ??
                  e.response!.data['error']['message'] as String;
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Face Enrollment')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(_errorMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                const Text(
                  'Make sure you have allowed camera permission in your browser.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMsg = '';
                      _isInit = false;
                    });
                    _initCamera();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInit || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Face Enrollment')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Starting camera...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('Face Registration'),
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Uploading facial landmarks...',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            )
          : Column(
              children: [
                // Progress bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of ${_guidedPrompts.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / _guidedPrompts.length,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF4FC3F7)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),

                // Live camera preview inside circular frame
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glowing ring
                        Container(
                          width: 296,
                          height: 296,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF4FC3F7), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF4FC3F7).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        // Camera preview
                        ClipOval(
                          child: SizedBox(
                            width: 280,
                            height: 280,
                            child: CameraPreview(_controller!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Instruction panel
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B2A45),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Guided Step ${_currentStep + 1} of ${_guidedPrompts.length}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white54),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _guidedPrompts[_currentStep],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _nextGuidedStep,
                          icon: Icon(
                            _currentStep < _guidedPrompts.length - 1
                                ? Icons.arrow_forward
                                : Icons.camera_alt,
                          ),
                          label: Text(
                            _currentStep < _guidedPrompts.length - 1
                                ? 'Next Step'
                                : 'Complete & Capture',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4FC3F7),
                            foregroundColor: Colors.black,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
