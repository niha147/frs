import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:smart_frs/presentation/providers/auth_provider.dart';
import 'package:smart_frs/presentation/providers/theme_provider.dart';
import 'package:smart_frs/presentation/widgets/theme_dialog.dart';
import 'package:smart_frs/presentation/providers/student_portal_provider.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final summaryAsync = ref.watch(studentSummaryProvider);
    final historyAsync = ref.watch(studentHistoryProvider);
    final student = authState.user;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.palette_rounded,
              color: isDark ? Colors.amberAccent : Colors.white,
            ),
            tooltip: "Theme & Accessibility",
            onPressed: () => showThemeSelectorDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
            tooltip: "Logout",
          ),
        ],
      ),
      body: student == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(studentSummaryProvider);
                ref.invalidate(studentHistoryProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Overview Card
                    _buildProfileCard(context, student),
                    const SizedBox(height: 24),

                    // Attendance summary title
                    Text(
                      "Subject-wise Attendance",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Attendance summary list
                    summaryAsync.when(
                      data: (summaries) => summaries.isEmpty
                          ? _buildEmptyCard("No subjects registered yet.")
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: summaries.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _buildSummaryTile(context, summaries[index]);
                              },
                            ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: Colors.teal),
                        ),
                      ),
                      error: (err, stack) => _buildErrorCard(err.toString()),
                    ),
                    const SizedBox(height: 24),

                    // History Title
                    Text(
                      "Attendance Logs",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // History list
                    historyAsync.when(
                      data: (history) => history.isEmpty
                          ? _buildEmptyCard("No attendance history found.")
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: history.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                return _buildHistoryTile(context, history[index]);
                              },
                            ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: Colors.teal),
                        ),
                      ),
                      error: (err, stack) => _buildErrorCard(err.toString()),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Look at the latest scheduled class from history or navigate to class selector
          historyAsync.whenData((history) {
            if (history.isNotEmpty) {
              final latestClass = history.first; // sorted desc
              context.push('/self-scan?classId=${latestClass.classId}');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No active class sessions found to mark self-attendance.")),
              );
            }
          });
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text("Self Attendance"),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic student) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B365D), Color(0xFF008080)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withAlpha(51),
            child: const Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  student.email, // email is mapped to roll number or email
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${student.department.toUpperCase()} • Sec ${student.role == 'student' ? 'A' : ''}", // stubbed section
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  Widget _buildSummaryTile(BuildContext context, SubjectSummary summary) {
    Color riskColor;
    switch (summary.riskStatus) {
      case 'SAFE':
        riskColor = Colors.greenAccent;
        break;
      case 'WARNING':
        riskColor = Colors.orangeAccent;
        break;
      case 'CRITICAL':
      default:
        riskColor = Colors.redAccent;
    }

    return Card(
      color: const Color(0xFF1B2C4A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.subjectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        summary.subjectCode,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor, width: 1),
                  ),
                  child: Text(
                    summary.riskStatus,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: summary.percentage / 100.0,
                      backgroundColor: Colors.white.withAlpha(30),
                      valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "${summary.percentage.toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Attended: ${summary.attended} / ${summary.totalClasses} classes",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, HistoryItem item) {
    Color statusColor;
    IconData statusIcon;
    switch (item.status) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'late':
        statusColor = Colors.orange;
        statusIcon = Icons.timelapse_rounded;
        break;
      case 'absent':
      default:
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
    }

    final parsedDate = DateTime.tryParse(item.scheduledStart) ?? DateTime.now();
    final formattedDate = DateFormat('EEE, MMM d • h:mm a').format(parsedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF15253F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subjectName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "$formattedDate • ${item.classroom}",
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.method == 'face_scan' ? 'Face Scan' : 'Manual',
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2C4A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withAlpha(100)),
      ),
      child: Text(
        "Failed to load data: $error",
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
