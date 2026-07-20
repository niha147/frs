import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_frs/data/models/subject_model.dart';

class ClassForm extends StatefulWidget {
  final List<SubjectModel> subjectList;
  const ClassForm({super.key, required this.subjectList});

  @override
  State<ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<ClassForm> {
  final _formKey = GlobalKey<FormState>();
  int? _subjectId;
  late final TextEditingController _classroomController;
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  bool _enableGeofence = false;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    _classroomController = TextEditingController(text: 'Room 301');
    _latController = TextEditingController(text: '12.9716');
    _lonController = TextEditingController(text: '77.5946');
    _radiusController = TextEditingController(text: '50.0');
    if (widget.subjectList.isNotEmpty) {
      _subjectId = widget.subjectList.first.id;
    }
  }

  @override
  void dispose() {
    _classroomController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _save() {
    if (_formKey.currentState!.validate() && _subjectId != null) {
      final startDt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      final endDt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );
      
      if (endDt.isBefore(startDt)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("End time must be after start time."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.of(context).pop({
        'subject_id': _subjectId,
        'classroom': _classroomController.text.trim(),
        'scheduled_start': startDt.toIso8601String(),
        'scheduled_end': endDt.toIso8601String(),
        if (_enableGeofence) 'latitude': double.tryParse(_latController.text.trim()),
        if (_enableGeofence) 'longitude': double.tryParse(_lonController.text.trim()),
        if (_enableGeofence) 'radius_meters': double.tryParse(_radiusController.text.trim()) ?? 50.0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Schedule Session"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _subjectId,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Course / Subject"),
                items: widget.subjectList.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text("${s.code} — ${s.name}", style: const TextStyle(color: Colors.black87)),
                  ),
                ).toList(),
                onChanged: (v) => setState(() => _subjectId = v),
                validator: (v) => v == null ? "Course is required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _classroomController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Classroom / Room"),
                validator: (v) => v == null || v.isEmpty ? "Classroom is required" : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("GPS Geofencing", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text("Enforce classroom location boundary for self-scan", style: TextStyle(fontSize: 11)),
                value: _enableGeofence,
                onChanged: (val) => setState(() => _enableGeofence = val),
              ),
              if (_enableGeofence) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(labelText: "Latitude"),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _lonController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(labelText: "Longitude"),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _radiusController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(labelText: "Radius (meters)", hintText: "50.0"),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 16),
              // Pick Date Action
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text("Session Date"),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _pickDate,
              ),
              const Divider(),
              // Pick Start Time Action
              ListTile(
                leading: const Icon(Icons.access_time_rounded),
                title: const Text("Start Time"),
                subtitle: Text(_startTime.format(context)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _pickStartTime,
              ),
              const Divider(),
              // Pick End Time Action
              ListTile(
                leading: const Icon(Icons.access_time_rounded),
                title: const Text("End Time"),
                subtitle: Text(_endTime.format(context)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _pickEndTime,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text("Schedule"),
        ),
      ],
    );
  }
}
