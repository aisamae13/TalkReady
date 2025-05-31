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

  // Use TextEditingControllers for better control and to set initial values
  final _classNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();

  // String _className = ''; // Replaced by controller
  // String _description = ''; // Replaced by controller
  // String _subject = ''; // Replaced by controller

  bool _initialLoading = true;
  bool _isUpdating = false;
  String? _error;
  String? _success;
  // ThemeData? _theme;

  @override
  void initState() {
    super.initState();
    _fetchClassData();
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _theme = Theme.of(context);
  // }

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
        // _className = details['className'] as String? ?? '';
        // _description = details['description'] as String? ?? '';
        // _subject = details['subject'] as String? ?? '';
        _classNameController.text = details['className'] as String? ?? '';
        _descriptionController.text = details['description'] as String? ?? '';
        _subjectController.text = details['subject'] as String? ?? '';
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
      // _formKey.currentState!.save(); // Not needed when using controllers

      setState(() {
        _isUpdating = true;
        _error = null;
        _success = null;
      });

      final updatedData = {
        'className': _classNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'subject': _subjectController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        await updateTrainerClass(widget.classId, updatedData);
        setState(() {
          _success = 'Class "${_classNameController.text}" updated successfully!';
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
    final theme = Theme.of(context);

    if (_initialLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Edit Class"),
          backgroundColor: theme.colorScheme.surfaceVariant,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary))),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(_classNameController.text.isNotEmpty ? "Edit: ${_classNameController.text}" : "Edit Class", overflow: TextOverflow.ellipsis),
        backgroundColor: theme.colorScheme.surfaceVariant,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.dividerColor,
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                    ]),
                  )
                ),
              if (_success != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_success!, style: TextStyle(color: Colors.green.shade800))),
                    ]),
                  )
                ),
              TextFormField(
                // initialValue: _className, // Controller handles initial value
                controller: _classNameController,
                decoration: InputDecoration(
                  labelText: 'Class Name',
                  prefixIcon: Icon(FontAwesomeIcons.chalkboardUser, color: theme.colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a class name.';
                  }
                  return null;
                },
                // onSaved: (value) => _className = value!, // Not needed with controller
                enabled: !_isUpdating,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                // initialValue: _description, // Controller handles initial value
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(FontAwesomeIcons.alignLeft, color: theme.colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                maxLines: 3,
                // onSaved: (value) => _description = value ?? '', // Not needed with controller
                enabled: !_isUpdating,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                // initialValue: _subject, // Controller handles initial value
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject/Category (Optional)',
                  prefixIcon: Icon(FontAwesomeIcons.tag, color: theme.colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                // onSaved: (value) => _subject = value ?? '', // Not needed with controller
                enabled: !_isUpdating,
              ),
              const SizedBox(height: 28.0),
              _isUpdating
                  ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)))
                  : ElevatedButton.icon(
                      icon: const Icon(FontAwesomeIcons.save, size: 16),
                      label: const Text('Save Changes'),
                      onPressed: _handleUpdateClass,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}