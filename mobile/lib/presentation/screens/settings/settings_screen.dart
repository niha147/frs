import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/presentation/providers/auth_provider.dart';
import 'package:smart_frs/presentation/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final themeMode = ref.watch(themeProvider);

    final isDarkMode = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings & Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. PROFILE DETAILS CARD
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFF1B365D),
                      child: Icon(Icons.person_rounded, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.name ?? 'Loading User...',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildProfileRow("Department", user?.department ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildProfileRow("Role Title", (user?.role ?? 'N/A').toUpperCase()),
                    const SizedBox(height: 8),
                    _buildProfileRow("Phone Number", user?.phone ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. APP PREFERENCES CARD
            Card(
              elevation: 1,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Dark Theme Mode"),
                    subtitle: const Text("Toggle application interface color theme"),
                    secondary: Icon(
                      isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDarkMode ? Colors.yellow[700] : Colors.grey,
                    ),
                    value: isDarkMode,
                    onChanged: (val) {
                      ref.read(themeProvider.notifier).toggleTheme(val);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text("Application Version"),
                    trailing: const Text("v1.0.0"),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // 3. LOGOUT BUTTON
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[850],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text("Sign Out Account"),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
