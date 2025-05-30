import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateClassForm extends StatefulWidget {
  const CreateClassForm({Key? key}) : super(key: key);

  @override
  State<CreateClassForm> createState() => _CreateClassFormState();
}

class _CreateClassFormState extends State<CreateClassForm> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();

  bool loading = false;
  String? error;
  String? success;

  Future<void> _handleSubmit() async {
    setState(() {
      error = null;
      success = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => error = "You must be logged in to create a class.");
      return;
    }

    setState(() => loading = true);

    try {
      final classData = {
        'className': _classNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'subject': _subjectController.text.trim(),
        'trainerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      final docRef = await FirebaseFirestore.instance.collection('classes').add(classData);
      setState(() {
        success = 'Class "${_classNameController.text.trim()}" created successfully!';
        _classNameController.clear();
        _descriptionController.clear();
        _subjectController.clear();
      });
      // Optionally: Navigator.pop(context); or navigate to class list/dashboard
    } catch (e) {
      setState(() => error = "Failed to create class. Please try again.");
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Class'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              if (success != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(success!, style: const TextStyle(color: Colors.green)),
                ),
              TextFormField(
                controller: _classNameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name *',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Class Name is required.' : null,
                enabled: !loading,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Class Description (Optional)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !loading,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject / Focus (Optional)',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(),
                ),
                enabled: !loading,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(loading ? 'Creating Class...' : 'Create Class'),
                  onPressed: loading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}