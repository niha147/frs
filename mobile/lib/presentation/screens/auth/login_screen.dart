import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/presentation/providers/auth_provider.dart';
import 'package:smart_frs/presentation/providers/theme_provider.dart';
import 'package:smart_frs/presentation/widgets/theme_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _deptController = TextEditingController(text: "Computer Science");
  
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isStudent = false;
  int _selectedYear = 1;
  String _selectedSection = "A";
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
    _nameController.dispose();
    _rollController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      if (!_isSignUp) {
        // LOGIN
        ref.read(authProvider.notifier).login(
              _isStudent ? _rollController.text.trim() : _emailController.text.trim(),
              _passwordController.text,
              isStudent: _isStudent,
              deviceId: _deviceId,
            );
      } else {
        // SIGN UP / REGISTER
        if (_isStudent) {
          ref.read(authProvider.notifier).registerStudent(
                rollNumber: _rollController.text.trim(),
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                department: _deptController.text.trim(),
                year: _selectedYear,
                section: _selectedSection,
                password: _passwordController.text,
                deviceId: _deviceId,
              );
        } else {
          ref.read(authProvider.notifier).registerFaculty(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                department: _deptController.text.trim(),
                password: _passwordController.text,
              );
        }
      }
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
            content: Text(
              next.errorMessage!,
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
      }
    });

    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.9),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.palette_rounded,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.amberAccent
                                    : Colors.amber.shade700,
                                size: 26,
                              ),
                              onPressed: () => showThemeSelectorDialog(context, ref),
                              tooltip: "Theme & Accessibility",
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white70, size: 26),
                              onPressed: _showServerUrlDialog,
                              tooltip: "API Server Settings",
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      color: Theme.of(context).cardColor,
                      elevation: 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Identity Face/Brand icon
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.face_retouching_natural_rounded,
                                  size: 48,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "SmartAttend AI",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).textTheme.titleLarge?.color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isSignUp ? "Create a new account" : "AI-Powered Attendance Management",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Sign In / Sign Up Mode Switch
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(() => _isSignUp = false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: !_isSignUp ? primaryColor : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "Sign In",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: !_isSignUp ? Colors.white : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(() => _isSignUp = true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: _isSignUp ? primaryColor : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "Sign Up",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: _isSignUp ? Colors.white : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Role Toggle Tab (Faculty vs Student)
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isStudent = false;
                                            _emailController.clear();
                                            _rollController.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: !_isStudent ? primaryColor.withOpacity(0.8) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "Faculty / Admin",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: !_isStudent ? Colors.white : Colors.grey,
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
                                            _rollController.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _isStudent ? primaryColor.withOpacity(0.8) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "Student",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _isStudent ? Colors.white : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Full Name field for Sign Up
                              if (_isSignUp) ...[
                                TextFormField(
                                  controller: _nameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: "Full Name",
                                    prefixIcon: Icon(Icons.person_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Full name is required";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Roll Number field for Student
                              if (_isStudent) ...[
                                TextFormField(
                                  controller: _rollController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: "Roll Number (e.g. S1001)",
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Roll number is required";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Email Address Field
                              if (!_isStudent || _isSignUp) ...[
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: "Email Address",
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Email address is required";
                                    }
                                    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!regex.hasMatch(value.trim())) {
                                      return "Enter a valid email address";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Additional Registration Fields (Department, Year, Section)
                              if (_isSignUp) ...[
                                TextFormField(
                                  controller: _deptController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: "Department",
                                    prefixIcon: Icon(Icons.school_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Department is required";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                if (_isStudent) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          value: _selectedYear,
                                          decoration: const InputDecoration(
                                            labelText: "Year",
                                            prefixIcon: Icon(Icons.numbers),
                                          ),
                                          items: [1, 2, 3, 4].map((y) {
                                            return DropdownMenuItem(value: y, child: Text("Year $y"));
                                          }).toList(),
                                          onChanged: (val) => setState(() => _selectedYear = val!),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedSection,
                                          decoration: const InputDecoration(
                                            labelText: "Section",
                                            prefixIcon: Icon(Icons.class_outlined),
                                          ),
                                          items: ["A", "B", "C", "D"].map((sec) {
                                            return DropdownMenuItem(value: sec, child: Text("Sec $sec"));
                                          }).toList(),
                                          onChanged: (val) => setState(() => _selectedSection = val!),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ],

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  prefixIcon: const Icon(Icons.lock_outlined),
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
                              const SizedBox(height: 28),

                              // Submit / Action
                              if (authState.status == AuthStatus.loading)
                                const Center(
                                  child: CircularProgressIndicator(),
                                )
                              else
                                Column(
                                  children: [
                                    ElevatedButton(
                                      onPressed: _submit,
                                      child: Text(_isSignUp ? "Create Account" : "Sign In"),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isSignUp = !_isSignUp;
                                        });
                                      },
                                      child: Text(
                                        _isSignUp
                                            ? "Already have an account? Sign In"
                                            : "Don't have an account? Sign Up",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextButton.icon(
                                      onPressed: _showServerUrlDialog,
                                      icon: Icon(Icons.dns_rounded, size: 14, color: primaryColor),
                                      label: Text(
                                        "Server: ${ref.watch(serverUrlProvider)}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
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
                    const SizedBox(height: 20),
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
