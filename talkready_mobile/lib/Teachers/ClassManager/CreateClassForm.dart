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
  // ThemeData? _theme;

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _theme = Theme.of(context);
  // }

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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Create New Class'),
        backgroundColor: theme.colorScheme.surfaceVariant,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.dividerColor,
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(error!, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 14))),
                    ],
                  ),
                ),
              if (success != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100, // Consider theme.colorScheme.primaryContainer or secondaryContainer
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(success!, style: TextStyle(color: Colors.green.shade800, fontSize: 14))),
                    ],
                  ),
                ),
              TextFormField(
                controller: _classNameController,
                decoration: InputDecoration(
                  labelText: 'Class Name *',
                  prefixIcon: Icon(Icons.class_, color: theme.colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Class Name is required.' : null,
                enabled: !loading,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Class Description (Optional)',
                  prefixIcon: Icon(Icons.description, color: theme.colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                maxLines: 3,
                enabled: !loading,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject / Focus (Optional)',
                  prefixIcon: Icon(Icons.label_outline, color: theme.colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                enabled: !loading,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                        )
                      : const Icon(Icons.add_circle_outline, size: 20),
                  label: Text(loading ? 'Creating Class...' : 'Create Class'),
                  onPressed: loading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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