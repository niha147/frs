import 'dart:async';
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

  // Dynamic Challenge state
  String? _challengeId;
  String? _challengeType;
  String _instruction = 'Requesting live challenge...';
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _challengeExpired = false;

  // Geofence simulation settings for testing on emulator/device
  bool _simulateInsideGeofence = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _fetchChallenge();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMsg = "No cameras detected on this device.");
        return;
      }
      
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

  Future<void> _fetchChallenge() async {
    _timer?.cancel();
    setState(() {
      _challengeExpired = false;
      _instruction = "Fetching live liveness challenge...";
      _secondsRemaining = 30;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/attendance/challenge',
        data: FormData.fromMap({'class_id': widget.classId}),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        setState(() {
          _challengeId = data['challenge_id'];
          _challengeType = data['challenge_type'];
          _instruction = data['instruction'] ?? 'Perform requested face action';
          _secondsRemaining = data['expires_in_seconds'] ?? 30;
        });

        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        String msg = "Could not fetch liveness challenge.";
        if (e is DioException && e.response?.data != null) {
          try {
            msg = e.response!.data['detail'] ?? e.response!.data['error']['message'];
          } catch (_) {}
        }
        setState(() {
          _instruction = "Challenge Error: $msg";
          _challengeExpired = true;
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _challengeExpired = true;
          _instruction = "Challenge expired. Tap refresh to get a new challenge.";
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _submitSelfAttendance() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_challengeId == null || _challengeExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Liveness challenge has expired. Please refresh the challenge."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final XFile pictureFile = await _controller!.takePicture();
      final bytes = await pictureFile.readAsBytes();

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('simulated_device_id') ?? 'unknown_device_id';

      final double lat = _simulateInsideGeofence ? 12.9716 : 12.9850;
      final double lon = _simulateInsideGeofence ? 77.5946 : 77.6100;

      final formData = FormData.fromMap({
        'class_id': widget.classId,
        'latitude': lat,
        'longitude': lon,
        'device_id': deviceId,
        'challenge_id': _challengeId,
        'blink_simulated': _challengeType == 'blink',
        'yaw_simulated': _challengeType == 'turn_left_right',
        'smile_simulated': _challengeType == 'smile',
        'pitch_simulated': _challengeType == 'look_up_down',
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
            content: Text("Attendance & Real-Time Liveness Verified!"),
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
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
        // Refresh challenge on error so user can retry safely
        _fetchChallenge();
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
        title: const Text("Challenge Verification"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchChallenge,
            tooltip: "Refresh Challenge",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text(
                    "Verifying real-time liveness & geofence...",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 340,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _challengeExpired ? Colors.red : Colors.teal.withAlpha(200),
                          width: 4,
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.elliptical(130, 170),
                        ),
                      ),
                    ),
                  ),
                ),
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
                          Icon(
                            _challengeExpired ? Icons.warning_amber_rounded : Icons.security,
                            color: _challengeExpired ? Colors.amber : Colors.tealAccent,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "REAL-TIME CHALLENGE",
                                      style: TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      "${_secondsRemaining}s",
                                      style: TextStyle(
                                        color: _secondsRemaining < 10 ? Colors.redAccent : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _instruction,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
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
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _challengeExpired
                        ? ElevatedButton.icon(
                            onPressed: _fetchChallenge,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Get New Challenge"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          )
                        : FloatingActionButton.large(
                            onPressed: _submitSelfAttendance,
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            child: const Text(
                              "Submit",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
