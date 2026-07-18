import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/presentation/providers/subject_provider.dart';
import 'package:smart_frs/presentation/providers/reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Filters
  int? _subjectId;
  String? _department;
  int? _year;
  String? _section;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  String _format = 'pdf'; // pdf, excel, csv
  bool _isGenerating = false;
  
  // Table search and sort
  late TabController _tabController;
  String _searchQuery = '';
  String _sortColumn = 'rollNumber';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _generateReport(bool isOverall) async {
    setState(() => _isGenerating = true);
    
    try {
      final dio = ref.read(dioProvider);
      
      // Setup query parameters
      final queryParams = {
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'department': _department,
        'year': _year?.toString(),
        'section': _section,
        'format': _format,
      };
      if (_subjectId != null) {
        queryParams['subject_id'] = _subjectId.toString();
      }

      String endpoint = '';
      String fileExt = _format == 'excel' ? 'xlsx' : _format;
      String mimeType = _format == 'pdf'
          ? 'application/pdf'
          : (_format == 'excel'
              ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
              : 'text/csv');

      if (isOverall) {
        endpoint = '/reports/overall-attendance';
      } else {
        endpoint = '/reports/attendance/$_format';
      }

      // Query raw binary bytes
      final response = await dio.get<List<int>>(
        endpoint,
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        // Save file to temporary directory
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filename = isOverall 
            ? 'overall_attendance_$timestamp.$fileExt'
            : 'attendance_logs_$timestamp.$fileExt';
        final file = File('${tempDir.path}/$filename');
        
        await file.writeAsBytes(response.data!);

        // Dispatch to system share menu
        await Share.shareXFiles(
          [XFile(file.path, mimeType: mimeType)],
          text: isOverall ? 'Overall Student Attendance Report' : 'Classroom Attendance Logs',
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = "Failed to export report: ${e.toString()}";
        if (e is DioException && e.response?.data != null) {
          try {
            msg = e.response.toString();
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsState = ref.watch(subjectListProvider);
    
    // Prepare filters payload
    final filters = {
      'department': _department,
      'year': _year,
      'section': _section,
      'subject_id': _subjectId,
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
    };

    final overallState = ref.watch(overallAttendanceProvider(filters));

    return Scaffold(
      appBar: AppBar(
        title: const Text("System Reports", style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.document_scanner_rounded), text: "Export Formats"),
            Tab(icon: Icon(Icons.table_chart_rounded), text: "Overall Attendance"),
          ],
        ),
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Compiling report logs and drawing documents...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Column(
              children: [
                // 1. COLLAPSIBLE SHARED FILTERS CARD
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: const Text("Report Query Filters", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    leading: const Icon(Icons.filter_list_rounded, color: Color(0xFF1B365D)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: subjectsState.when(
                                      loading: () => const Center(child: CircularProgressIndicator()),
                                      error: (e, s) => Text("Error: $e"),
                                      data: (list) {
                                        return DropdownButtonFormField<int?>(
                                          initialValue: _subjectId,
                                          style: const TextStyle(color: Colors.black87),
                                          decoration: const InputDecoration(labelText: "Course"),
                                          items: [
                                            const DropdownMenuItem(value: null, child: Text("All Courses", style: TextStyle(color: Colors.black87))),
                                            ...list.map((s) => DropdownMenuItem(value: s.id, child: Text("${s.code} - ${s.name}", style: const TextStyle(color: Colors.black87)))),
                                          ],
                                          onChanged: (val) => setState(() => _subjectId = val),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String?>(
                                      initialValue: _department,
                                      style: const TextStyle(color: Colors.black87),
                                      decoration: const InputDecoration(labelText: "Dept"),
                                      items: const [
                                        DropdownMenuItem(value: null, child: Text("All Depts", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: "Computer Science", child: Text("CSE", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: "Electrical Engineering", child: Text("EE", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: "Mechanical Engineering", child: Text("ME", style: TextStyle(color: Colors.black87))),
                                      ],
                                      onChanged: (val) => setState(() => _department = val),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int?>(
                                      initialValue: _year,
                                      style: const TextStyle(color: Colors.black87),
                                      decoration: const InputDecoration(labelText: "Year"),
                                      items: const [
                                        DropdownMenuItem(value: null, child: Text("All Years", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: 1, child: Text("Year 1", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: 2, child: Text("Year 2", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: 3, child: Text("Year 3", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: 4, child: Text("Year 4", style: TextStyle(color: Colors.black87))),
                                      ],
                                      onChanged: (val) => setState(() => _year = val),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String?>(
                                      initialValue: _section,
                                      style: const TextStyle(color: Colors.black87),
                                      decoration: const InputDecoration(labelText: "Section"),
                                      items: const [
                                        DropdownMenuItem(value: null, child: Text("All Secs", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: "A", child: Text("Sec A", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: "B", child: Text("Sec B", style: TextStyle(color: Colors.black87))),
                                        DropdownMenuItem(value: "C", child: Text("Sec C", style: TextStyle(color: Colors.black87))),
                                      ],
                                      onChanged: (val) => setState(() => _section = val),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton.icon(
                                    onPressed: _pickStartDate,
                                    icon: const Icon(Icons.date_range_rounded),
                                    label: Text("Start: ${DateFormat('yyyy-MM-dd').format(_startDate)}"),
                                  ),
                                  TextButton.icon(
                                    onPressed: _pickEndDate,
                                    icon: const Icon(Icons.date_range_rounded),
                                    label: Text("End: ${DateFormat('yyyy-MM-dd').format(_endDate)}"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. TABBED CONTENTS
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB A: EXPORT CONFIG
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Configure file attachments and share options:", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _format,
                              style: const TextStyle(color: Colors.black87),
                              decoration: const InputDecoration(
                                labelText: "Download Format",
                                prefixIcon: Icon(Icons.file_copy_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'pdf', child: Text("PDF Report Document (.pdf)", style: TextStyle(color: Colors.black87))),
                                DropdownMenuItem(value: 'excel', child: Text("Excel Spreadsheet Workbook (.xlsx)", style: TextStyle(color: Colors.black87))),
                                DropdownMenuItem(value: 'csv', child: Text("Comma Separated Values Sheet (.csv)", style: TextStyle(color: Colors.black87))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _format = val);
                              },
                            ),
                            const SizedBox(height: 48),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                              icon: const Icon(Icons.share_rounded),
                              label: const Text("Export Attendance Logs"),
                              onPressed: () => _generateReport(false),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                              icon: const Icon(Icons.group_work_rounded),
                              label: const Text("Export Overall Student Report"),
                              onPressed: () => _generateReport(true),
                            ),
                          ],
                        ),
                      ),

                      // TAB B: OVERALL ATTENDANCE TABLE VIEW
                      Column(
                        children: [
                          // Search Box
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "Search students by name or roll number...",
                                prefixIcon: Icon(Icons.search_rounded),
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                            ),
                          ),
                          
                          // DataTable View
                          Expanded(
                            child: overallState.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, s) => Center(child: Text("Error fetching report data: $e")),
                              data: (list) {
                                // 1. Filter local search query
                                var filtered = list.where((item) {
                                  return item.fullName.toLowerCase().contains(_searchQuery) ||
                                      item.rollNumber.toLowerCase().contains(_searchQuery);
                                }).toList();

                                // 2. Perform sorting
                                filtered.sort((a, b) {
                                  int cmp = 0;
                                  if (_sortColumn == 'rollNumber') {
                                    cmp = a.rollNumber.compareTo(b.rollNumber);
                                  } else if (_sortColumn == 'fullName') {
                                    cmp = a.fullName.compareTo(b.fullName);
                                  } else if (_sortColumn == 'percent') {
                                    cmp = a.attendancePercent.compareTo(b.attendancePercent);
                                  } else if (_sortColumn == 'risk') {
                                    cmp = a.riskStatus.compareTo(b.riskStatus);
                                  }
                                  return _sortAscending ? cmp : -cmp;
                                });

                                if (filtered.isEmpty) {
                                  return const Center(child: Text("No student logs match query."));
                                }

                                return SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      sortColumnIndex: _sortColumn == 'rollNumber' ? 0 : (_sortColumn == 'fullName' ? 1 : 2),
                                      sortAscending: _sortAscending,
                                      columns: [
                                        DataColumn(
                                          label: const Text("Roll No"),
                                          onSort: (colIndex, ascending) {
                                            setState(() {
                                              _sortColumn = 'rollNumber';
                                              _sortAscending = ascending;
                                            });
                                          },
                                        ),
                                        DataColumn(
                                          label: const Text("Name"),
                                          onSort: (colIndex, ascending) {
                                            setState(() {
                                              _sortColumn = 'fullName';
                                              _sortAscending = ascending;
                                            });
                                          },
                                        ),
                                        DataColumn(label: const Text("Dept")),
                                        DataColumn(label: const Text("Sec")),
                                        DataColumn(label: const Text("Total")),
                                        DataColumn(label: const Text("Attended")),
                                        DataColumn(
                                          label: const Text("%"),
                                          onSort: (colIndex, ascending) {
                                            setState(() {
                                              _sortColumn = 'percent';
                                              _sortAscending = ascending;
                                            });
                                          },
                                        ),
                                        DataColumn(
                                          label: const Text("Risk"),
                                          onSort: (colIndex, ascending) {
                                            setState(() {
                                              _sortColumn = 'risk';
                                              _sortAscending = ascending;
                                            });
                                          },
                                        ),
                                      ],
                                      rows: filtered.map((item) {
                                        Color riskColor = Colors.grey;
                                        if (item.riskStatus == 'SAFE') {
                                          riskColor = Colors.green;
                                        } else if (item.riskStatus == 'WARNING') {
                                          riskColor = Colors.orange;
                                        } else if (item.riskStatus == 'CRITICAL') {
                                          riskColor = Colors.red;
                                        }

                                        return DataRow(
                                          cells: [
                                            DataCell(Text(item.rollNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataCell(Text(item.fullName)),
                                            DataCell(Text(item.department.substring(0, 3).toUpperCase())),
                                            DataCell(Text("${item.year}${item.section}")),
                                            DataCell(Text("${item.totalSessions}")),
                                            DataCell(Text("${item.attendedSessions}")),
                                            DataCell(Text(
                                              "${item.attendancePercent.toStringAsFixed(1)}%",
                                              style: TextStyle(
                                                color: item.attendancePercent < 75.0 ? Colors.red : Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: riskColor.withAlpha(26),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: riskColor.withAlpha(102)),
                                                ),
                                                child: Text(
                                                  item.riskStatus,
                                                  style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
