import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_frs/presentation/providers/auth_provider.dart';
import 'package:smart_frs/presentation/providers/theme_provider.dart';
import 'package:smart_frs/presentation/widgets/theme_dialog.dart';
import 'package:smart_frs/presentation/providers/class_provider.dart';
import 'package:smart_frs/presentation/providers/notification_provider.dart';

class FacultyDashboard extends ConsumerStatefulWidget {
  const FacultyDashboard({super.key});

  @override
  ConsumerState<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends ConsumerState<FacultyDashboard> {
  String _selectedFilter = 'all'; // all, active, scheduled, past

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final classesState = ref.watch(classListProvider);
    final notificationsState = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SmartAttend AI — Faculty",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            Text(
              "Instructor: ${user?.name ?? 'Faculty'}",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.palette_rounded,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.amberAccent : Colors.white,
            ),
            tooltip: "Theme & Accessibility",
            onPressed: () => showThemeSelectorDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. WARNING ALERTS CAROUSEL/LIST VIEW
          notificationsState.when(
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
            data: (notifications) {
              final unread = notifications.where((n) => !n.isRead).toList();
              if (unread.isEmpty) return const SizedBox.shrink();
              
              return Container(
                height: 90,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: unread.length,
                  itemBuilder: (context, i) {
                    final n = unread[i];
                    return Container(
                      width: 320,
                      margin: const EdgeInsets.only(right: 12),
                      child: Card(
                        color: Colors.red[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red[200]!, width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(n.title, style: const TextStyle(color: Colors.red)),
                                content: Text(n.message),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      ref.read(notificationProvider.notifier).markRead(n.id);
                                      Navigator.of(ctx).pop();
                                    },
                                    child: const Text("Dismiss & Mark Read"),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        n.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n.message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          
          // 2. SEGMENT FILTERS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Assigned Sessions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("All Classes")),
                    DropdownMenuItem(value: 'active', child: Text("Active Now")),
                    DropdownMenuItem(value: 'scheduled', child: Text("Scheduled")),
                    DropdownMenuItem(value: 'past', child: Text("Past")),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedFilter = v);
                  },
                ),
              ],
            ),
          ),
          
          // 3. CLASSES LISTING
          Expanded(
            child: classesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("Error: ${e.toString()}")),
              data: (list) {
                // Filter
                final filtered = list.where((c) {
                  if (_selectedFilter == 'all') return true;
                  return c.status == _selectedFilter;
                }).toList();
                
                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(classListProvider.notifier).refresh();
                    await ref.read(notificationProvider.notifier).refresh();
                  },
                  child: filtered.isEmpty
                      ? const Center(child: Text("No class sessions found matching this filter."))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final start = DateTime.parse(c.scheduledStart);
                            final end = DateTime.parse(c.scheduledEnd);
                            final timeStr = "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 2,
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: c.status == 'active'
                                        ? Colors.green[50]
                                        : c.status == 'scheduled'
                                            ? Colors.blue[50]
                                            : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.class_rounded,
                                    color: c.status == 'active'
                                        ? Colors.green
                                        : c.status == 'scheduled'
                                            ? Colors.blue
                                            : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  "${c.subjectCode} — ${c.subjectName}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "Room: ${c.classroom}\nTime: $timeStr (${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')})",
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: c.status == 'active'
                                            ? Colors.green
                                            : c.status == 'scheduled'
                                                ? Colors.blue
                                                : Colors.grey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        c.status.toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                  ],
                                ),
                                onTap: () {
                                  context.push('/class/${c.id}');
                                },
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
}
