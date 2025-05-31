import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For trainerId
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Define a simple Question model (you might want a more complex one)
class Question {
  String id;
  String text;
  String type; // e.g., 'multiple-choice', 'fill-in-the-blank'
  List<String>? options; // For multiple-choice
  List<String>? correctAnswers; // Can be single or multiple
  int points;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    this.correctAnswers,
    this.points = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'options': options,
      'correctAnswers': correctAnswers,
      'points': points,
    };
  }
}


class CreateAssessmentPage extends StatefulWidget {
  final String? classId; // Can be null if creating a general assessment
  const CreateAssessmentPage({this.classId, Key? key, String? initialClassId}) : super(key: key);

  @override
  State<CreateAssessmentPage> createState() => _CreateAssessmentPageState();
}

class _CreateAssessmentPageState extends State<CreateAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedClassId; 
  List<Map<String, dynamic>> _trainerClasses = []; 

  List<Question> _questions = [];
  bool _isLoading = false;
  String? _error;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  // ThemeData? _theme;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.classId;
    if (widget.classId == null) {
      _fetchTrainerClasses();
    }
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _theme = Theme.of(context);
  // }

  Future<void> _fetchTrainerClasses() async {
    // TODO: Implement if you need a dropdown to select a class
    // For now, assumes classId is provided or assessment is not class-specific initially
    if (currentUser == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('trainerId', isEqualTo: currentUser!.uid)
          .get();
      setState(() {
        _trainerClasses = snapshot.docs.map((doc) => {'id': doc.id, 'name': doc.data()['className'] ?? 'Unnamed Class'}).toList();
        if (_trainerClasses.isNotEmpty && _selectedClassId == null) {
          // _selectedClassId = _trainerClasses.first['id']; // Optionally pre-select
        }
      });
    } catch (e) {
      // Handle error
    }
  }


  void _addQuestion() {
    // TODO: Implement a more sophisticated way to add questions (e.g., a dialog or separate page)
    // For now, adding a placeholder question
    setState(() {
      _questions.add(Question(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'New Question ${_questions.length + 1}',
        type: 'multiple-choice', // Default type
        options: ['Option A', 'Option B'],
        correctAnswers: ['Option A'],
        points: 10
      ));
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _saveAssessment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null && widget.classId == null) {
        setState(() => _error = "Please select a class for this assessment.");
        return;
    }
    if (_questions.isEmpty) {
        setState(() => _error = "Please add at least one question.");
        return;
    }


    setState(() { _isLoading = true; _error = null; });

    try {
      if (currentUser == null) {
        throw Exception("User not logged in.");
      }

      final assessmentData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'classId': _selectedClassId ?? widget.classId, // Use the selected or provided classId
        'trainerId': currentUser!.uid,
        'questions': _questions.map((q) => q.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Add other fields like 'deadline', 'totalPoints', etc.
      };

      await FirebaseFirestore.instance.collection('assessments').add(assessmentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessment created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Pop and indicate success
      }
    } catch (e) {
      setState(() { _error = "Failed to save assessment: ${e.toString()}"; });
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Create New Assessment'),
        backgroundColor: theme.colorScheme.surfaceVariant,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            onPressed: _isLoading ? null : _saveAssessment,
            tooltip: "Save Assessment",
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.dividerColor,
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(FontAwesomeIcons.triangleExclamation, color: theme.colorScheme.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                      ],
                    ),
                  ),
                ),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Assessment Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(FontAwesomeIcons.fileSignature, color: theme.colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(FontAwesomeIcons.alignLeft, color: theme.colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              if (widget.classId == null) ...[
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Class',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: Icon(FontAwesomeIcons.chalkboardUser, color: theme.colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  value: _selectedClassId,
                  items: _trainerClasses.map((cls) {
                    return DropdownMenuItem<String>(
                      value: cls['id'] as String,
                      child: Text(cls['name'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClassId = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a class' : null,
                ),
                const SizedBox(height: 16),
              ],


              const Divider(height: 32, thickness: 1, color: Colors.grey),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Questions', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onBackground)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Question'),
                    onPressed: _addQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_questions.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("No questions added yet.", style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))),
                )),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final question = _questions[index];
                  return Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: theme.colorScheme.surface,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text("${index + 1}", style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(question.text, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurface)),
                      subtitle: Text('${question.type} - ${question.points} pts', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error.withOpacity(0.8)),
                        onPressed: () => _removeQuestion(index),
                        tooltip: "Remove question",
                      ),
                      // TODO: Add onTap to edit question
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: _isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary)) : const Icon(Icons.save_alt_outlined),
                label: Text(_isLoading ? 'Saving...' : 'Save Assessment'),
                onPressed: _isLoading ? null : _saveAssessment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
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