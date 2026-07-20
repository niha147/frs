import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_frs/presentation/providers/auth_provider.dart';
import 'package:smart_frs/presentation/providers/student_provider.dart';
import 'package:smart_frs/presentation/providers/faculty_provider.dart';
import 'package:smart_frs/presentation/providers/subject_provider.dart';
import 'package:smart_frs/presentation/providers/class_provider.dart';

// Widgets
import 'package:smart_frs/presentation/screens/admin/widgets/student_form.dart';
import 'package:smart_frs/presentation/screens/admin/widgets/faculty_form.dart';
import 'package:smart_frs/presentation/screens/admin/widgets/subject_form.dart';
import 'package:smart_frs/presentation/screens/admin/widgets/class_form.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _searchController.clear();
        _searchQuery = '';
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _logout() {
    ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    
    final studentsState = ref.watch(studentListProvider);
    final facultyState = ref.watch(facultyListProvider);
    final subjectsState = ref.watch(subjectListProvider);
    final classesState = ref.watch(classListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SmartAttend AI — Admin",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            Text(
              "Welcome, ${user?.name ?? 'Admin'}",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.amberAccent : Colors.amber.shade700,
            ),
            tooltip: "Toggle Light/Dark Theme",
            onPressed: () {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              ref.read(themeProvider.notifier).toggleTheme(!isDark);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: "Students"),
            Tab(icon: Icon(Icons.supervised_user_circle_rounded), text: "Faculty"),
            Tab(icon: Icon(Icons.menu_book_rounded), text: "Courses"),
            Tab(icon: Icon(Icons.event_seat_rounded), text: "Sessions"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Local search query input bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search records...",
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. STUDENTS TAB
                studentsState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Error: ${e.toString()}")),
                  data: (list) {
                    final filtered = list.where((s) {
                      return s.name.toLowerCase().contains(_searchQuery) ||
                          s.rollNumber.toLowerCase().contains(_searchQuery) ||
                          s.email.toLowerCase().contains(_searchQuery);
                    }).toList();

                    return RefreshIndicator(
                      onRefresh: () => ref.read(studentListProvider.notifier).refresh(),
                      child: filtered.isEmpty
                          ? const Center(child: Text("No students found."))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final s = filtered[i];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: ListTile(
                                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("${s.rollNumber} • ${s.department} (Year ${s.year}-${s.section})"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Face register status trigger
                                        IconButton(
                                          icon: Icon(
                                            s.isFaceRegistered
                                                ? Icons.face_retouching_natural_rounded
                                                : Icons.face_rounded,
                                            color: s.isFaceRegistered ? Colors.green : Colors.grey,
                                          ),
                                          tooltip: s.isFaceRegistered ? "Face Registered" : "Register Face",
                                          onPressed: () {
                                            context.push('/register?studentId=${s.id}');
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () async {
                                            final result = await showDialog<Map<String, dynamic>>(
                                              context: context,
                                              builder: (ctx) => StudentForm(student: s),
                                            );
                                            if (result != null) {
                                              ref.read(studentListProvider.notifier).updateStudent(s.id, result);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                          onPressed: () {
                                            ref.read(studentListProvider.notifier).deleteStudent(s.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
                // 2. FACULTY TAB
                facultyState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Error: ${e.toString()}")),
                  data: (list) {
                    final filtered = list.where((f) {
                      return f.name.toLowerCase().contains(_searchQuery) ||
                          f.email.toLowerCase().contains(_searchQuery) ||
                          f.department.toLowerCase().contains(_searchQuery);
                    }).toList();

                    return RefreshIndicator(
                      onRefresh: () => ref.read(facultyListProvider.notifier).refresh(),
                      child: filtered.isEmpty
                          ? const Center(child: Text("No faculty accounts found."))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final f = filtered[i];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: ListTile(
                                    title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("${f.role.toUpperCase()} • ${f.department}"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () async {
                                            final result = await showDialog<Map<String, dynamic>>(
                                              context: context,
                                              builder: (ctx) => FacultyForm(faculty: f),
                                            );
                                            if (result != null) {
                                              ref.read(facultyListProvider.notifier).updateFaculty(f.id, result);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                          onPressed: () {
                                            ref.read(facultyListProvider.notifier).deleteFaculty(f.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
                // 3. SUBJECTS TAB
                subjectsState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Error: ${e.toString()}")),
                  data: (list) {
                    final filtered = list.where((subj) {
                      return subj.name.toLowerCase().contains(_searchQuery) ||
                          subj.code.toLowerCase().contains(_searchQuery) ||
                          subj.department.toLowerCase().contains(_searchQuery);
                    }).toList();

                    return RefreshIndicator(
                      onRefresh: () => ref.read(subjectListProvider.notifier).refresh(),
                      child: filtered.isEmpty
                          ? const Center(child: Text("No courses found."))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final subj = filtered[i];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: ListTile(
                                    title: Text(subj.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("${subj.code} • ${subj.department} (Year ${subj.year}-${subj.section})\nInstructor: ${subj.facultyName ?? 'Unassigned'}"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () async {
                                            final instructors = facultyState.value ?? [];
                                            final result = await showDialog<Map<String, dynamic>>(
                                              context: context,
                                              builder: (ctx) => SubjectForm(subject: subj, facultyList: instructors),
                                            );
                                            if (result != null) {
                                              ref.read(subjectListProvider.notifier).updateSubject(subj.id, result);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                          onPressed: () {
                                            ref.read(subjectListProvider.notifier).deleteSubject(subj.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
                // 4. SESSIONS TAB
                classesState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Error: ${e.toString()}")),
                  data: (list) {
                    final filtered = list.where((c) {
                      return c.classroom.toLowerCase().contains(_searchQuery) ||
                          c.subjectName.toLowerCase().contains(_searchQuery) ||
                          c.subjectCode.toLowerCase().contains(_searchQuery);
                    }).toList();

                    return RefreshIndicator(
                      onRefresh: () => ref.read(classListProvider.notifier).refresh(),
                      child: filtered.isEmpty
                          ? const Center(child: Text("No class sessions scheduled."))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final c = filtered[i];
                                // Parse dates
                                final start = DateTime.parse(c.scheduledStart);
                                final end = DateTime.parse(c.scheduledEnd);
                                final formattedTime = "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: ListTile(
                                    title: Text("${c.subjectCode} — ${c.subjectName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("Classroom: ${c.classroom}\nTime: $formattedTime (${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')})"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          c.status.toUpperCase(),
                                          style: TextStyle(
                                            color: c.status == 'active'
                                                ? Colors.green
                                                : c.status == 'past'
                                                    ? Colors.grey
                                                    : Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                          tooltip: "Cancel Session",
                                          onPressed: () {
                                            ref.read(classListProvider.notifier).deleteClassSession(c.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final tabIndex = _tabController.index;
          if (tabIndex == 0) {
            // Add student
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (ctx) => const StudentForm(),
            );
            if (result != null) {
              ref.read(studentListProvider.notifier).addStudent(result);
            }
          } else if (tabIndex == 1) {
            // Add faculty
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (ctx) => const FacultyForm(),
            );
            if (result != null) {
              ref.read(facultyListProvider.notifier).addFaculty(result);
            }
          } else if (tabIndex == 2) {
            // Add Subject
            final instructors = facultyState.value ?? [];
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (ctx) => SubjectForm(facultyList: instructors),
            );
            if (result != null) {
              ref.read(subjectListProvider.notifier).addSubject(result);
            }
          } else if (tabIndex == 3) {
            // Add Session
            final subjects = subjectsState.value ?? [];
            if (subjects.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please add a subject/course first before scheduling sessions.")),
              );
              return;
            }
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (ctx) => ClassForm(subjectList: subjects),
            );
            if (result != null) {
              ref.read(classListProvider.notifier).addClassSession(result);
            }
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
