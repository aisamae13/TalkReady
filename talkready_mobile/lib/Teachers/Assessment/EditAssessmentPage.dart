// src/pages/trainer/edit_assessment_page.dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../notification_service.dart';
import 'CreateAssessmentPage.dart';
import 'dart:io';

class Question {
  String questionId;
  String text;
  String type; // 'multiple-choice', 'fill-in-the-blank', or 'speaking_prompt'
  int points;
  String? questionImageUrl;
  String? questionImagePath;

  // MCQ fields
  List<Map<String, dynamic>>? options; // [{optionId: 'A', text: 'Option text'}]
  List<String>? correctOptionIds; // For multi-select MCQ

  // FITB fields
  String? scenarioText;
  String? questionTextBeforeBlank;
  String? questionTextAfterBlank;
  List<String>? correctAnswers; // For typing mode
  String? answerInputMode; // 'typing' or 'multipleChoice'
  String? correctOptionIdForFITB; // For MCQ mode FITB

  // Speaking prompt fields
  String? title;
  String? promptText;

  Question({
    required this.questionId,
    required this.text,
    required this.type,
    required this.points,
    this.questionImageUrl,
    this.questionImagePath,
    this.options,
    this.correctOptionIds,
    this.scenarioText,
    this.questionTextBeforeBlank,
    this.questionTextAfterBlank,
    this.correctAnswers,
    this.answerInputMode,
    this.correctOptionIdForFITB,
    this.title,
    this.promptText,
  });

  factory Question.fromMap(Map<String, dynamic> data) {
    return Question(
      questionId: data['questionId'] ?? '',
      text: data['text'] ?? '',
      type: data['type'] ?? 'multiple-choice',
      points: data['points'] ?? 10,
      questionImageUrl: data['questionImageUrl'],
      questionImagePath: data['questionImagePath'],
      options: (data['options'] as List<dynamic>?)
          ?.map((opt) => Map<String, dynamic>.from(opt))
          .toList(),
      correctOptionIds: (data['correctOptionIds'] as List<dynamic>?)?.cast<String>() ??
          (data['correctAnswers'] as List<dynamic>?)?.cast<String>(), // Fallback for old structure
      scenarioText: data['scenarioText'],
      questionTextBeforeBlank: data['questionTextBeforeBlank'],
      questionTextAfterBlank: data['questionTextAfterBlank'],
      correctAnswers: (data['correctAnswers'] as List<dynamic>?)?.cast<String>(),
      answerInputMode: data['answerInputMode'] ?? 'typing',
      correctOptionIdForFITB: data['correctOptionIdForFITB'],
      title: data['title'],
      promptText: data['promptText'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'text': text,
      'type': type,
      'points': points,
      'questionImageUrl': questionImageUrl,
      'questionImagePath': questionImagePath,
      'options': options,
      'correctOptionIds': correctOptionIds,
      'scenarioText': scenarioText,
      'questionTextBeforeBlank': questionTextBeforeBlank,
      'questionTextAfterBlank': questionTextAfterBlank,
      'correctAnswers': correctAnswers,
      'answerInputMode': answerInputMode,
      'correctOptionIdForFITB': correctOptionIdForFITB,
      'title': title,
      'promptText': promptText,
    };
  }
}

class EditAssessmentPage extends StatefulWidget {
  final String assessmentId;
  const EditAssessmentPage({Key? key, required this.assessmentId}) : super(key: key);

  @override
  _EditAssessmentPageState createState() => _EditAssessmentPageState();
}

class _EditAssessmentPageState extends State<EditAssessmentPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic assessment fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _submissionDeadlineController = TextEditingController();

  List<Question> _questions = [];
  List<Map<String, String>> _trainerClasses = [];
  String? _selectedClassId;
  String _assessmentType = 'standard_quiz';

  // Assessment header image
  String? _assessmentHeaderImageUrl;
  String? _assessmentHeaderImagePath;
  File? _assessmentHeaderImageFile;

  // Question form state
  bool _showQuestionForm = false;
  String? _editingQuestionId;
  String _currentQuestionType = 'multiple-choice';
  int _currentPoints = 10;

  // MCQ specific
  final _currentQuestionTextMCQController = TextEditingController();
  List<Map<String, dynamic>> _currentOptionsMCQ = [
    {'optionId': 'opt_${DateTime.now().millisecondsSinceEpoch}', 'text': ''}
  ];
  List<String> _currentCorrectOptionIdsMCQ = [];

  // FITB specific
  final _currentScenarioTextFITBController = TextEditingController();
  final _currentTextBeforeBlankFITBController = TextEditingController();
  final _currentTextAfterBlankFITBController = TextEditingController();
  List<String> _currentCorrectAnswersFITB = [''];
  String _currentFITBAnswerMode = 'typing';
  List<Map<String, dynamic>> _currentFITBOptions = [
    {'optionId': 'A', 'text': ''},
    {'optionId': 'B', 'text': ''},
    {'optionId': 'C', 'text': ''},
    {'optionId': 'D', 'text': ''}
  ];
  String _currentFITBCorrectOptionId = '';

  // Current question image
  File? _currentQuestionImageFile;
  String? _currentQuestionImageUrl;
  String? _currentQuestionImagePath;

  // UI state
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;
  String? _successMessage;
  String? _imageOperationMessage;

  @override
  void initState() {
    super.initState();
    _fetchAssessmentData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _submissionDeadlineController.dispose();
    _currentQuestionTextMCQController.dispose();
    _currentScenarioTextFITBController.dispose();
    _currentTextBeforeBlankFITBController.dispose();
    _currentTextAfterBlankFITBController.dispose();
    super.dispose();
  }

  Future<String?> _uploadImage(File imageFile, String storagePath) async {
    try {
      print('Uploading image to: $storagePath');

      Reference storageRef = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask = storageRef.putFile(imageFile);

      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();

      print('Image uploaded successfully: $downloadURL');
      return downloadURL;
    } on FirebaseException catch (e) {
      print('Image upload failed: ${e.message}');
      setState(() {
        _errorMessage = 'Image upload failed: ${e.message}';
      });
      return null;
    } catch (e) {
      print('Image upload failed: $e');
      setState(() {
        _errorMessage = 'Image upload failed: $e';
      });
      return null;
    }
  }

  Future<void> _deleteImageFromStorage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;

    try {
      await FirebaseStorage.instance.ref().child(imagePath).delete();
      print('Image deleted from storage: $imagePath');
    } on FirebaseException catch (e) {
      print('Failed to delete image from storage: ${e.message}');
      // Don't throw error, just log it
    } catch (e) {
      print('Failed to delete image from storage: $e');
      // Don't throw error, just log it
    }
  }

  Future<void> _fetchAssessmentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Trainer not authenticated.");
      }
      final trainerId = user.uid;

      // Fetch trainer classes
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('trainerClass')
          .where('trainerId', isEqualTo: trainerId)
          .get();
      _trainerClasses = classesSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'className': doc.data()['className'] as String,
        };
      }).toList();

      // Fetch assessment data
      final assessmentDoc = await FirebaseFirestore.instance
          .collection('trainerAssessments')
          .doc(widget.assessmentId)
          .get();

      if (!assessmentDoc.exists) {
        throw Exception("Assessment not found.");
      }

      final data = assessmentDoc.data();

      // Check authorization
      if (data?['trainerId'] != trainerId) {
        throw Exception("You are not authorized to edit this assessment.");
      }

      // Load basic fields
      _titleController.text = data?['title'] ?? '';
      _descriptionController.text = data?['description'] ?? '';
      _selectedClassId = data?['classId'] ?? data?['associatedClass'];
      _assessmentHeaderImageUrl = data?['assessmentHeaderImageUrl'];
      _assessmentHeaderImagePath = data?['assessmentHeaderImagePath'];

      // Determine assessment type
      if (data?['assessmentType'] == 'speaking_assessment') {
        _assessmentType = 'speaking_assessment';
      } else if (data?['questions'] != null &&
                 (data!['questions'] as List).isNotEmpty &&
                 (data['questions'][0]['type'] == 'speaking_prompt')) {
        _assessmentType = 'speaking_assessment';
      } else {
        _assessmentType = 'standard_quiz';
      }

      // Load deadline
      final timestamp = data?['deadline'] ?? data?['submissionDeadline'] as Timestamp?;
      if (timestamp != null) {
        final deadlineDate = timestamp.toDate();
        _submissionDeadlineController.text = DateFormat('dd/MM/yyyy HH:mm').format(deadlineDate);
      }

      // Load questions
        final questionMaps = data?['questions'] as List<dynamic>? ?? [];

        _questions = questionMaps
            .whereType<Map<String, dynamic>>() // Filter out any non-map entries
            .map((q) => Question.fromMap(q))
            .toList();

    } catch (e) {
      _errorMessage = 'Failed to load assessment: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

 Future<void> _updateAssessment() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  if (_questions.isEmpty && _assessmentType != 'speaking_assessment') {
    setState(() {
      _errorMessage = "Please add at least one question.";
    });
    return;
  }

  setState(() {
    _isUpdating = true;
    _errorMessage = null;
    _successMessage = null;
    _imageOperationMessage = 'Saving changes...';
  });

  try {
    // 1. Handle header image upload/deletion first
    String? finalHeaderImageUrl = _assessmentHeaderImageUrl;
    String? finalHeaderImagePath = _assessmentHeaderImagePath;

    if (_assessmentHeaderImageFile != null) {
      // A new image has been selected. Upload it.
      final storagePath = 'assessments/${widget.assessmentId}/header_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newImageUrl = await _uploadImage(_assessmentHeaderImageFile!, storagePath);
      if (newImageUrl == null) {
        throw Exception("Header image upload failed.");
      }

      // If a previous image existed, delete it from storage.
      if (_assessmentHeaderImagePath != null) {
        await _deleteImageFromStorage(_assessmentHeaderImagePath);
      }

      finalHeaderImageUrl = newImageUrl;
      finalHeaderImagePath = storagePath;
    } else if (_assessmentHeaderImagePath != null && _assessmentHeaderImageUrl == null) {
      // User removed the old image. Delete it from storage.
      await _deleteImageFromStorage(_assessmentHeaderImagePath);
      finalHeaderImagePath = null;
    }

    // 2. Prepare the deadline
    DateTime? deadline;
    if (_submissionDeadlineController.text.isNotEmpty) {
      try {
        deadline = DateFormat('dd/MM/yyyy HH:mm').parseStrict(_submissionDeadlineController.text);
      } catch (e) {
        throw Exception("Invalid date format. Use dd/MM/yyyy HH:mm.");
      }
    }

    // 3. Create the data map for Firestore
    final assessmentDataToUpdate = {
      'classId': _selectedClassId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'assessmentType': _assessmentType,
      'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
      'assessmentHeaderImageUrl': finalHeaderImageUrl,
      'assessmentHeaderImagePath': finalHeaderImagePath,
      'questions': _questions.map((q) => q.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 4. Update Firestore
await FirebaseFirestore.instance
    .collection('trainerAssessments')
    .doc(widget.assessmentId)
    .update(assessmentDataToUpdate);

// 5. Get trainer's name from Firestore
String trainerName = 'Your trainer';
try {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final trainerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (trainerDoc.exists) {
      final trainerData = trainerDoc.data()!;
      trainerName = '${trainerData['firstName'] ?? ''} ${trainerData['lastName'] ?? ''}'.trim();
      if (trainerName.isEmpty) {
        trainerName = trainerData['displayName'] ?? 'Your trainer';
      }
    }
  }
} catch (e) {
  debugPrint('Could not fetch trainer name: $e');
}

// 6. Get class name for notification
String? className;
try {
  if (_selectedClassId != null) {
    final classDoc = await FirebaseFirestore.instance
        .collection('trainerClass')
        .doc(_selectedClassId)
        .get();
    className = classDoc.data()?['className'] as String?;
  }
} catch (e) {
  debugPrint('Could not fetch class name: $e');
}

// 7. Create notifications for students
if (_selectedClassId != null) {
  await NotificationService.createNotificationsForStudents(
  classId: _selectedClassId!,
  message: '$trainerName updated an assessment: ${_titleController.text.trim()}',
  className: className,
  link: '/student/class/$_selectedClassId',
  type: 'assessment',  // ADD THIS
);
}

    setState(() {
      _successMessage = 'Assessment "${_titleController.text}" updated successfully!';
      _assessmentHeaderImageUrl = finalHeaderImageUrl;
      _assessmentHeaderImagePath = finalHeaderImagePath;
      _assessmentHeaderImageFile = null;
    });

    // Navigate back after a delay
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  } on FirebaseException catch (e) {
    setState(() {
      _errorMessage = 'Firebase error: ${e.message}';
    });
  } catch (e) {
    setState(() {
      _errorMessage = 'Failed to update assessment: $e';
    });
  } finally {
    setState(() {
      _isUpdating = false;
      _imageOperationMessage = null;
    });
  }
}

  Future<void> _deleteAssessment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Assessment'),
        content: Text('Are you sure you want to permanently delete "${_titleController.text}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _imageOperationMessage = 'Deleting assessment...';
    });

    try {
      // Delete all question images
      for (var question in _questions) {
        if (question.questionImagePath != null) {
          await _deleteImageFromStorage(question.questionImagePath);
        }
      }

      // Delete header image
      if (_assessmentHeaderImagePath != null) {
        await _deleteImageFromStorage(_assessmentHeaderImagePath);
      }

      // Delete assessment document
      await FirebaseFirestore.instance
          .collection('trainerAssessments')
          .doc(widget.assessmentId)
          .delete();

      setState(() {
        _successMessage = 'Assessment deleted successfully!';
      });

      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to delete assessment: $e';
      });
    } finally {
      setState(() {
        _isUpdating = false;
        _imageOperationMessage = null;
      });
    }
  }


void _cloneAssessment() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.copy, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Clone Assessment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a copy of "${_titleController.text}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will create a new assessment with:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildCloneInfoItem('Title prefixed with "Copy of"'),
            _buildCloneInfoItem('All questions/prompts'),
            _buildCloneInfoItem('Same description and settings'),
            _buildCloneInfoItem('Header image reference'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can modify the copy before saving',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _performClone();
            },
            icon: const Icon(Icons.copy),
            label: const Text('Clone Assessment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    },
  );
}
void _performClone() {
  // Prepare cloned data
  final clonedData = {
    'title': _titleController.text,
    'description': _descriptionController.text,
    'assessmentType': _assessmentType,
    'headerImageUrl': _assessmentHeaderImageUrl,
    'deadline': _submissionDeadlineController.text,
    'questions': _questions.map((q) => {
      'questionId': q.questionId,
      'text': q.text,
      'type': q.type,
      'points': q.points,
      'questionImageUrl': q.questionImageUrl,
      'options': q.options,
      'correctOptionIds': q.correctOptionIds,
      'correctAnswers': q.correctAnswers,
      'scenarioText': q.scenarioText,
      'questionTextBeforeBlank': q.questionTextBeforeBlank,
      'questionTextAfterBlank': q.questionTextAfterBlank,
      'answerInputMode': q.answerInputMode,
      'correctOptionIdForFITB': q.correctOptionIdForFITB,
      'title': q.title,
      'promptText': q.promptText,
      'requiresReview': q.type == 'fill-in-the-blank' || q.type == 'speaking_prompt',
    }).toList(),
  };

  // Navigate to CreateAssessmentPage with cloned data
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CreateAssessmentPage(
        initialClassId: _selectedClassId,
        clonedData: clonedData,
      ),
    ),
  ).then((value) {
    if (value == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Assessment cloned successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  });
}
  Future<void> _selectDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        setState(() {
          _submissionDeadlineController.text = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
        });
      }
    }
  }

  void _resetQuestionForm() {
    _currentQuestionTextMCQController.clear();
    _currentScenarioTextFITBController.clear();
    _currentTextBeforeBlankFITBController.clear();
    _currentTextAfterBlankFITBController.clear();

    setState(() {
      _currentOptionsMCQ = [
        {'optionId': 'opt_${DateTime.now().millisecondsSinceEpoch}', 'text': ''}
      ];
      _currentCorrectOptionIdsMCQ.clear();
      _currentCorrectAnswersFITB = [''];
      _currentFITBAnswerMode = 'typing';
      _currentFITBOptions = [
        {'optionId': 'A', 'text': ''},
        {'optionId': 'B', 'text': ''},
        {'optionId': 'C', 'text': ''},
        {'optionId': 'D', 'text': ''}
      ];
      _currentFITBCorrectOptionId = '';
      _currentQuestionImageFile = null;
      _currentQuestionImageUrl = null;
      _currentQuestionImagePath = null;
      _currentPoints = 10;
      _editingQuestionId = null;
    });
  }
Widget _buildCloneInfoItem(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

  void _showAddQuestionDialog() {
    _resetQuestionForm();
    setState(() {
      _showQuestionForm = true;
    });
  }

  void _editQuestion(Question question) {
    _resetQuestionForm();
    setState(() {
      _editingQuestionId = question.questionId;
      _currentQuestionType = question.type;
      _currentPoints = question.points;
      _currentQuestionImageUrl = question.questionImageUrl;
      _currentQuestionImagePath = question.questionImagePath;
      _showQuestionForm = true;
    });

    if (question.type == 'multiple-choice') {
      _currentQuestionTextMCQController.text = question.text;
      _currentOptionsMCQ = question.options?.map((opt) => Map<String, dynamic>.from(opt)).toList() ??
          [{'optionId': 'opt_${DateTime.now().millisecondsSinceEpoch}', 'text': ''}];
      _currentCorrectOptionIdsMCQ = question.correctOptionIds ?? [];
    } else if (question.type == 'fill-in-the-blank') {
      _currentScenarioTextFITBController.text = question.scenarioText ?? '';
      _currentTextBeforeBlankFITBController.text = question.questionTextBeforeBlank ?? '';
      _currentTextAfterBlankFITBController.text = question.questionTextAfterBlank ?? '';
      _currentFITBAnswerMode = question.answerInputMode ?? 'typing';

      if (_currentFITBAnswerMode == 'multipleChoice') {
        _currentFITBOptions = question.options?.map((opt) => Map<String, dynamic>.from(opt)).toList() ??
            [{'optionId': 'A', 'text': ''}, {'optionId': 'B', 'text': ''}, {'optionId': 'C', 'text': ''}, {'optionId': 'D', 'text': ''}];
        _currentFITBCorrectOptionId = question.correctOptionIdForFITB ?? '';
      } else {
        _currentCorrectAnswersFITB = question.correctAnswers ?? [''];
      }
    }
  }

  Future<void> _saveQuestionToList() async {
    // Validation
    if (_currentQuestionType == 'multiple-choice') {
      if (_currentQuestionTextMCQController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter question text'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_currentOptionsMCQ.where((opt) => opt['text'].toString().trim().isNotEmpty).length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please add at least 2 options'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_currentCorrectOptionIdsMCQ.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one correct answer'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_currentQuestionType == 'fill-in-the-blank') {
      if (_currentTextBeforeBlankFITBController.text.trim().isEmpty && _currentTextAfterBlankFITBController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please add text before or after the blank'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_currentFITBAnswerMode == 'typing' &&
          _currentCorrectAnswersFITB.where((ans) => ans.trim().isNotEmpty).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please provide at least one correct answer'), backgroundColor: Colors.red),
        );
        return;
      } else if (_currentFITBAnswerMode == 'multipleChoice' && _currentFITBCorrectOptionId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select the correct answer'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() {
      _isUpdating = true;
      _imageOperationMessage = 'Saving question...';
    });

    try {
      // Handle question image upload/deletion
      String? finalQuestionImageUrl = _currentQuestionImageUrl;
      String? finalQuestionImagePath = _currentQuestionImagePath;

      if (_currentQuestionImageFile != null) {
        final storagePath = 'questions/${widget.assessmentId}/q_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newImageUrl = await _uploadImage(_currentQuestionImageFile!, storagePath);

        if (newImageUrl != null) {
          // If a previous image existed for this question, delete it.
          final existingQuestion = _questions.firstWhere((q) => q.questionId == _editingQuestionId, orElse: () => Question(questionId: '', text: '', type: '', points: 0));
          if (existingQuestion.questionImagePath != null) {
            await _deleteImageFromStorage(existingQuestion.questionImagePath);
          }
          finalQuestionImageUrl = newImageUrl;
          finalQuestionImagePath = storagePath;
        } else {
          throw Exception("Question image upload failed.");
        }
      } else if (_editingQuestionId != null && _currentQuestionImageUrl == null) {
        // If user removed the image from an existing question
        final existingQuestion = _questions.firstWhere((q) => q.questionId == _editingQuestionId, orElse: () => Question(questionId: '', text: '', type: '', points: 0));
        if (existingQuestion.questionImagePath != null) {
          await _deleteImageFromStorage(existingQuestion.questionImagePath);
        }
        finalQuestionImagePath = null;
      }

      // Create question object with final image data
      final questionId = _editingQuestionId ?? 'q_${DateTime.now().millisecondsSinceEpoch}';
      final newQuestion = Question(
        questionId: questionId,
        text: _currentQuestionType == 'multiple-choice'
            ? _currentQuestionTextMCQController.text.trim()
            : '${_currentScenarioTextFITBController.text} ${_currentTextBeforeBlankFITBController.text} ___ ${_currentTextAfterBlankFITBController.text}'.trim(),
        type: _currentQuestionType,
        points: _currentPoints,
        questionImageUrl: finalQuestionImageUrl,
        questionImagePath: finalQuestionImagePath,
      );

      if (_currentQuestionType == 'multiple-choice') {
        newQuestion.options = _currentOptionsMCQ.where((opt) => opt['text'].toString().trim().isNotEmpty).toList();
        newQuestion.correctOptionIds = _currentCorrectOptionIdsMCQ;
      } else if (_currentQuestionType == 'fill-in-the-blank') {
        newQuestion.scenarioText = _currentScenarioTextFITBController.text.trim();
        newQuestion.questionTextBeforeBlank = _currentTextBeforeBlankFITBController.text.trim();
        newQuestion.questionTextAfterBlank = _currentTextAfterBlankFITBController.text.trim();
        newQuestion.answerInputMode = _currentFITBAnswerMode;

        if (_currentFITBAnswerMode == 'typing') {
          newQuestion.correctAnswers = _currentCorrectAnswersFITB.where((ans) => ans.trim().isNotEmpty).toList();
        } else {
          newQuestion.options = _currentFITBOptions;
          newQuestion.correctOptionIdForFITB = _currentFITBCorrectOptionId;
        }
      }

      // Update local questions list
      setState(() {
        if (_editingQuestionId != null) {
          final index = _questions.indexWhere((q) => q.questionId == _editingQuestionId);
          if (index >= 0) {
            _questions[index] = newQuestion;
          }
        } else {
          _questions.add(newQuestion);
        }
        _showQuestionForm = false;
        _isUpdating = false;
      });

      _resetQuestionForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingQuestionId != null ? 'Question updated!' : 'Question added!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save question: $e';
        _isUpdating = false;
      });
    } finally {
      setState(() {
        _imageOperationMessage = null;
      });
    }
  }

  Future<void> _removeQuestion(String questionId) async {
    final questionToRemove = _questions.firstWhere((q) => q.questionId == questionId, orElse: () => Question(questionId: '', text: '', type: '', points: 0));

    setState(() {
      _isUpdating = true;
      _imageOperationMessage = 'Removing question...';
    });

    try {
      if (questionToRemove.questionImagePath != null) {
        await _deleteImageFromStorage(questionToRemove.questionImagePath);
      }

      setState(() {
        _questions.removeWhere((q) => q.questionId == questionId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Question removed'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to remove question: $e';
      });
    } finally {
      setState(() {
        _isUpdating = false;
        _imageOperationMessage = null;
      });
    }
  }


  Future<void> _pickHeaderImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxHeight: 800,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _assessmentHeaderImageFile = File(pickedFile.path);
        _imageOperationMessage = 'Header image selected! Click "Save Changes" to upload.';
      });

      // Clear message after 4 seconds
      Future.delayed(Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _imageOperationMessage = null;
          });
        }
      });
    }
  }

  void _removeHeaderImage() {
    setState(() {
      _assessmentHeaderImageFile = null;
      _assessmentHeaderImageUrl = null;
      _imageOperationMessage = 'Header image removed! Click "Save Changes" to confirm.';
    });

    Future.delayed(Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _imageOperationMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Assessment'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6),
              Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        actions: [
          IconButton(
            onPressed: _cloneAssessment,
            icon: const Icon(Icons.copy),
            tooltip: 'Clone Assessment',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error/Success Messages
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_successMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_imageOperationMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,        // Light purple background
                    border: Border.all(color: Colors.purple.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: const Color.fromARGB(255, 133, 18, 156), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _imageOperationMessage!,
                          style: TextStyle(color: Colors.blue.shade700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              // Assessment Details Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assessment Details',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Assessment Type (read-only)
                      const Text('Assessment Type', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _assessmentType == 'speaking_assessment' ? 'Speaking Assessment' : 'Standard Quiz',
                        enabled: false,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const Text(
                        'The assessment type cannot be changed after creation.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Associated Class
                      const Text('Associated Class *', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedClassId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Select a Class',
                          prefixIcon: Icon(Icons.class_),
                        ),
                        items: _trainerClasses.map((classData) {
                          return DropdownMenuItem<String>(
                            value: classData['id'],
                            child: Text(classData['className']!),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedClassId = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a class.';
                          }
                          return null;
                        },
                      ),
                      if (_trainerClasses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'No classes available. Create one first.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Submission Deadline
                      const Text('Submission Deadline (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _submissionDeadlineController,
                        readOnly: true,
                        onTap: () => _selectDateTime(context),
                        decoration: InputDecoration(
                          labelText: 'dd/MM/yyyy HH:mm',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: _submissionDeadlineController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _submissionDeadlineController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                      const Text(
                        'If set, students cannot start the assessment after this date and time.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Assessment Header Image
                      const Text('Assessment Header Image (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_assessmentHeaderImageFile != null || _assessmentHeaderImageUrl != null)
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _assessmentHeaderImageFile != null
                                    ? Image.file(_assessmentHeaderImageFile!, fit: BoxFit.contain, height: 150)
                                    : Image.network(_assessmentHeaderImageUrl!, fit: BoxFit.contain, height: 150),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                onPressed: _removeHeaderImage,
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: _pickHeaderImage,
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Tap to Upload Header Image', style: TextStyle(color: Colors.grey)),
                                Text('Max 5MB', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Questions Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Questions',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_assessmentType == 'standard_quiz')
                            OutlinedButton.icon(
                              onPressed: _showAddQuestionDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Question'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.colorScheme.primary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_assessmentType == 'speaking_assessment')
                        // Speaking Assessment Questions (Read-only)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'You are editing a speaking assessment. The prompts are listed below. To add or remove prompts, please create a new assessment.',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            ..._questions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final question = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prompt ${index + 1}: ${question.title ?? "Speaking Prompt"}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (question.promptText != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        question.promptText!,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        )
                      else
                        // Standard Quiz Questions
                        Column(
                          children: [
                            if (_questions.isEmpty && !_showQuestionForm)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text('No questions added yet.'),
                                ),
                              ),
                            ..._questions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final question = entry.value;
                              return _buildQuestionCard(index, question, theme);
                            }).toList(),

                            // Question Form
                            if (_showQuestionForm)
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,        // Light purple background
                                  border: Border.all(color: Colors.purple.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _buildQuestionForm(theme),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              if (_successMessage == null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUpdating ? null : _deleteAssessment,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Delete Assessment',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUpdating ? null : _updateAssessment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isUpdating
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Saving...'),
                                ],
                              )
                            : const Text('Save Changes', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildQuestionCard(int index, Question question, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Q${index + 1}: ${question.type == 'multiple-choice' ? '(Multiple Choice)' : '(Fill-in-Blank)'}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _editQuestion(question),
                      icon: const Icon(Icons.edit, size: 18),
                      color: const Color.fromARGB(255, 139, 21, 145),
                      tooltip: 'Edit Question',
                    ),
                    IconButton(
                      onPressed: () => _removeQuestion(question.questionId),
                      icon: const Icon(Icons.delete, size: 18),
                      color: theme.colorScheme.error,
                      tooltip: 'Delete Question',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Question Image
            if (question.questionImageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    question.questionImageUrl!,
                    fit: BoxFit.contain,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),

            // Question Content
            if (question.type == 'multiple-choice') ...[
              Text(
                question.text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (question.options != null && question.options!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...question.options!.asMap().entries.map((entry) {
                  final optIndex = entry.key;
                  final option = entry.value;
                  final isCorrect = question.correctOptionIds?.contains(option['optionId']) ?? false;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('${String.fromCharCode(65 + optIndex)}. '),
                        Expanded(
                          child: Text(
                            option['text'] ?? '',
                            style: TextStyle(
                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                              color: isCorrect ? Colors.green : Colors.black87,
                            ),
                          ),
                        ),
                        if (isCorrect)
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ] else if (question.type == 'fill-in-the-blank') ...[
              if (question.scenarioText?.isNotEmpty ?? false) ...[
                Text(
                  'Scenario: ${question.scenarioText}',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
                const SizedBox(height: 4),
              ],
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  children: [
                    if (question.questionTextBeforeBlank?.isNotEmpty ?? false)
                      TextSpan(text: question.questionTextBeforeBlank),
                    const TextSpan(
                      text: ' _____ ',
                      style: TextStyle(fontWeight: FontWeight.bold, color:Color.fromARGB(255, 139, 21, 145),),
                    ),
                    if (question.questionTextAfterBlank?.isNotEmpty ?? false)
                      TextSpan(text: question.questionTextAfterBlank),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (question.answerInputMode == 'typing' && question.correctAnswers != null)
                Text(
                  'Correct Answer(s): ${question.correctAnswers!.join(' / ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                )
              else if (question.answerInputMode == 'multipleChoice' && question.options != null) ...[
                const Text('Options:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ...question.options!.map((option) {
                  final isCorrect = option['optionId'] == question.correctOptionIdForFITB;
                  return Text(
                    '${option['optionId']}: ${option['text']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCorrect ? Colors.green : Colors.black87,
                      fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ],
            ],

            const SizedBox(height: 8),
            Text(
              'Points: ${question.points}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _editingQuestionId != null ? 'Edit Question' : 'Add New Question',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _currentQuestionType,
              items: const [
                DropdownMenuItem(value: 'multiple-choice', child: Text('Multiple Choice')),
                DropdownMenuItem(value: 'fill-in-the-blank', child: Text('Fill-in-Blank')),
              ],
              onChanged: _editingQuestionId == null ? (value) {
                if (value != null) {
                  setState(() {
                    _currentQuestionType = value;
                  });
                }
              } : null,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Question Image Upload
        const Text('Question Image (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        if (_currentQuestionImageUrl != null || _currentQuestionImageFile != null)
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _currentQuestionImageFile != null
                      ? Image.file(_currentQuestionImageFile!, fit: BoxFit.contain, height: 80)
                      : Image.network(_currentQuestionImageUrl!, fit: BoxFit.contain, height: 80),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentQuestionImageFile = null;
                      _currentQuestionImageUrl = null;
                      _currentQuestionImagePath = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: () async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 70,
                maxHeight: 400,
                maxWidth: 400,
              );
              if (pickedFile != null) {
                setState(() {
                  _currentQuestionImageFile = File(pickedFile.path);
                });
              }
            },
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey.shade50,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 20, color: Colors.grey),
                  Text('Add Image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Question Type Specific Fields
        if (_currentQuestionType == 'multiple-choice') ...[
          // MCQ Question Text
          TextFormField(
            controller: _currentQuestionTextMCQController,
            decoration: const InputDecoration(
              labelText: 'Question Text *',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // MCQ Options
          const Text('Options (Check correct answers) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          ..._currentOptionsMCQ.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: _currentCorrectOptionIdsMCQ.contains(option['optionId']),
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          _currentCorrectOptionIdsMCQ.add(option['optionId']);
                        } else {
                          _currentCorrectOptionIdsMCQ.remove(option['optionId']);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: option['text'],
                      decoration: InputDecoration(
                        labelText: 'Option ${index + 1}',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _currentOptionsMCQ[index]['text'] = value;
                        });
                      },
                    ),
                  ),
                  if (_currentOptionsMCQ.length > 1)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          final removedId = _currentOptionsMCQ[index]['optionId'];
                          _currentOptionsMCQ.removeAt(index);
                          _currentCorrectOptionIdsMCQ.remove(removedId);
                        });
                      },
                      icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                    ),
                ],
              ),
            );
          }).toList(),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _currentOptionsMCQ.add({
                  'optionId': 'opt_${DateTime.now().millisecondsSinceEpoch}',
                  'text': ''
                });
              });
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Option', style: TextStyle(fontSize: 12)),
          ),
        ] else if (_currentQuestionType == 'fill-in-the-blank') ...[
          // FITB Scenario
          TextFormField(
            controller: _currentScenarioTextFITBController,
            decoration: const InputDecoration(
              labelText: 'Scenario Context (Optional)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          // FITB Before Blank
          TextFormField(
            controller: _currentTextBeforeBlankFITBController,
            decoration: const InputDecoration(
              labelText: 'Text Before Blank',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),

          const Center(
            child: Text(
              '[STUDENT FILLS BLANK HERE]',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // FITB After Blank
          TextFormField(
            controller: _currentTextAfterBlankFITBController,
            decoration: const InputDecoration(
              labelText: 'Text After Blank',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

          // Answer Input Mode
          const Text('Student Answer Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Typing', style: TextStyle(fontSize: 12)),
                  value: 'typing',
                  groupValue: _currentFITBAnswerMode,
                  onChanged: (value) {
                    setState(() {
                      _currentFITBAnswerMode = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Multiple Choice', style: TextStyle(fontSize: 12)),
                  value: 'multipleChoice',
                  groupValue: _currentFITBAnswerMode,
                  onChanged: (value) {
                    setState(() {
                      _currentFITBAnswerMode = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Conditional inputs based on answer mode
          if (_currentFITBAnswerMode == 'typing') ...[
            const Text('Acceptable Typed Answers *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            ..._currentCorrectAnswersFITB.asMap().entries.map((entry) {
              final index = entry.key;
              final answer = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: answer,
                        decoration: InputDecoration(
                          labelText: 'Answer ${index + 1}',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.all(8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _currentCorrectAnswersFITB[index] = value;
                          });
                        },
                      ),
                    ),
                    if (_currentCorrectAnswersFITB.length > 1)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentCorrectAnswersFITB.removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                      ),
                  ],
                ),
              );
            }).toList(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentCorrectAnswersFITB.add('');
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Answer', style: TextStyle(fontSize: 12)),
            ),
          ] else if (_currentFITBAnswerMode == 'multipleChoice') ...[
            const Text('Options (Select correct answer) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            ..._currentFITBOptions.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<String>(
                      value: option['optionId'],
                      groupValue: _currentFITBCorrectOptionId,
                      onChanged: (value) {
                        setState(() {
                          _currentFITBCorrectOptionId = value!;
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: option['text'],
                        decoration: InputDecoration(
                          labelText: 'Option ${option['optionId']}',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.all(8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _currentFITBOptions[index]['text'] = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],

        const SizedBox(height: 16),

        // Points
        Row(
          children: [
            const Text('Points: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: _currentPoints.toString(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final points = int.tryParse(value);
                  if (points != null && points >= 0) {
                    setState(() {
                      _currentPoints = points;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _showQuestionForm = false;
                });
                _resetQuestionForm();
              },
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isUpdating ? null : _saveQuestionToList,
              child: Text(_editingQuestionId != null ? 'Update' : 'Add Question'),
            ),
          ],
        ),
      ],
    );
  }
}