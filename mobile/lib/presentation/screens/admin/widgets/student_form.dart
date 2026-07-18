import 'package:flutter/material.dart';
import 'package:smart_frs/data/models/student_model.dart';

class StudentForm extends StatefulWidget {
  final StudentModel? student;
  const StudentForm({super.key, this.student});

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _rollController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _deptController;
  late final TextEditingController _sectionController;
  late int _year;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student?.name ?? '');
    _rollController = TextEditingController(text: widget.student?.rollNumber ?? '');
    _emailController = TextEditingController(text: widget.student?.email ?? '');
    _phoneController = TextEditingController(text: widget.student?.phone ?? '');
    _deptController = TextEditingController(text: widget.student?.department ?? 'Computer Science');
    _sectionController = TextEditingController(text: widget.student?.section ?? 'A');
    _year = widget.student?.year ?? 1;
    _isActive = widget.student?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'roll_number': _rollController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _deptController.text.trim(),
        'year': _year,
        'section': _sectionController.text.trim().toUpperCase(),
        'is_active': _isActive,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.student == null ? "Add Student" : "Edit Student"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Full Name"),
                validator: (v) => v == null || v.isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rollController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Roll Number"),
                validator: (v) => v == null || v.isEmpty ? "Roll Number is required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Email Address"),
                validator: (v) => v == null || v.isEmpty ? "Email is required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Phone Number"),
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
              SwitchListTile(
                title: const Text("Is Active"),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
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
