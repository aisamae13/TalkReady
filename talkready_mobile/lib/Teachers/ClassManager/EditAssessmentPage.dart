import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting

// --- Models (Simplified - reuse or define as in CreateAssessmentPage) ---
// Assuming QuestionType, AssessmentQuestion, Option, TrainerClass models are defined
// (e.g., in a shared models file or copied from CreateAssessmentPage.dart)
// For brevity, I'm omitting them here but they are crucial.
// Ensure they match the structure used in CreateAssessmentPage.dart

// --- Placeholder Firebase Service Functions (reuse or define as in CreateAssessmentPage) ---
// getTrainerClasses, uploadAssessmentMediaFile, deleteAssessmentMediaFile
// And new ones:
Future<Map<String, dynamic>> getAssessmentDetailsFromService(String assessmentId) async {
  final doc = await FirebaseFirestore.instance.collection('assessments').doc(assessmentId).get();
  if (!doc.exists) throw Exception("Assessment not found");
  return {'id': doc.id, ...doc.data()!};
}

Future<void> updateTrainerAssessmentInService(String assessmentId, Map<String, dynamic> assessmentData) async {
  await FirebaseFirestore.instance.collection('assessments').doc(assessmentId).update(assessmentData);
}

// deleteTrainerAssessmentFromService (from ClassAssessmentsListPage.dart)
Future<void> deleteTrainerAssessmentFromService(String assessmentId) async {
  await FirebaseFirestore.instance.collection('assessments').doc(assessmentId).delete();
}

// --- Re-use models from CreateAssessmentPage.dart ---
enum QuestionType { multipleChoice, fillInTheBlanks }

class AssessmentQuestion {
  String id;
  QuestionType type;
  String questionText;
  List<Option> options;
  List<String> correctOptionIds;
  String scenarioTextFITB;
  String textBeforeBlankFITB;
  String textAfterBlankFITB;
  List<String> correctAnswersFITB;
  String fitbAnswerMode;
  List<Option> fitbOptions;
  String fitbCorrectOptionId;
  int points;
  String? imageUrl;
  String? imagePath; // Storage path for the image
  File? localImageFile; // For new/updated image before upload

  AssessmentQuestion({
    required this.id,
    required this.type,
    this.questionText = '',
    this.options = const [],
    this.correctOptionIds = const [],
    this.scenarioTextFITB = '',
    this.textBeforeBlankFITB = '',
    this.textAfterBlankFITB = '',
    this.correctAnswersFITB = const [],
    this.fitbAnswerMode = 'typing', // 'typing' or 'options'
    this.fitbOptions = const [],
    this.fitbCorrectOptionId = '',
    this.points = 10,
    this.imageUrl,
    this.imagePath,
    this.localImageFile,
  });

  // Add toJson and fromJson/fromMap if needed for complex state or direct Firestore mapping
   Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString().split('.').last,
        'questionText': questionText,
        'points': points,
        'imageUrl': imageUrl,
        'imagePath': imagePath,
        // MCQ specific
        'options': options.map((opt) => opt.toJson()).toList(),
        'correctOptionIds': correctOptionIds,
        // FITB specific
        'scenarioTextFITB': scenarioTextFITB,
        'textBeforeBlankFITB': textBeforeBlankFITB,
        'textAfterBlankFITB': textAfterBlankFITB,
        'correctAnswersFITB': correctAnswersFITB,
        'fitbAnswerMode': fitbAnswerMode,
        'fitbOptions': fitbOptions.map((opt) => opt.toJson()).toList(),
        'fitbCorrectOptionId': fitbCorrectOptionId,
      };

  factory AssessmentQuestion.fromMap(Map<String, dynamic> map) {
    return AssessmentQuestion(
      id: map['id'],
      type: QuestionType.values.firstWhere((e) => e.toString().split('.').last == map['type'], orElse: () => QuestionType.multipleChoice),
      questionText: map['questionText'] ?? '',
      points: map['points'] ?? 10,
      imageUrl: map['imageUrl'],
      imagePath: map['imagePath'],
      options: (map['options'] as List<dynamic>?)?.map((optMap) => Option.fromMap(optMap)).toList() ?? [],
      correctOptionIds: List<String>.from(map['correctOptionIds'] ?? []),
      scenarioTextFITB: map['scenarioTextFITB'] ?? '',
      textBeforeBlankFITB: map['textBeforeBlankFITB'] ?? '',
      textAfterBlankFITB: map['textAfterBlankFITB'] ?? '',
      correctAnswersFITB: List<String>.from(map['correctAnswersFITB'] ?? []),
      fitbAnswerMode: map['fitbAnswerMode'] ?? 'typing',
      fitbOptions: (map['fitbOptions'] as List<dynamic>?)?.map((optMap) => Option.fromMap(optMap)).toList() ?? [],
      fitbCorrectOptionId: map['fitbCorrectOptionId'] ?? '',
    );
  }
}

class Option {
  String optionId;
  String text;
  Option({required this.optionId, required this.text});

  Map<String, dynamic> toJson() => {'optionId': optionId, 'text': text};
  factory Option.fromMap(Map<String, dynamic> map) => Option(optionId: map['optionId'], text: map['text']);
}

class TrainerClass { // From CreateAssessmentPage
  final String id;
  final String className;
  TrainerClass({required this.id, required this.className});
}
// --- End of Re-used models ---


class EditAssessmentPage extends StatefulWidget {
  final String assessmentId;

  const EditAssessmentPage({Key? key, required this.assessmentId}) : super(key: key);

  @override
  _EditAssessmentPageState createState() => _EditAssessmentPageState();
}

class _EditAssessmentPageState extends State<EditAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // --- State Variables (similar to CreateAssessmentPage) ---
  String _title = '';
  String _description = '';
  String? _selectedClassId;
  String? _originalClassId; // To track if class assignment changes
  List<TrainerClass> _trainerClasses = [];
  List<AssessmentQuestion> _questions = [];
  DateTime? _deadline;

  // Assessment Header Image
  File? _assessmentHeaderImageFile; // New local file
  String? _assessmentHeaderImageUrl; // Existing or new URL
  String? _assessmentHeaderImagePath; // Existing or new storage path
  bool _isUploadingHeaderImage = false;
  String? _headerImageUploadError;

  // Question Form (Simplified for brevity - this would be complex)
  // bool _showQuestionForm = false;
  // QuestionType _currentQuestionType = QuestionType.multipleChoice;
  // ... (state for current question being edited/created)

  bool _pageLoading = true;
  bool _isUpdating = false;
  String? _error;
  String? _success;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (_currentUser == null) {
      setState(() { _error = "Authentication required."; _pageLoading = false; });
      return;
    }
    setState(() { _pageLoading = true; _error = null; _success = null; });

    try {
      // Fetch trainer classes (reuse from CreateAssessmentPage or define)
      // final classes = await getTrainerClasses(_currentUser!.uid);
      // For now, mock or assume fetched:
      _trainerClasses = [TrainerClass(id: "class1_dummy", className: "Dummy Class 1 (Edit Page)")];


      final assessmentData = await getAssessmentDetailsFromService(widget.assessmentId);
      if (assessmentData['trainerId'] != _currentUser!.uid) {
         setState(() { _error = "You are not authorized to edit this assessment."; _pageLoading = false; });
         return;
      }

      setState(() {
        _title = assessmentData['title'] ?? '';
        _description = assessmentData['description'] ?? '';
        _selectedClassId = assessmentData['classId'];
        _originalClassId = assessmentData['classId'];
        if (assessmentData['deadline'] != null) {
          _deadline = DateTime.tryParse(assessmentData['deadline']);
        }
        _assessmentHeaderImageUrl = assessmentData['assessmentHeaderImageUrl'];
        _assessmentHeaderImagePath = assessmentData['assessmentHeaderImagePath'];

        if (assessmentData['questions'] is List) {
          _questions = (assessmentData['questions'] as List)
              .map((qMap) => AssessmentQuestion.fromMap(qMap as Map<String, dynamic>))
              .toList();
        }
        // _trainerClasses = classes; // Assign fetched classes
        _pageLoading = false;
      });

    } catch (e) {
      setState(() { _error = "Failed to load assessment: ${e.toString()}"; _pageLoading = false; });
    }
  }

  // --- Assessment Header Image Handlers (reuse/adapt from CreateAssessmentPage) ---
  // _pickAssessmentHeaderImage, _uploadAssessmentHeaderImage, _removeAssessmentHeaderImage
  // Important: _uploadAssessmentHeaderImage should handle replacing old image if _assessmentHeaderImagePath exists.
  // _removeAssessmentHeaderImage should also delete from storage if _assessmentHeaderImagePath exists.

  // --- Question Management (Simplified - reuse/adapt from CreateAssessmentPage) ---
  // _addOrEditQuestion, _deleteQuestion
  // _deleteQuestion should also handle deleting question-specific images from storage.

  Future<void> _handleUpdateAssessment() async {
    if (_currentUser == null) {
      setState(() => _error = "Authentication error.");
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_selectedClassId == null || _selectedClassId!.isEmpty) {
        setState(() => _error = "Please select a class for this assessment.");
        return;
    }
    if (_questions.isEmpty) {
        setState(() => _error = "Please add at least one question.");
        return;
    }

    setState(() { _isUpdating = true; _error = null; _success = null; });

    try {
      // Handle header image upload/update if _assessmentHeaderImageFile is present
      String? finalHeaderImageUrl = _assessmentHeaderImageUrl;
      String? finalHeaderImagePath = _assessmentHeaderImagePath;

      if (_assessmentHeaderImageFile != null) {
        // If there was an old image, delete it first
        if (_assessmentHeaderImagePath != null && _assessmentHeaderImagePath!.isNotEmpty) {
          // await deleteAssessmentMediaFile(_assessmentHeaderImagePath!); // Implement this
        }
        // final uploadResult = await uploadAssessmentMediaFile(...); // Implement this
        // finalHeaderImageUrl = uploadResult['downloadURL'];
        // finalHeaderImagePath = uploadResult['filePath'];
      } else if (_assessmentHeaderImageFile == null && _assessmentHeaderImageUrl == null && _assessmentHeaderImagePath != null) {
        // This means user removed existing image without uploading new one
        // await deleteAssessmentMediaFile(_assessmentHeaderImagePath!); // Implement this
         finalHeaderImagePath = null;
      }


      // Handle question image uploads/updates (complex, needs iteration)
      // For each question in _questions:
      //   If question.localImageFile is not null:
      //     If question.imagePath existed, delete old image from storage.
      //     Upload question.localImageFile to storage.
      //     Update question.imageUrl and question.imagePath with new values.
      //   Else if question.localImageFile is null AND question.imageUrl is null AND question.imagePath existed:
      //     User removed image. Delete question.imagePath from storage.
      //     Set question.imagePath to null.


      final assessmentData = {
        'trainerId': _currentUser!.uid,
        'classId': _selectedClassId,
        'title': _title,
        'description': _description,
        'deadline': _deadline?.toIso8601String(),
        'questions': _questions.map((q) => q.toJson()).toList(), // Assuming toJson in AssessmentQuestion
        'assessmentHeaderImageUrl': finalHeaderImageUrl,
        'assessmentHeaderImagePath': finalHeaderImagePath,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await updateTrainerAssessmentInService(widget.assessmentId, assessmentData);
      setState(() { _success = 'Assessment "$_title" updated successfully!'; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true); // Pop with success
      });

    } catch (e) {
      setState(() { _error = "Failed to update assessment: ${e.toString()}"; });
    } finally {
      setState(() { _isUpdating = false; });
    }
  }

  Future<void> _handleDeleteAssessment() async {
     bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete Assessment'),
        content: Text('Are you sure you want to permanently delete the assessment "$_title"? This action cannot be undone and will remove all associated data.'),
        actions: <Widget>[
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(child: const Text('DELETE PERMANENTLY', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    setState(() { _isUpdating = true; _error = null; _success = null; });
    try {
      // Important: Need to delete associated storage items (header image, question images) BEFORE deleting Firestore doc.
      // if (_assessmentHeaderImagePath != null) await deleteAssessmentMediaFile(_assessmentHeaderImagePath!);
      // for (var q in _questions) { if (q.imagePath != null) await deleteAssessmentMediaFile(q.imagePath!); }

      await deleteTrainerAssessmentFromService(widget.assessmentId); // From ClassAssessmentsListPage
      setState(() { _success = 'Assessment "$_title" deleted successfully.'; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // Navigate back to a relevant page, e.g., class assessments list or trainer dashboard
          int popCount = 0;
          Navigator.of(context).popUntil((_) => popCount++ >= 2); // Pop twice if Edit came from List
        }
      });
    } catch (e) {
      setState(() { _error = "Failed to delete assessment: ${e.toString()}"; _isUpdating = false; });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_pageLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Edit Assessment")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // The UI structure will be very similar to CreateAssessmentPage.
    // Key differences:
    // - AppBar title: "Edit Assessment: $_title"
    // - Initial values for TextFormFields, Dropdown, Deadline picker.
    // - Display existing header image, allow removal/replacement.
    // - Display existing questions, allow editing/removal/reordering.
    // - "Update Assessment" button instead of "Create".
    // - Add a "Delete Assessment" button.

    // For brevity, I'm providing a simplified scaffold.
    // You should adapt the UI from CreateAssessmentPage.dart, populating fields
    // with _title, _description, _selectedClassId, _deadline, _assessmentHeaderImageUrl, _questions.
    return Scaffold(
      appBar: AppBar(
        title: Text(_title.isNotEmpty ? "Edit: $_title" : "Edit Assessment"),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.trashAlt, color: Colors.red),
            onPressed: _isUpdating ? null : _handleDeleteAssessment,
            tooltip: "Delete Assessment",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null)
                Padding(padding: const EdgeInsets.only(bottom:10.0), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              if (_success != null)
                Padding(padding: const EdgeInsets.only(bottom:10.0), child: Text(_success!, style: TextStyle(color: Colors.green[700]))),
              
              // --- Assessment Title ---
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Assessment Title', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a title.' : null,
                onSaved: (value) => _title = value!,
                enabled: !_isUpdating,
              ),
              const SizedBox(height: 16),

              // --- Description ---
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                maxLines: 3,
                onSaved: (value) => _description = value ?? '',
                enabled: !_isUpdating,
              ),
              const SizedBox(height: 16),

              // --- Select Class ---
              if (_trainerClasses.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Class', border: OutlineInputBorder()),
                  value: _selectedClassId, // Ensure this value exists in items
                  items: _trainerClasses.map((TrainerClass cls) {
                    return DropdownMenuItem<String>(value: cls.id, child: Text(cls.className));
                  }).toList(),
                  onChanged: _isUpdating ? null : (value) => setState(() => _selectedClassId = value),
                  validator: (value) => value == null || value.isEmpty ? 'Please select a class.' : null,
                ),
              const SizedBox(height: 16),

              // --- Deadline Picker ---
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.calendarCheck),
                label: Text(_deadline == null ? 'Set Deadline (Optional)' : 'Deadline: ${DateFormat.yMd().add_jm().format(_deadline!)}'),
                onPressed: _isUpdating ? null : () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _deadline ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)), // Allow past for editing
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_deadline ?? DateTime.now()),
                    );
                    if (pickedTime != null) {
                         setState(() => _deadline = DateTime(picked.year, picked.month, picked.day, pickedTime.hour, pickedTime.minute));
                    }
                  }
                },
              ),
              const SizedBox(height: 24),

              // --- Assessment Header Image Section (Adapt from CreateAssessmentPage) ---
              // Needs to show _assessmentHeaderImageUrl if present, allow removal/replacement.
              // Text("Assessment Header Image... (Implement UI similar to Create Page)"),
              const SizedBox(height: 24),


              // --- Questions Section (Adapt from CreateAssessmentPage) ---
              // Needs to list _questions, allow editing, adding, removing.
              // Text("Questions... (${_questions.length}) (Implement UI similar to Create Page)"),
              // Example:
              Text("Questions (${_questions.length})", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_questions.isEmpty) const Center(child: Text("No questions added yet.")),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(q.questionText.isNotEmpty ? q.questionText : "Question ${index + 1}"),
                      subtitle: Text("${q.type.toString().split('.').last} - ${q.points} pts"),
                      // Add edit/delete buttons for each question
                    ),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.plusCircle),
                label: const Text("Add/Manage Questions"),
                onPressed: _isUpdating ? null : () {
                  // Navigate to a question management UI or show dialog
                  // This part is complex and needs its own UI flow.
                },
              ),
              const SizedBox(height: 32),


              _isUpdating
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(FontAwesomeIcons.save),
                      label: const Text('Update Assessment'),
                      onPressed: _handleUpdateAssessment,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12.0)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}