import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Assumed Firebase Service functions (implement these)
Future<Map<String, dynamic>> getClassDetails(String classId) async {
  final doc = await FirebaseFirestore.instance.collection('classes').doc(classId).get();
  if (!doc.exists) throw Exception("Class not found");
  return {'id': doc.id, ...doc.data()!};
}

Future<void> updateTrainerClass(String classId, Map<String, dynamic> data) async {
  await FirebaseFirestore.instance.collection('classes').doc(classId).update(data);
}

class EditClassPage extends StatefulWidget {
  final String classId;

  const EditClassPage({Key? key, required this.classId}) : super(key: key);

  @override
  _EditClassPageState createState() => _EditClassPageState();
}

class _EditClassPageState extends State<EditClassPage> {
  final _formKey = GlobalKey<FormState>();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _className = '';
  String _description = '';
  String _subject = '';

  bool _initialLoading = true;
  bool _isUpdating = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _fetchClassData();
  }

  Future<void> _fetchClassData() async {
    if (_currentUser == null) {
      setState(() {
        _error = "Authentication required.";
        _initialLoading = false;
      });
      return;
    }
    setState(() {
      _initialLoading = true;
      _error = null;
      _success = null;
    });
    try {
      final details = await getClassDetails(widget.classId);
      if (details['trainerId'] != _currentUser!.uid) {
        setState(() {
          _error = "You are not authorized to edit this class.";
          _initialLoading = false;
        });
        // Optionally navigate away
        // Future.delayed(const Duration(seconds: 3), () {
        //   if (mounted) Navigator.pop(context);
        // });
        return;
      }
      setState(() {
        _className = details['className'] as String? ?? '';
        _description = details['description'] as String? ?? '';
        _subject = details['subject'] as String? ?? '';
        _initialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load class details: ${e.toString()}";
        _initialLoading = false;
      });
    }
  }

  Future<void> _handleUpdateClass() async {
    if (_currentUser == null) {
      setState(() => _error = "Authentication error. Please log in again.");
      return;
    }
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isUpdating = true;
        _error = null;
        _success = null;
      });

      final updatedData = {
        'className': _className.trim(),
        'description': _description.trim(),
        'subject': _subject.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        await updateTrainerClass(widget.classId, updatedData);
        setState(() {
          _success = 'Class "$_className" updated successfully!';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // Navigate back or to class dashboard
            Navigator.pop(context, true); // Pop with a result to indicate success
          }
        });
      } catch (e) {
        setState(() {
          _error = 'Failed to update class: ${e.toString()}';
        });
      } finally {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Edit Class")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_className.isNotEmpty ? "Edit: $_className" : "Edit Class"),
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (_success != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(_success!, style: TextStyle(color: Colors.green[700])),
                ),
              TextFormField(
                initialValue: _className,
                decoration: const InputDecoration(
                  labelText: 'Class Name',
                  prefixIcon: Icon(FontAwesomeIcons.chalkboardUser),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a class name.';
                  }
                  return null;
                },
                onSaved: (value) => _className = value!,
                enabled: !_isUpdating,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(FontAwesomeIcons.alignLeft),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onSaved: (value) => _description = value ?? '',
                enabled: !_isUpdating,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                initialValue: _subject,
                decoration: const InputDecoration(
                  labelText: 'Subject/Category (Optional)',
                  prefixIcon: Icon(FontAwesomeIcons.tag),
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _subject = value ?? '',
                enabled: !_isUpdating,
              ),
              const SizedBox(height: 24.0),
              _isUpdating
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(FontAwesomeIcons.save),
                      label: const Text('Save Changes'),
                      onPressed: _handleUpdateClass,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}