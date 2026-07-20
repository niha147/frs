import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isStudent = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadOrCreateDeviceId();
  }

  Future<void> _loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var devId = prefs.getString('simulated_device_id');
    if (devId == null) {
      devId = 'device_${DateTime.now().millisecondsSinceEpoch}_${(100 + (DateTime.now().microsecond % 900))}';
      await prefs.setString('simulated_device_id', devId);
    }
    setState(() {
      _deviceId = devId;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
            isStudent: _isStudent,
            deviceId: _deviceId,
          );
    }
  }

  void _showServerUrlDialog() {
    final currentUrl = ref.read(serverUrlProvider);
    final controller = TextEditingController(text: currentUrl);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Server Configuration"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter backend API Base URL (e.g. Vercel/Render server link):",
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Server API URL",
                hintText: "https://your-backend.vercel.app/api/v1",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await ref.read(serverUrlProvider.notifier).setUrl(newUrl);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("API Server URL updated to: $newUrl"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for authentication errors
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F1E36), Color(0xFF1B365D)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Glow decoration shapes
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF008080).withAlpha(51),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1B365D).withAlpha(77),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: IconButton(
                          icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white70, size: 28),
                          onPressed: _showServerUrlDialog,
                          tooltip: "API Server Settings",
                        ),
                      ),
                    ),
                    Card(
                      color: Colors.white.withAlpha(242),
                      elevation: 12,
                      shadowColor: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Identity Face/Brand icon
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B365D).withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.face_retouching_natural_rounded,
                                  size: 54,
                                  color: Color(0xFF1B365D),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "SmartAttend AI",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B365D),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "AI-Powered Attendance Management",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Segmented Control or custom toggle tab
                              Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isStudent = false;
                                            _emailController.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: !_isStudent ? const Color(0xFF1B365D) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "Faculty / Admin",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: !_isStudent ? Colors.white : Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isStudent = true;
                                            _emailController.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _isStudent ? const Color(0xFF1B365D) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "Student",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: _isStudent ? Colors.white : Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Input Field (Email or Roll Number)
                              TextFormField(
                                controller: _emailController,
                                keyboardType: _isStudent ? TextInputType.text : TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: _isStudent ? "Roll Number" : "Email Address",
                                  prefixIcon: Icon(_isStudent ? Icons.badge_outlined : Icons.email_outlined),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return _isStudent ? "Roll number is required" : "Email address is required";
                                  }
                                  if (!_isStudent) {
                                    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!regex.hasMatch(value.trim())) {
                                      return "Enter a valid email address";
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(color: Colors.black87),
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Password is required";
                                  }
                                  if (value.length < 6) {
                                    return "Password must be at least 6 characters";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 36),
                              // Submit / Action
                              if (authState.status == AuthStatus.loading)
                                const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B365D)),
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    ElevatedButton(
                                      onPressed: _submit,
                                      child: const Text("Sign In"),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: _showServerUrlDialog,
                                      icon: const Icon(Icons.dns_rounded, size: 16, color: Color(0xFF1B365D)),
                                      label: Text(
                                        "Server: ${ref.watch(serverUrlProvider)}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1B365D),
                                          fontWeight: FontWeight.w600,
                                          decoration: TextUnderlineStyle.solid,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isStudent && _deviceId != null 
                          ? "Device Bound: ${_deviceId!.substring(0, 14)}..."
                          : "v1.0.0 — Secured with JWT & Biometrics",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
