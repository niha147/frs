import 'package:flutter/material.dart';
import 'package:smart_frs/data/models/faculty_model.dart';
import 'package:smart_frs/data/models/subject_model.dart';

class SubjectForm extends StatefulWidget {
  final SubjectModel? subject;
  final List<FacultyModel> facultyList;
  const SubjectForm({super.key, this.subject, required this.facultyList});

  @override
  State<SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends State<SubjectForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _deptController;
  late final TextEditingController _sectionController;
  late int _year;
  String? _facultyId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject?.name ?? '');
    _codeController = TextEditingController(text: widget.subject?.code ?? '');
    _deptController = TextEditingController(text: widget.subject?.department ?? 'Computer Science');
    _sectionController = TextEditingController(text: widget.subject?.section ?? 'A');
    _year = widget.subject?.year ?? 1;
    
    // Check if faculty exists in the passed list
    if (widget.subject?.facultyId != null) {
      final exists = widget.facultyList.any((f) => f.id == widget.subject!.facultyId);
      if (exists) {
        _facultyId = widget.subject!.facultyId;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _deptController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().toUpperCase(),
        'department': _deptController.text.trim(),
        'year': _year,
        'section': _sectionController.text.trim().toUpperCase(),
        'faculty_id': _facultyId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.subject == null ? "Add Course" : "Edit Course"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Course Name"),
                validator: (v) => v == null || v.isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Course Code"),
                validator: (v) => v == null || v.isEmpty ? "Code is required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deptController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Department"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _year,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Year"),
                items: List.generate(4, (i) => i + 1)
                    .map((y) => DropdownMenuItem(value: y, child: Text("Year $y", style: const TextStyle(color: Colors.black87))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _year = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sectionController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Section"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _facultyId,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Assigned Instructor"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("None (Unassigned)", style: TextStyle(color: Colors.black87)),
                  ),
                  ...widget.facultyList.map(
                    (f) => DropdownMenuItem<String?>(
                      value: f.id,
                      child: Text(f.name, style: const TextStyle(color: Colors.black87)),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _facultyId = v),
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
          child: const Text("Save"),
        ),
      ],
    );
  }
}
