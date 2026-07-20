import 'dart:async';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/presentation/providers/student_portal_provider.dart';

enum LocationPermissionMode { granted, denied }

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

  // GPS Geofence State
  LocationPermissionMode _permMode = LocationPermissionMode.granted;
  bool _isInsideZone = true; // true = 14m, false = 1,800m away

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
        setState(() {
          _instruction = "Error fetching challenge. Tap refresh.";
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _secondsRemaining = 0;
          _challengeExpired = true;
          _instruction = "Challenge expired! Tap 🔄 to get a new challenge.";
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

      final bool isLocationAvailable = _permMode == LocationPermissionMode.granted;
      // Nullable coordinates (no 0.0, 0.0 fallbacks)
      final double? lat = isLocationAvailable ? (_isInsideZone ? 12.9716 : 12.9850) : null;
      final double? lon = isLocationAvailable ? (_isInsideZone ? 77.5946 : 77.6100) : null;

      final formDataMap = <String, dynamic>{
        'class_id': widget.classId,
        'location_available': isLocationAvailable,
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
      };

      if (lat != null && lon != null) {
        formDataMap['latitude'] = lat;
        formDataMap['longitude'] = lon;
      }

      final formData = FormData.fromMap(formDataMap);

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
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            backgroundColor: const Color(0xFF1A2234),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white, width: 1.5),
            ),
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
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text("Self Attendance Scan")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _errorMsg,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_isInit) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      );
    }

    final int distanceMeters = _permMode == LocationPermissionMode.denied
        ? 0
        : (_isInsideZone ? 14 : 1850);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Self Attendance Scan"),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.tealAccent),
            onPressed: _fetchChallenge,
            tooltip: "Get New Liveness Challenge",
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
                // Oval face framing overlay
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
                // Top Challenge Instruction Banner
                Positioned(
                  top: 16,
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
                // Bottom GPS Location Status Card
                Positioned(
                  bottom: 110,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.black.withAlpha(220),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _permMode == LocationPermissionMode.denied
                            ? Colors.amber
                            : (_isInsideZone ? Colors.greenAccent : Colors.redAccent),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _permMode == LocationPermissionMode.denied
                                    ? Icons.location_off_rounded
                                    : (_isInsideZone ? Icons.location_on_rounded : Icons.wrong_location_rounded),
                                color: _permMode == LocationPermissionMode.denied
                                    ? Colors.amber
                                    : (_isInsideZone ? Colors.greenAccent : Colors.redAccent),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _permMode == LocationPermissionMode.denied
                                      ? "Location access is required for this class."
                                      : (_isInsideZone
                                          ? "You are inside the classroom attendance zone."
                                          : "You are outside the classroom attendance zone."),
                                  style: TextStyle(
                                    color: _permMode == LocationPermissionMode.denied
                                        ? Colors.amberAccent
                                        : (_isInsideZone ? Colors.greenAccent : Colors.redAccent),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _permMode == LocationPermissionMode.denied
                                    ? "Permission: Denied"
                                    : "Permission: Granted",
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              if (_permMode == LocationPermissionMode.granted)
                                Text(
                                  "Distance: ${distanceMeters}m from room",
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 16),
                          // Location Controls / Test Simulator
                          Row(
                            children: [
                              const Text(
                                "GPS Simulation:",
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _permMode == LocationPermissionMode.denied
                                      ? "denied"
                                      : (_isInsideZone ? "inside" : "outside"),
                                  isExpanded: true,
                                  dropdownColor: Colors.black90,
                                  style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  underline: Container(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: "inside",
                                      child: Text("Inside Zone (14m) — PASS"),
                                    ),
                                    DropdownMenuItem(
                                      value: "outside",
                                      child: Text("Outside Zone (1850m) — FAIL"),
                                    ),
                                    DropdownMenuItem(
                                      value: "denied",
                                      child: Text("Location Permission Denied — FAIL"),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == "denied") {
                                        _permMode = LocationPermissionMode.denied;
                                      } else if (val == "inside") {
                                        _permMode = LocationPermissionMode.granted;
                                        _isInsideZone = true;
                                      } else {
                                        _permMode = LocationPermissionMode.granted;
                                        _isInsideZone = false;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom Submit Action Button
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: (_secondsRemaining > 0 && !_isLoading) ? _submitSelfAttendance : null,
                    icon: const Icon(Icons.verified_user_rounded),
                    label: Text(
                      _secondsRemaining == 0 ? "Challenge Expired — Tap Refresh" : "Verify & Submit Attendance",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
