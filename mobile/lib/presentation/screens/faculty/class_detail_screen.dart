import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_frs/presentation/providers/class_provider.dart';
import 'package:smart_frs/presentation/providers/student_provider.dart';
import 'package:smart_frs/presentation/providers/attendance_provider.dart';
import 'package:smart_frs/data/models/class_session_model.dart';
import 'package:smart_frs/data/models/student_model.dart';
import 'package:smart_frs/data/repositories/attendance_repository.dart';

class ClassDetailScreen extends ConsumerStatefulWidget {
  final int classId;
  const ClassDetailScreen({super.key, required this.classId});

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  bool _isUpdating = false;
  List<Map<String, dynamic>> _offlineQueue = [];
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _loadOfflineQueue();
  }

  Future<void> _loadOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedQueue = prefs.getStringList('offline_attendance_queue_${widget.classId}');
    if (storedQueue != null) {
      setState(() {
        _offlineQueue = storedQueue.map((item) {
          final parts = item.split('|');
          return {
            'studentId': parts[0],
            'classId': int.parse(parts[1]),
            'status': parts[2],
            'studentName': parts[3],
          };
        }).toList();
      });
    }
  }

  Future<void> _saveOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded = _offlineQueue.map((item) {
      return "${item['studentId']}|${item['classId']}|${item['status']}|${item['studentName']}";
    }).toList();
    await prefs.setStringList('offline_attendance_queue_${widget.classId}', encoded);
  }

  void _showOverrideDialog(String studentId, String studentName, String currentStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Override Status: $studentName"),
        content: const Text("Select corrected attendance marking status:"),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(80, 40),
                ),
                onPressed: () => _updateStatus(studentId, studentName, 'present'),
                child: const Text("Present", style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(80, 40),
                ),
                onPressed: () => _updateStatus(studentId, studentName, 'late'),
                child: const Text("Late", style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(80, 40),
                ),
                onPressed: () => _updateStatus(studentId, studentName, 'absent'),
                child: const Text("Absent", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String studentId, String studentName, String newStatus) async {
    Navigator.of(context).pop(); // Close dialog
    
    if (_isOfflineMode) {
      setState(() {
        _offlineQueue.removeWhere((item) => item['studentId'] == studentId);
        _offlineQueue.add({
          'studentId': studentId,
          'classId': widget.classId,
          'status': newStatus,
          'studentName': studentName,
        });
      });
      await _saveOfflineQueue();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Offline cached: $studentName marked ${newStatus.toUpperCase()}"),
          backgroundColor: Colors.teal,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);
    
    try {
      await ref.read(attendanceRepositoryProvider).submitManualOverride(studentId, widget.classId, newStatus);
      ref.invalidate(attendanceLogsProvider(widget.classId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Marking updated to ${newStatus.toUpperCase()} successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update status: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _syncOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    setState(() => _isUpdating = true);
    int successCount = 0;
    int failCount = 0;
    
    final repo = ref.read(attendanceRepositoryProvider);
    final listCopy = List<Map<String, dynamic>>.from(_offlineQueue);
    
    for (final item in listCopy) {
      try {
        await repo.submitManualOverride(
          item['studentId'] as String,
          item['classId'] as int,
          item['status'] as String,
        );
        successCount++;
        setState(() {
          _offlineQueue.removeWhere((q) => q['studentId'] == item['studentId']);
        });
      } catch (e) {
        failCount++;
      }
    }
    
    await _saveOfflineQueue();
    ref.invalidate(attendanceLogsProvider(widget.classId));
    
    setState(() => _isUpdating = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sync complete: $successCount synced, $failCount failed."),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classListProvider).value ?? [];
    final students = ref.watch(studentListProvider).value ?? [];
    final logsState = ref.watch(attendanceLogsProvider(widget.classId));

    // Find class session details
    final ClassSessionModel session = classes.firstWhere(
      (c) => c.id == widget.classId,
      orElse: () => ClassSessionModel(
        id: widget.classId,
        subjectId: 0,
        subjectName: "Course",
        subjectCode: "CODE",
        classroom: "Unknown",
        scheduledStart: DateTime.now().toIso8601String(),
        scheduledEnd: DateTime.now().toIso8601String(),
        status: "scheduled",
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("${session.subjectCode} Details"),
        actions: [
          Row(
            children: [
              const Text("Offline Mode", style: TextStyle(fontSize: 12)),
              Switch(
                value: _isOfflineMode,
                activeThumbColor: Colors.tealAccent,
                onChanged: (val) {
                  setState(() {
                    _isOfflineMode = val;
                  });
                },
              ),
            ],
          ),
          if (_offlineQueue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: Colors.tealAccent),
              onPressed: _syncOfflineQueue,
              tooltip: "Sync ${_offlineQueue.length} offline records",
            ),
        ],
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER INFO CARD
                Card(
                  margin: const EdgeInsets.all(16),
                  color: const Color(0xFF1B365D),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.subjectName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Room: ${session.classroom}",
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        if (_isOfflineMode) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(50),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Offline Mode Active: ${_offlineQueue.length} pending sync.",
                                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Scan shortcuts (hidden if offline mode to encourage manual entry when no net)
                        if (!_isOfflineMode)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1B365D),
                                  ),
                                  icon: const Icon(Icons.camera_alt_rounded),
                                  label: const Text("Initial Scan"),
                                  onPressed: () {
                                    context.push('/attendance-camera?classId=${widget.classId}&mode=scan');
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white),
                                  ),
                                  icon: const Icon(Icons.security_rounded),
                                  label: const Text("Surprise check"),
                                  onPressed: () {
                                    context.push('/attendance-camera?classId=${widget.classId}&mode=verify');
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                // 2. SUMMARY COUNTS
                logsState.when(
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                  data: (serverLogs) {
                    // Calculate effective logs incorporating offline modifications
                    final List<AttendanceLogModel> logs = List<AttendanceLogModel>.from(serverLogs);
                    for (final queued in _offlineQueue) {
                      final idx = logs.indexWhere((l) => l.studentId == queued['studentId']);
                      if (idx != -1) {
                        final existing = logs[idx];
                        logs[idx] = AttendanceLogModel(
                          id: existing.id,
                          studentId: existing.studentId,
                          classId: existing.classId,
                          status: queued['status'] as String,
                          method: 'offline',
                          isFlagged: false,
                          markedAt: existing.markedAt,
                        );
                      }
                    }

                    final total = logs.length;
                    final present = logs.where((l) => l.status == 'present' || l.status == 'late').length;
                    final flagged = logs.where((l) => l.isFlagged).length;
                    final absent = total - present;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard("Enrolled", total.toString(), Colors.blue),
                          _buildStatCard("Present", present.toString(), Colors.green),
                          _buildStatCard("Absent", absent.toString(), Colors.red),
                          _buildStatCard("Flagged", flagged.toString(), Colors.orange),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Student Attendance Logs",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. TABULAR LIST
                Expanded(
                  child: logsState.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: ${e.toString()}")),
                    data: (serverLogs) {
                      // Apply local queue logs
                      final List<AttendanceLogModel> logs = List<AttendanceLogModel>.from(serverLogs);
                      for (final queued in _offlineQueue) {
                        final idx = logs.indexWhere((l) => l.studentId == queued['studentId']);
                        if (idx != -1) {
                          final existing = logs[idx];
                          logs[idx] = AttendanceLogModel(
                            id: existing.id,
                            studentId: existing.studentId,
                            classId: existing.classId,
                            status: queued['status'] as String,
                            method: 'offline',
                            isFlagged: false,
                            markedAt: existing.markedAt,
                          );
                        } else {
                          // Fallback display if not fetched from server
                          logs.add(AttendanceLogModel(
                            id: 0,
                            studentId: queued['studentId'] as String,
                            classId: queued['classId'] as int,
                            status: queued['status'] as String,
                            method: 'offline',
                            isFlagged: false,
                            markedAt: DateTime.now().toIso8601String(),
                          ));
                        }
                      }

                      if (logs.isEmpty) {
                        return const Center(child: Text("No logs recorded. Perform a classroom scan first."));
                      }
                      
                      return RefreshIndicator(
                        onRefresh: () => ref.refresh(attendanceLogsProvider(widget.classId).future),
                        child: ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, idx) {
                            final log = logs[idx];
                            // Search student
                            final student = students.firstWhere(
                              (s) => s.id == log.studentId,
                              orElse: () => StudentModel(
                                id: log.studentId,
                                name: "Unknown Student",
                                rollNumber: "N/A",
                                email: "",
                                phone: "",
                                department: "",
                                year: 1,
                                section: "",
                                isFaceRegistered: false,
                                isActive: true,
                              ),
                            );

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("Roll No: ${student.rollNumber} • ${log.method.toUpperCase()}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (log.isFlagged) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.red[200]!),
                                        ),
                                        child: const Text("BUNK", style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    _buildStatusBadge(log.status),
                                  ],
                                ),
                                onTap: () => _showOverrideDialog(log.studentId, student.name, log.status),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51), width: 1),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey[100]!;
    Color fg = Colors.grey;
    if (status == 'present') {
      bg = Colors.green[50]!;
      fg = Colors.green;
    } else if (status == 'late') {
      bg = Colors.orange[50]!;
      fg = Colors.orange;
    } else if (status == 'absent') {
      bg = Colors.red[50]!;
      fg = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
