import 'package:flutter/material.dart';
import 'package:smart_frs/data/models/faculty_model.dart';

class FacultyForm extends StatefulWidget {
  final FacultyModel? faculty;
  const FacultyForm({super.key, this.faculty});

  @override
  State<FacultyForm> createState() => _FacultyFormState();
}

class _FacultyFormState extends State<FacultyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _deptController;
  late final TextEditingController _passController;
  late String _role;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.faculty?.name ?? '');
    _emailController = TextEditingController(text: widget.faculty?.email ?? '');
    _phoneController = TextEditingController(text: widget.faculty?.phone ?? '');
    _deptController = TextEditingController(text: widget.faculty?.department ?? 'Computer Science');
    _passController = TextEditingController();
    _role = widget.faculty?.role ?? 'faculty';
    _isActive = widget.faculty?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text.trim();
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'department': _deptController.text.trim().isNotEmpty
            ? _deptController.text.trim()
            : 'General',
        'role': _role,
        if (phone.isNotEmpty) 'phone': phone,
      };

      if (widget.faculty == null) {
        // Creating new faculty — send password, no is_active
        data['password'] = _passController.text;
      } else {
        // Updating existing faculty — send is_active toggle
        data['is_active'] = _isActive;
        if (_passController.text.isNotEmpty) {
          data['password'] = _passController.text;
        }
      }

      Navigator.of(context).pop(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.faculty == null ? "Add Faculty" : "Edit Faculty"),
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
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Email Address"),
                validator: (v) => v == null || v.isEmpty ? "Email is required" : null,
              ),
              const SizedBox(height: 12),
              if (widget.faculty == null) ...[
                TextFormField(
                  controller: _passController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(labelText: "Password"),
                  validator: (v) => v == null || v.length < 6 ? "Password must be at least 6 chars" : null,
                ),
                const SizedBox(height: 12),
              ],
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
              DropdownButtonFormField<String>(
                initialValue: _role,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: "Role"),
                items: const [
                  DropdownMenuItem(value: 'faculty', child: Text("Faculty", style: TextStyle(color: Colors.black87))),
                  DropdownMenuItem(value: 'admin', child: Text("Administrator", style: TextStyle(color: Colors.black87))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _role = v);
                },
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
