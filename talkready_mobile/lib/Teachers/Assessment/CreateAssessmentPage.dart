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

  String? _selectedClassId; // If classId is not passed, user might select one
  List<Map<String, dynamic>> _trainerClasses = []; // For dropdown if classId is null

  List<Question> _questions = [];
  bool _isLoading = false;
  String? _error;
  final User? currentUser = FirebaseAuth.instance.currentUser;


  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.classId;
    if (widget.classId == null) {
      _fetchTrainerClasses();
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Assessment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveAssessment,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
                ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Assessment Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(FontAwesomeIcons.fileSignature),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(FontAwesomeIcons.alignLeft)
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Class Selector (if classId not provided via widget)
              if (widget.classId == null) ...[
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Class',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(FontAwesomeIcons.chalkboardUser),
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


              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Question'),
                    onPressed: _addQuestion,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_questions.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No questions added yet.", style: TextStyle(color: Colors.grey)),
                )),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final question = _questions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(child: Text("${index + 1}")),
                      title: Text(question.text, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${question.type} - ${question.points} pts'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                        onPressed: () => _removeQuestion(index),
                      ),
                      // TODO: Add onTap to edit question
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt_outlined),
                label: Text(_isLoading ? 'Saving...' : 'Save Assessment'),
                onPressed: _isLoading ? null : _saveAssessment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}