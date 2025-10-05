// src/components/TrainerSection/assessments/CreateAssessmentPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

// Add the new imports
import '../../Teachers/Assessment/ClassAssessmentsListPage.dart';
import '../../notification_service.dart';

class Question {
  String id;
  String text;
  String
  type; // e.g., 'multiple-choice', 'fill-in-the-blank', 'speaking_prompt'
  List<String>? options; // For multiple-choice
  List<String>? correctAnswers; // Can be single or multiple
  int points;
  bool requiresReview;
  String? questionImageUrl;
  String? questionImagePath;

  // Fields for fill-in-the-blank type
  String? scenarioContext;
  String? textBeforeBlank;
  String? textAfterBlank;
  String? fillInInputMethod; // 'typing' or 'multiple-choice'

  // NEW: Add these fields for speaking prompts
  String? title;
  String? promptText;
  String? referenceText;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    this.correctAnswers,
    this.points = 10,
    this.requiresReview = false,
    this.questionImageUrl,
    this.questionImagePath,
    this.scenarioContext,
    this.textBeforeBlank,
    this.textAfterBlank,
    this.fillInInputMethod,
    // NEW: Add these parameters
    this.title,
    this.promptText,
    this.referenceText,
  });

  Map<String, dynamic> toMap() {
    final baseMap = {
      'questionId': id,
      'text': text,
      'type': type,
      'questionImageUrl': questionImageUrl,
      'questionImagePath': questionImagePath,
      'points': points,
      'requiresReview': requiresReview,
    };

    if (type == 'speaking_prompt') {
      // Add speaking prompt specific fields
      baseMap.addAll({
        'title': title,
        'promptText': promptText,
        'referenceText': referenceText,
      });
    } else {
      // Your existing logic for other question types
      baseMap.addAll({
        // Standardize option structure
        'options': type == 'multiple-choice'
            ? options
                  ?.asMap()
                  .entries
                  .map(
                    (e) => {
                      'optionId': String.fromCharCode(65 + e.key),
                      'text': e.value,
                    },
                  )
                  .toList()
            : (type == 'fill-in-the-blank' &&
                  fillInInputMethod == 'multiple-choice')
            ? correctAnswers
                  ?.asMap()
                  .entries
                  .map(
                    (e) => {
                      'optionId': String.fromCharCode(65 + e.key),
                      'text': e.value,
                    },
                  )
                  .toList()
            : null,

        // Standardize correct answers
        'correctOptionIds': type == 'multiple-choice'
            ? correctAnswers
                  ?.map((answer) {
                    int index = options?.indexOf(answer) ?? -1;
                    return index >= 0 ? String.fromCharCode(65 + index) : null;
                  })
                  .where((id) => id != null)
                  .toList()
            : null,

        // FITB specific fields with consistent naming
        'scenarioText': scenarioContext,
        'questionTextBeforeBlank': textBeforeBlank,
        'questionTextAfterBlank': textAfterBlank,
        'correctAnswers':
            type == 'fill-in-the-blank' && fillInInputMethod == 'typing'
            ? correctAnswers
            : null,
        'answerInputMode': fillInInputMethod,
        'correctOptionIdForFITB':
            type == 'fill-in-the-blank' &&
                fillInInputMethod == 'multiple-choice'
            ? 'A'
            : null,
      });
    }

    return baseMap;
  }
}

// NEW: Define a SpeakingPrompt model
class SpeakingPrompt {
  String id;
  String title;
  String promptText;
  String referenceText;
  int points;
  bool requiresReview;

  SpeakingPrompt({
    required this.id,
    required this.title,
    required this.promptText,
    required this.referenceText,
    this.points = 100,
    this.requiresReview = true, // Speaking assessments always require review
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': id, // Consistent with Question structure
      'title': title,
      'type': 'speaking_prompt',
      'promptText': promptText,
      'text': promptText, // Duplicate for compatibility
      'referenceText': referenceText,
      'points': points,
      'requiresReview': requiresReview,
    };
  }
}

class CreateAssessmentPage extends StatefulWidget {
  final String? classId;
  final String? initialClassId;
  final Map<String, dynamic>? clonedData;  // ADD THIS LINE
  const CreateAssessmentPage({
    super.key,
    this.classId,
    this.initialClassId,
    this.clonedData,  // ADD THIS LINE
  });

  @override
  State<CreateAssessmentPage> createState() => _CreateAssessmentPageState();
}

class _CreateAssessmentPageState extends State<CreateAssessmentPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // VVVV ADD THESE NEW CONTROLLERS VVVV
  final TextEditingController _promptTitleController = TextEditingController();
  final TextEditingController _promptTextController = TextEditingController();
  final TextEditingController _referenceTextController =
      TextEditingController();
  // ^^^^ END OF NEW CONTROLLERS ^^^^

  String? _selectedClassId;
  List<Map<String, dynamic>> _trainerClasses = [];

  final List<Question> _questions = [];
  bool _isLoading = false;
  String? _error;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Image + ID helpers
  final _imagePicker = ImagePicker();
  final _uuid = const Uuid();

  // Assessment type
  String _assessmentType = 'standard_quiz';

  // Deadline
  DateTime? _deadline;
  final _deadlineFmt = DateFormat('yyyy-MM-dd HH:mm');
  String? get _deadlineDisplay =>
      _deadline == null ? null : _deadlineFmt.format(_deadline!);

  // Header image (5MB limit)
  XFile? _assessmentHeaderXFile;
  String? _assessmentHeaderImageUrl;
  String? _assessmentHeaderImagePath;
  bool _isUploadingHeaderImage = false;
  String? _headerImageError;

  // Current question image (2MB limit)
  XFile? _currentQuestionXFile;
  String? _currentQuestionImageUrl;
  String? _currentQuestionImagePath;
  bool _isUploadingQuestionImage = false;
  String? _questionImageError;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
@override
void initState() {
  super.initState();
  _selectedClassId = widget.classId ?? widget.initialClassId;

  // Initialize animations
  _fadeController = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  );
  _slideController = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );

  _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
  );
  _slideAnimation =
      Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
      );

  if (widget.classId == null && widget.initialClassId == null) {
    _fetchTrainerClasses();
  }

  // ADD THESE 3 LINES:
  if (widget.clonedData != null) {
    _loadClonedData();
  }

  // Start animations
  _fadeController.forward();
  _slideController.forward();
}
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _promptTitleController.dispose();
    _promptTextController.dispose();
    _referenceTextController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrainerClasses() async {
    if (currentUser == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trainerClass')
          .where('trainerId', isEqualTo: currentUser!.uid)
          .get();
      setState(() {
        _trainerClasses = snapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'name': doc.data()['className'] ?? 'Unnamed Class',
              },
            )
            .toList();
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load classes: ${e.toString()}";
      });
    }
  }
void _loadClonedData() {
  final data = widget.clonedData!;

  // Load basic info with "Copy of" prefix
  _titleController.text = 'Copy of ${data['title'] ?? ''}';
  _descriptionController.text = data['description'] ?? '';
  _assessmentType = data['assessmentType'] ?? 'standard_quiz';

  // Load header image URL (note: path will be different for the new assessment)
  _assessmentHeaderImageUrl = data['headerImageUrl'];
  _assessmentHeaderImagePath = null; // Don't copy the path, it will be new

  // Load deadline if exists
  if (data['deadline'] != null && data['deadline'].toString().isNotEmpty) {
    try {
      final deadlineStr = data['deadline'] as String;
      // Parse the deadline format from EditAssessmentPage (dd/MM/yyyy HH:mm)
      _deadline = DateFormat('dd/MM/yyyy HH:mm').parse(deadlineStr);
    } catch (e) {
      // If parsing fails, ignore the deadline
      _deadline = null;
    }
  }

  // Load questions based on assessment type
  if (_assessmentType == 'speaking_assessment' && data['questions'] != null) {
    final questions = data['questions'] as List<dynamic>;
    if (questions.isNotEmpty) {
      final firstQuestion = questions[0] as Map<String, dynamic>;
      _promptTitleController.text = firstQuestion['title'] ?? '';
      _promptTextController.text = firstQuestion['promptText'] ?? '';
      _referenceTextController.text = firstQuestion['referenceText'] ?? '';
    }
  } else if (_assessmentType == 'standard_quiz' && data['questions'] != null) {
    // Clone standard quiz questions
    final questions = data['questions'] as List<dynamic>;
    _questions.clear();
    for (var q in questions) {
      final questionMap = q as Map<String, dynamic>;

      // Recreate the question with new ID
      _questions.add(Question(
        id: _uuid.v4(), // Generate new ID for cloned question
        text: questionMap['text'] ?? '',
        type: questionMap['type'] ?? 'multiple-choice',
        points: questionMap['points'] ?? 10,
        requiresReview: questionMap['requiresReview'] ?? false,

        // For multiple choice
        options: (questionMap['options'] as List<dynamic>?)
            ?.map((o) {
              if (o is Map) {
                return o['text']?.toString() ?? '';
              }
              return o.toString();
            })
            .toList(),
        correctAnswers: (questionMap['correctAnswers'] as List<dynamic>?)
            ?.map((a) => a.toString())
            .toList(),

        // Image URL (but not path - will be new)
        questionImageUrl: questionMap['questionImageUrl'],
        questionImagePath: null, // Don't copy path

        // Fill in the blank fields
        scenarioContext: questionMap['scenarioText'],
        textBeforeBlank: questionMap['questionTextBeforeBlank'],
        textAfterBlank: questionMap['questionTextAfterBlank'],
        fillInInputMethod: questionMap['answerInputMode'] ?? 'typing',

        // Speaking prompt fields
        title: questionMap['title'],
        promptText: questionMap['promptText'],
        referenceText: questionMap['referenceText'],
      ));
    }
  }

  setState(() {
    // Trigger UI update
  });
}
  // NEW: Add validation flags
  bool get _canAddQuestions {
    return _titleController.text.trim().isNotEmpty &&
        (_selectedClassId != null || widget.classId != null);
  }

  void _addQuestion() {
    // NEW: Check if basic info is filled before allowing questions
    if (!_canAddQuestions) {
      _showValidationDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return QuestionEditorDialog(
          onSave: (Question newQuestion) {
            setState(() {
              _questions.add(newQuestion);
              _error = null;
            });
            Navigator.of(context).pop();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  // NEW: Show validation dialog
  void _showValidationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    FontAwesomeIcons.triangleExclamation,
                    color: const Color(0xFFF59E0B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                // ADDED Center WIDGET HERE
                Center(
                  child: Text(
                    'Complete Basic Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please fill in the assessment title and select a class before adding questions.',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Auto-focus the title field if empty
                      if (_titleController.text.trim().isEmpty) {
                        FocusScope.of(context).requestFocus(FocusNode());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK, Got It'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editQuestion(int index) {
    final question = _questions[index];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return QuestionEditorDialog(
          existingQuestion: question,
          onSave: (Question updatedQuestion) {
            setState(() {
              _questions[index] = updatedQuestion;
            });
            Navigator.of(context).pop();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _navigateToAssessmentsList() {
    if (_selectedClassId != null || widget.classId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClassAssessmentsListPage(
            classId: _selectedClassId ?? widget.classId!,
          ),
        ),
      );
    } else {
      _showSnackBar('Please select a class first', Colors.orange);
    }
  }

  void _navigateToViewResults(String assessmentId) {
    // This method should only be used when you want to view results of a specific assessment
    // For now, let's navigate to the assessments list instead
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassAssessmentsListPage(
          classId: _selectedClassId ?? widget.classId!,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- Storage helpers ---
  Future<Map<String, String>> _uploadXFileToStorage({
    required XFile xfile,
    required String basePath,
    void Function(double pct)? onProgress,
  }) async {
    final file = File(xfile.path);
    final ext = path.extension(xfile.path);
    final id = _uuid.v4();
    final storagePath = '$basePath/$id$ext';

    final ref = firebase_storage.FirebaseStorage.instance.ref(storagePath);
    final task = ref.putFile(file);

    task.snapshotEvents.listen((s) {
      if (onProgress != null && s.totalBytes > 0) {
        onProgress((s.bytesTransferred / s.totalBytes) * 100);
      }
    });

    final snap = await task;
    final url = await snap.ref.getDownloadURL();
    return {'url': url, 'path': storagePath};
  }

  Future<void> _deleteStorageFileIfAny(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      await firebase_storage.FirebaseStorage.instance.ref(storagePath).delete();
    } catch (_) {}
  }

  // --- Header image ---
  Future<void> _pickHeaderImage() async {
    if (currentUser == null) {
      setState(() => _headerImageError = 'Not logged in.');
      return;
    }
    _headerImageError = null;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final size = await picked.length();
    if (size > 5 * 1024 * 1024) {
      setState(() {
        _headerImageError = 'File is too large. Max 5MB.';
        _assessmentHeaderXFile = null;
      });
      return;
    }

    setState(() {
      _assessmentHeaderXFile = picked;
      _isUploadingHeaderImage = true;
    });

    if ((_assessmentHeaderImagePath ?? '').isNotEmpty) {
      await _deleteStorageFileIfAny(_assessmentHeaderImagePath);
      setState(() {
        _assessmentHeaderImageUrl = null;
        _assessmentHeaderImagePath = null;
      });
    }

    final basePath = 'assessments/temp_${currentUser!.uid}/header';
    try {
      final res = await _uploadXFileToStorage(
        xfile: picked,
        basePath: basePath,
      );
      setState(() {
        _assessmentHeaderImageUrl = res['url'];
        _assessmentHeaderImagePath = res['path'];
      });
    } catch (e) {
      setState(() {
        _headerImageError = 'Failed to upload header image.';
        _assessmentHeaderXFile = null;
      });
    } finally {
      if (mounted) setState(() => _isUploadingHeaderImage = false);
    }
  }

  Future<void> _removeHeaderImage() async {
    setState(() => _isUploadingHeaderImage = true);
    await _deleteStorageFileIfAny(_assessmentHeaderImagePath);
    if (mounted) {
      setState(() {
        _isUploadingHeaderImage = false;
        _assessmentHeaderXFile = null;
        _assessmentHeaderImageUrl = null;
        _assessmentHeaderImagePath = null;
        _headerImageError = null;
      });
    }
  }

  // --- Question image ---
  Future<void> _pickQuestionImage({String? questionId}) async {
    if (currentUser == null) {
      setState(() => _questionImageError = 'Not logged in.');
      return;
    }
    _questionImageError = null;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final size = await picked.length();
    if (size > 2 * 1024 * 1024) {
      setState(() {
        _questionImageError = 'File is too large. Max 2MB.';
        _currentQuestionXFile = null;
      });
      return;
    }

    setState(() {
      _currentQuestionXFile = picked;
      _isUploadingQuestionImage = true;
    });

    if ((_currentQuestionImagePath ?? '').isNotEmpty) {
      await _deleteStorageFileIfAny(_currentQuestionImagePath);
      setState(() {
        _currentQuestionImageUrl = null;
        _currentQuestionImagePath = null;
      });
    }

    final qId = questionId ?? 'temp_q_${DateTime.now().millisecondsSinceEpoch}';
    final basePath = 'assessments/temp_${currentUser!.uid}/questions/$qId';
    try {
      final res = await _uploadXFileToStorage(
        xfile: picked,
        basePath: basePath,
      );
      setState(() {
        _currentQuestionImageUrl = res['url'];
        _currentQuestionImagePath = res['path'];
      });
    } catch (e) {
      setState(() {
        _questionImageError = 'Failed to upload question image.';
        _currentQuestionXFile = null;
      });
    } finally {
      if (mounted) setState(() => _isUploadingQuestionImage = false);
    }
  }

  Future<void> _removeQuestionImage() async {
    setState(() => _isUploadingQuestionImage = true);
    await _deleteStorageFileIfAny(_currentQuestionImagePath);
    if (mounted) {
      setState(() {
        _isUploadingQuestionImage = false;
        _currentQuestionXFile = null;
        _currentQuestionImageUrl = null;
        _currentQuestionImagePath = null;
        _questionImageError = null;
      });
    }
  }

  // --- Build payload (call inside your save flow) ---
  Map<String, dynamic> _buildAssessmentPayload() {
    final basePayload = {
      'trainerId': currentUser?.uid,
      'classId': _selectedClassId ?? widget.classId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'assessmentType': _assessmentType,
      'status': 'published',
      'createdAt': FieldValue.serverTimestamp(),
      'deadline': _deadline?.toIso8601String(),
      if (_assessmentHeaderImageUrl != null)
        'assessmentHeaderImageUrl': _assessmentHeaderImageUrl,
      if (_assessmentHeaderImagePath != null)
        'assessmentHeaderImagePath': _assessmentHeaderImagePath,
    };

    if (_assessmentType == 'standard_quiz') {
      return basePayload
        ..['questions'] = _questions.map((q) => q.toMap()).toList();
    } else {
      // Assume only one speaking prompt per assessment
      final speakingPrompt = SpeakingPrompt(
        id: const Uuid().v4(),
        title: _promptTitleController.text.trim(),
        promptText: _promptTextController.text.trim(),
        referenceText: _referenceTextController.text.trim(),
      );
      return basePayload..['questions'] = [speakingPrompt.toMap()];
    }
  }

  // Example save using payload
  Future<void> _saveAssessment() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_selectedClassId ?? widget.classId) == null) {
      setState(() => _error = 'Please select a class.');
      return;
    }

    // Validation based on assessment type
    if (_assessmentType == 'standard_quiz' && _questions.isEmpty) {
      setState(() => _error = 'Please add at least one question.');
      return;
    }

    if (_assessmentType == 'speaking_assessment') {
      if (_promptTitleController.text.trim().isEmpty) {
        setState(() => _error = 'Please add a title for the speaking prompt.');
        return;
      }
      if (_promptTextController.text.trim().isEmpty) {
        setState(
          () => _error =
              'Please add the prompt text for the speaking assessment.',
        );
        return;
      }
      // NOTE: No deadline validation here - it's optional!

      // Create the speaking prompt
      final speakingPrompt = SpeakingPrompt(
        id: const Uuid().v4(),
        title: _promptTitleController.text.trim(),
        promptText: _promptTextController.text.trim(),
        referenceText: _referenceTextController.text.trim(),
      );

      // Clear any existing questions and add the speaking prompt
      _questions.clear();
      _questions.add(
        Question(
          id: speakingPrompt.id,
          text: speakingPrompt.promptText,
          type: 'speaking_prompt',
          points: speakingPrompt.points,
          requiresReview: true,
          title: speakingPrompt.title,
          promptText: speakingPrompt.promptText,
          referenceText: speakingPrompt.referenceText,
        ),
      );
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = _buildAssessmentPayload();
      final docRef = await FirebaseFirestore.instance
          .collection('trainerAssessments')
          .add(data);

      // Get class name for notification
      final classId = _selectedClassId ?? widget.classId!;
      String? className;
      if (_trainerClasses.isNotEmpty) {
        final selectedClass = _trainerClasses.firstWhere(
          (c) => c['id'] == classId,
          orElse: () => {'name': 'your class'},
        );
        className = selectedClass['name'] as String?;
      }

      // Create notifications for students
      await NotificationService.createNotificationsForStudents(
        classId: classId,
        message: 'New assessment: ${_titleController.text.trim()}',
        className: className,
        link: '/student/class/$classId',
      );

      if (!mounted) return;
      _showSuccessDialog(docRef.id);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to save assessment: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String assessmentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Assessment created successfully!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'What would you like to do next?',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(
                            context,
                          ).pop(); // Go back to previous page
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          // Navigate to ClassAssessmentsListPage to show all assessments
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => ClassAssessmentsListPage(
                                classId: _selectedClassId ?? widget.classId!,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'View Results',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(),
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildMainContent(),
                            // NEW: Add progress indicator
                            const SizedBox(height: 16),
                            _buildProgressIndicator(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Added: Modern AppBar builder
  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Create Assessment',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
          tooltip: 'View Assessments',
          onPressed: _navigateToAssessmentsList,
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  // Update the _buildBackgroundGradient method:
  BoxDecoration _buildBackgroundGradient() {
    return const BoxDecoration(color: Colors.white);
  }

  Widget _buildProgressIndicator() {
    bool titleComplete = _titleController.text.trim().isNotEmpty;
    bool classComplete = _selectedClassId != null || widget.classId != null;

    bool questionsComplete;
    if (_assessmentType == 'standard_quiz') {
      questionsComplete = _questions.isNotEmpty;
    } else {
      // For speaking assessments, check if the form fields are filled
      // NOTE: Deadline is NOT required for completion
      questionsComplete =
          _promptTitleController.text.trim().isNotEmpty &&
          _promptTextController.text.trim().isNotEmpty;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            'Assessment Setup Progress',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildProgressStep('Title', titleComplete, true),
              _buildProgressConnector(titleComplete),
              _buildProgressStep('Class', classComplete, titleComplete),
              _buildProgressConnector(classComplete),
              _buildProgressStep(
                _assessmentType == 'speaking_assessment'
                    ? 'Prompt'
                    : 'Questions',
                questionsComplete,
                classComplete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String label, bool isComplete, bool isEnabled) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF10B981)
                  : isEnabled
                  ? const Color(0xFF8B5CF6).withOpacity(0.1)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isComplete
                    ? const Color(0xFF10B981)
                    : isEnabled
                    ? const Color(0xFF8B5CF6)
                    : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Icon(
              isComplete
                  ? FontAwesomeIcons.check
                  : isEnabled
                  ? FontAwesomeIcons.circle
                  : FontAwesomeIcons.lock,
              color: isComplete
                  ? Colors.white
                  : isEnabled
                  ? const Color(0xFF8B5CF6)
                  : Colors.grey[400],
              size: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isComplete
                  ? const Color(0xFF10B981)
                  : isEnabled
                  ? const Color(0xFF8B5CF6)
                  : Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressConnector(bool isComplete) {
    return Container(
      height: 2,
      width: 24,
      color: isComplete ? const Color(0xFF10B981) : Colors.grey[300],
    );
  }

  // Update the main content build method to include required flags
  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 0),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header - same as before
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6),
                          const Color(0xFF6366F1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      FontAwesomeIcons.clipboardList,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Assessment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Complete the information below to get started',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Error Display (same as before)
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF6B6B).withOpacity(0.1),
                        const Color(0xFFFF5252).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.triangleExclamation,
                        color: const Color(0xFFFF6B6B),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: const Color(0xFFFF6B6B),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Form Fields with required indicators
              _buildModernTextField(
                controller: _titleController,
                label: 'Assessment Title',
                icon: FontAwesomeIcons.fileSignature,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
                isRequired: true,
              ),
              const SizedBox(height: 16),

              _buildModernTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                icon: FontAwesomeIcons.alignLeft,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              if (widget.classId == null && widget.initialClassId == null) ...[
                _buildClassDropdown(),
                const SizedBox(height: 16),
              ],

              // VVVV NEW: Assessment Type Selection VVVV
              Text(
                'Assessment Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Standard Quiz'),
                      value: 'standard_quiz',
                      groupValue: _assessmentType,
                      onChanged: (String? value) {
                        setState(() {
                          _assessmentType = value!;
                          _questions
                              .clear(); // Clear questions when type changes
                          _promptTitleController
                              .clear(); // Clear speaking prompt when type changes
                          _promptTextController.clear();
                          _referenceTextController.clear();
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Speaking Assessment'),
                      value: 'speaking_assessment',
                      groupValue: _assessmentType,
                      onChanged: (String? value) {
                        setState(() {
                          _assessmentType = value!;
                          _questions.clear();
                          _promptTitleController.clear();
                          _promptTextController.clear();
                          _referenceTextController.clear();
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // VVVV START: Assessment Questions/Prompt Section VVVV
              if (_assessmentType == 'standard_quiz')
                _buildStandardQuizSection()
              else if (_assessmentType == 'speaking_assessment')
                _buildSpeakingAssessmentSection(),

              // ^^^^ END: Assessment Questions/Prompt Section ^^^^
              const SizedBox(height: 24),

              // Save Button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Build the Standard Quiz section
  Widget _buildStandardQuizSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAssessmentHeaderImagePicker(),
        const SizedBox(height: 20),
        _buildSubmissionDeadlinePicker(),
        const SizedBox(height: 24),
        Text(
          'Assessment Questions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        if (_questions.isEmpty)
          Text(
            'No questions added yet. Tap "Add Question" to start.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        if (_questions.isNotEmpty)
          ..._questions.asMap().entries.map((entry) {
            int index = entry.key;
            Question question = entry.value;
            return _buildQuestionCard(question, index);
          }).toList(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _addQuestion,
          icon: const Icon(Icons.add_circle, color: Colors.white),
          label: const Text(
            'Add Question',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  // NEW: Build the Speaking Assessment section
  Widget _buildSpeakingAssessmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAssessmentHeaderImagePicker(),
        const SizedBox(height: 20),
        _buildSubmissionDeadlinePicker(),
        const SizedBox(height: 24),
        Text(
          'Speaking Prompt',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _promptTitleController,
          onChanged: (value) {
            // ADD THIS: Trigger rebuild when text changes
            setState(() {
              _error = null;
            });
          },
          decoration: InputDecoration(
            labelText: 'Prompt Title *',
            hintText: 'Describe the situation the student needs to respond to.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.title),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a title for the prompt.';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _promptTextController,
          maxLines: 4,
          onChanged: (value) {
            // ADD THIS: Trigger rebuild when text changes
            setState(() {
              _error = null;
            });
          },
          decoration: InputDecoration(
            labelText: 'Prompt Text *',
            hintText: 'e.g., "Handling an Angry customer"',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
              child: Icon(Icons.chat_bubble_outline),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the prompt text.';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _referenceTextController,
          maxLines: 4,
          onChanged: (value) {
            // ADD THIS: Even for optional fields, trigger rebuild
            setState(() {});
          },
          decoration: InputDecoration(
            labelText: 'Reference Text for AI Review',
            hintText:
                'Provide an ideal or correct text response for the AI to compare against.',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
              child: Icon(Icons.mic),
            ),
          ),
        ),
      ],
    );
  }

  // Simplified save button
  Widget _buildSaveButton() {
    bool canSave =
        _titleController.text.trim().isNotEmpty &&
        (_selectedClassId != null || widget.classId != null);

    // Different validation for different assessment types
    if (_assessmentType == 'standard_quiz') {
      canSave = canSave && _questions.isNotEmpty;
    } else if (_assessmentType == 'speaking_assessment') {
      // For speaking assessments, check the form fields directly
      // NOTE: Deadline is NOT required for speaking assessments
      canSave =
          canSave &&
          _promptTitleController.text.trim().isNotEmpty &&
          _promptTextController.text.trim().isNotEmpty;
      // Removed any deadline requirement here
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                canSave ? FontAwesomeIcons.floppyDisk : FontAwesomeIcons.lock,
                size: 14,
              ),
        label: Text(
          _isLoading
              ? 'Saving...'
              : canSave
              ? 'Save Assessment'
              : 'Complete Required Fields',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onPressed: _isLoading ? null : (canSave ? _saveAssessment : null),
        style: ElevatedButton.styleFrom(
          backgroundColor: canSave ? const Color(0xFF8B5CF6) : Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canSave ? 2 : 0,
        ),
      ),
    );
  }

  Widget _buildAssessmentHeaderImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assessment Header Image (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        if (_assessmentHeaderImageUrl != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _assessmentHeaderImageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _removeHeaderImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: _isUploadingHeaderImage ? null : _pickHeaderImage,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: _isUploadingHeaderImage
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF8B5CF6),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FontAwesomeIcons.solidImage,
                            size: 30,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload Header Image',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          if (_headerImageError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _headerImageError!,
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmissionDeadlinePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submission Deadline (Optional)', // Make sure it says "Optional"
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: _deadline ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (pickedDate != null) {
              final TimeOfDay? pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(
                  _deadline ?? DateTime.now(),
                ),
              );
              if (pickedTime != null) {
                setState(() {
                  _deadline = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                });
              }
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Select Date and Time',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: const Icon(Icons.calendar_today),
              // NO validator here - deadline is optional
            ),
            child: Text(
              _deadline == null
                  ? 'No deadline set'
                  : _deadlineFmt.format(_deadline!),
              style: TextStyle(
                fontSize: 14,
                color: _deadline == null ? Colors.grey[600] : Colors.black,
              ),
            ),
          ),
        ),
        if (_deadline != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _deadline = null;
                });
              },
              icon: Icon(Icons.close, size: 16, color: Colors.red),
              label: Text(
                'Remove Deadline',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionsList() {
    return Column(
      children: List.generate(_questions.length, (index) {
        final q = _questions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => _editQuestion(index),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                FontAwesomeIcons.pencil,
                                size: 10,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _removeQuestion(index),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                FontAwesomeIcons.trash,
                                size: 10,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getShortQuestionType(q.type),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${q.points}pts',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (q.requiresReview) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Manual',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _getShortQuestionType(String type) {
    switch (type) {
      case 'multiple-choice':
        return 'MC';
      case 'fill-in-the-blank':
        return 'Fill';
      default:
        return 'Other';
    }
  }

  Widget _buildQuestionCard(Question question, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => _editQuestion(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            FontAwesomeIcons.pencil,
                            size: 10,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeQuestion(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            FontAwesomeIcons.trash,
                            size: 10,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getShortQuestionType(question.type),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${question.points}pts',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (question.requiresReview) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Manual',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyQuestionsState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _canAddQuestions
                  ? const Color(0xFF64748B).withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _canAddQuestions
                  ? FontAwesomeIcons.questionCircle
                  : FontAwesomeIcons.lock,
              size: 40,
              color: _canAddQuestions
                  ? const Color(0xFF64748B).withOpacity(0.6)
                  : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _canAddQuestions
                ? "Ready to add questions!"
                : "Complete basic information first",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _canAddQuestions
                  ? const Color(0xFF64748B)
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _canAddQuestions
                ? "Click 'Add Question' to create your first question"
                : "Fill in the assessment title and select a class to unlock questions",
            style: TextStyle(
              fontSize: 13,
              color: _canAddQuestions
                  ? const Color(0xFF64748B).withOpacity(0.8)
                  : const Color(0xFFF59E0B),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    bool hasValue = controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        enabled: !_isLoading,
        style: const TextStyle(fontSize: 14),
        onChanged: (value) {
          if (isRequired) {
            setState(() {
              _error = null;
            });
          }
        },
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(
            fontSize: 13,
            color: isRequired && !hasValue ? const Color(0xFFF59E0B) : null,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRequired && hasValue
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isRequired && hasValue ? FontAwesomeIcons.check : icon,
              color: isRequired && hasValue
                  ? const Color(0xFF10B981)
                  : const Color(0xFF8B5CF6),
              size: 16,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isRequired && !hasValue
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : Colors.grey[300]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isRequired && !hasValue
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isRequired && hasValue
                  ? const Color(0xFF10B981)
                  : const Color(0xFF8B5CF6),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isRequired && !hasValue
              ? const Color(0xFFFBBF24).withOpacity(0.05)
              : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          isDense: true,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildClassDropdown() {
    bool hasValue = _selectedClassId != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Select Class *',
          labelStyle: TextStyle(
            fontSize: 13,
            color: !hasValue ? const Color(0xFFF59E0B) : null,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasValue
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasValue
                  ? FontAwesomeIcons.check
                  : FontAwesomeIcons.chalkboardUser,
              color: hasValue
                  ? const Color(0xFF10B981)
                  : const Color(0xFF8B5CF6),
              size: 16,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: !hasValue
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : Colors.grey[300]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: !hasValue
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasValue
                  ? const Color(0xFF10B981)
                  : const Color(0xFF8B5CF6),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: !hasValue
              ? const Color(0xFFFBBF24).withOpacity(0.05)
              : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        value: _selectedClassId,
        items: _trainerClasses.map((cls) {
          return DropdownMenuItem<String>(
            value: cls['id'] as String,
            child: Text(cls['name'] as String),
          );
        }).toList(),
        onChanged: _isLoading
            ? null
            : (value) {
                setState(() {
                  _selectedClassId = value;
                  _error = null;
                });
              },
        validator: (value) => value == null ? 'Please select a class' : null,
      ),
    );
  }
}

class QuestionEditorDialog extends StatefulWidget {
  final Question? existingQuestion;
  final Function(Question) onSave;
  final VoidCallback onCancel;
  const QuestionEditorDialog({
    super.key,
    this.existingQuestion,
    required this.onSave,
    required this.onCancel,
  });
  @override
  State<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<QuestionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionTextController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _scenarioContextController =
      TextEditingController();
  final TextEditingController _textBeforeBlankController =
      TextEditingController();
  final TextEditingController _textAfterBlankController =
      TextEditingController();

  String _selectedType = 'multiple-choice';
  String _previousSelectedType = 'multiple-choice'; // NEW: Add this line
  List<String> _options = ['', '', '', ''];
  List<bool> _correctAnswers = [false, false, false, false];
  String _fillInInputMethod = 'typing';
  List<String> _acceptableAnswers = [''];
  final List<String> _questionTypes = ['multiple-choice', 'fill-in-the-blank'];
  final _imagePicker = ImagePicker();
  final _uuid = const Uuid();
  XFile? _currentQuestionXFile;
  String? _currentQuestionImageUrl;
  String? _currentQuestionImagePath;
  bool _isUploadingQuestionImage = false;
  String? _questionImageError;

  @override
  void initState() {
    super.initState();
    if (widget.existingQuestion != null) {
      _questionTextController.text = widget.existingQuestion!.text;
      _pointsController.text = widget.existingQuestion!.points.toString();
      _selectedType = widget.existingQuestion!.type;
      _currentQuestionImageUrl = widget.existingQuestion!.questionImageUrl;
      _currentQuestionImagePath = widget.existingQuestion!.questionImagePath;
      if (_selectedType == 'multiple-choice') {
        if (widget.existingQuestion!.options != null) {
          _options = List.from(widget.existingQuestion!.options!);
          while (_options.length < 4) {
            _options.add('');
          }
        }
        if (widget.existingQuestion!.correctAnswers != null) {
          _correctAnswers = List.filled(_options.length, false);
          for (int i = 0; i < _options.length; i++) {
            if (widget.existingQuestion!.correctAnswers!.contains(
              _options[i],
            )) {
              _correctAnswers[i] = true;
            }
          }
        }
      } else if (_selectedType == 'fill-in-the-blank') {
        _scenarioContextController.text =
            widget.existingQuestion!.scenarioContext ?? '';
        _textBeforeBlankController.text =
            widget.existingQuestion!.textBeforeBlank ?? '';
        _textAfterBlankController.text =
            widget.existingQuestion!.textAfterBlank ?? '';
        _fillInInputMethod =
            widget.existingQuestion!.fillInInputMethod ?? 'typing';
        if (widget.existingQuestion!.correctAnswers != null) {
          _acceptableAnswers = List.from(
            widget.existingQuestion!.correctAnswers!,
          );
        }
      }
    } else {
      _pointsController.text = '10';
    }
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _pointsController.dispose();
    _scenarioContextController.dispose();
    _textBeforeBlankController.dispose();
    _textAfterBlankController.dispose();
    super.dispose();
  }

  void _addAcceptableAnswer() {
    setState(() {
      _acceptableAnswers.add('');
    });
  }

  void _removeAcceptableAnswer(int index) {
    if (_acceptableAnswers.length > 1) {
      setState(() {
        _acceptableAnswers.removeAt(index);
      });
    }
  }

  void _addOption() {
    setState(() {
      _options.add('');
      _correctAnswers.add(false);
    });
  }

  void _removeOption(int index) {
    if (_options.length > 2) {
      setState(() {
        _options.removeAt(index);
        _correctAnswers.removeAt(index);
      });
    }
  }

  void _saveQuestion() {
    if (!_formKey.currentState!.validate()) return;
    List<String>? options;
    List<String>? correctAnswers;
    bool requiresReview = false;
    if (_selectedType == 'multiple-choice') {
      bool hasCorrectAnswer = false;
      for (int i = 0; i < _options.length; i++) {
        if (_options[i].trim().isNotEmpty && _correctAnswers[i]) {
          hasCorrectAnswer = true;
          break;
        }
      }
      if (!hasCorrectAnswer) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please mark at least one correct answer'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
      options = _options.where((o) => o.trim().isNotEmpty).toList();
      correctAnswers = [];
      for (int i = 0; i < _options.length; i++) {
        if (_options[i].trim().isNotEmpty && _correctAnswers[i]) {
          correctAnswers.add(_options[i].trim());
        }
      }
    } else if (_selectedType == 'fill-in-the-blank') {
      options = _fillInInputMethod == 'multiple-choice'
          ? _acceptableAnswers.where((a) => a.trim().isNotEmpty).toList()
          : null;
      correctAnswers = _acceptableAnswers
          .where((a) => a.trim().isNotEmpty)
          .toList();
      requiresReview = true;
    }
    final newQuestion = Question(
      id: widget.existingQuestion?.id ?? const Uuid().v4(),
      text: _questionTextController.text.trim(),
      type: _selectedType,
      options: options,
      correctAnswers: correctAnswers,
      points: int.tryParse(_pointsController.text.trim()) ?? 10,
      requiresReview: requiresReview,
      questionImageUrl: _currentQuestionImageUrl,
      questionImagePath: _currentQuestionImagePath,
      scenarioContext: _scenarioContextController.text.trim().isEmpty
          ? null
          : _scenarioContextController.text.trim(),
      textBeforeBlank: _textBeforeBlankController.text.trim().isEmpty
          ? null
          : _textBeforeBlankController.text.trim(),
      textAfterBlank: _textAfterBlankController.text.trim().isEmpty
          ? null
          : _textAfterBlankController.text.trim(),
      fillInInputMethod: _fillInInputMethod,
    );
    widget.onSave(newQuestion);
  }

  Future<Map<String, String>> _uploadXFileToStorage({
    required XFile xfile,
    required String basePath,
  }) async {
    final file = File(xfile.path);
    final ext = path.extension(xfile.path);
    final id = _uuid.v4();
    final storagePath = '$basePath/$id$ext';
    final ref = firebase_storage.FirebaseStorage.instance.ref(storagePath);
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    return {'url': url, 'path': storagePath};
  }

  Future<void> _deleteStorageFileIfAny(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      await firebase_storage.FirebaseStorage.instance.ref(storagePath).delete();
    } catch (_) {}
  }

  Future<void> _pickQuestionImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final size = await picked.length();
    if (size > 2 * 1024 * 1024) {
      setState(() {
        _questionImageError = 'File is too large. Max 2MB.';
        _currentQuestionXFile = null;
      });
      return;
    }
    setState(() {
      _currentQuestionXFile = picked;
      _isUploadingQuestionImage = true;
      _questionImageError = null;
    });
    if ((_currentQuestionImagePath ?? '').isNotEmpty) {
      await _deleteStorageFileIfAny(_currentQuestionImagePath);
    }
    final basePath = 'assessments/question_media/${const Uuid().v4()}';
    try {
      final res = await _uploadXFileToStorage(
        xfile: picked,
        basePath: basePath,
      );
      if (mounted) {
        setState(() {
          _currentQuestionImageUrl = res['url'];
          _currentQuestionImagePath = res['path'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _questionImageError = 'Failed to upload question image.';
          _currentQuestionXFile = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isUploadingQuestionImage = false);
    }
  }

  Future<void> _removeQuestionImage() async {
    setState(() => _isUploadingQuestionImage = true);
    await _deleteStorageFileIfAny(_currentQuestionImagePath);
    if (mounted) {
      setState(() {
        _isUploadingQuestionImage = false;
        _currentQuestionXFile = null;
        _currentQuestionImageUrl = null;
        _currentQuestionImagePath = null;
        _questionImageError = null;
      });
    }
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    bool hasValue = controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        onChanged: (value) {
          if (isRequired) {
            setState(() {
              // No error state to update in this scope, but a good practice
            });
          }
        },
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(
            fontSize: 13,
            color: isRequired && !hasValue ? const Color(0xFFF59E0B) : null,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRequired && hasValue
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isRequired && hasValue ? FontAwesomeIcons.check : icon,
              color: isRequired && hasValue
                  ? const Color(0xFF10B981)
                  : const Color(0xFF8B5CF6),
              size: 16,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isRequired && !hasValue
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : Colors.grey[300]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isRequired && !hasValue
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : Colors.grey[300]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isRequired && hasValue
                  ? const Color(0xFF10B981)
                  : const Color(0xFF8B5CF6),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isRequired && !hasValue
              ? const Color(0xFFFBBF24).withOpacity(0.05)
              : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          isDense: true,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildQuestionImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question Image (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        if (_currentQuestionImageUrl != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _currentQuestionImageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _removeQuestionImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: _isUploadingQuestionImage ? null : _pickQuestionImage,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[300]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: _isUploadingQuestionImage
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF8B5CF6),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FontAwesomeIcons.solidImage,
                            size: 24,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload Image',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          if (_questionImageError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _questionImageError!,
                              style: TextStyle(color: Colors.red, fontSize: 10),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Question Editor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _questionTextController,
                  label: 'Question Text',
                  icon: FontAwesomeIcons.question,
                  maxLines: 2,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Question text is required'
                      : null,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                _buildQuestionImagePicker(),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _pointsController,
                  label: 'Points',
                  icon: FontAwesomeIcons.star,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Points are required';
                    if (int.tryParse(value) == null) return 'Must be a number';
                    return null;
                  },
                  isRequired: true,
                ),
                const SizedBox(height: 24),
                _buildQuestionTypeSelector(),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final positionTween = Tween<Offset>(
                          begin: _selectedType == 'fill-in-the-blank'
                              ? const Offset(1.0, 0.0) // Slide from right
                              : const Offset(-1.0, 0.0), // Slide from left
                          end: Offset.zero,
                        );
                        return SlideTransition(
                          position: positionTween.animate(animation),
                          child: child,
                        );
                      },
                  child: _selectedType == 'multiple-choice'
                      ? _buildMultipleChoiceSection()
                      : _buildFillInTheBlankSection(),
                ),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _questionTypes.map((type) {
            final isSelected = _selectedType == type;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(
                    type.replaceAll('-', ' ').toUpperCase(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF8B5CF6),
                  backgroundColor: Colors.grey[100],
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _previousSelectedType =
                            _selectedType; // Update the previous type
                        _selectedType = type;
                      });
                    }
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceSection() {
    return Column(
      key: const ValueKey('multiple-choice-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Options & Correct Answers',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ..._options.asMap().entries.map((entry) {
          int index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Checkbox(
                  value: _correctAnswers[index],
                  onChanged: (bool? value) {
                    setState(() {
                      _correctAnswers[index] = value!;
                    });
                  },
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: _options[index],
                    onChanged: (value) {
                      _options[index] = value;
                    },
                    decoration: InputDecoration(
                      labelText: 'Option ${index + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) {
                      if (_options.where((o) => o.trim().isNotEmpty).length <
                          2) {
                        return 'At least two options are required.';
                      }
                      return null;
                    },
                  ),
                ),
                if (_options.length > 2)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _removeOption(index),
                  ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _addOption,
          icon: const Icon(Icons.add_circle),
          label: const Text('Add Option'),
        ),
      ],
    );
  }

  Widget _buildFillInTheBlankSection() {
    return Column(
      key: const ValueKey('fill-in-the-blank-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernTextField(
          controller: _scenarioContextController,
          label: 'Scenario Context (Optional)',
          icon: FontAwesomeIcons.book,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _textBeforeBlankController,
          label: 'Text Before Blank',
          icon: FontAwesomeIcons.alignLeft,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              '[ STUDENT FILLS BLANK HERE ]',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildModernTextField(
          controller: _textAfterBlankController,
          label: 'Text After Blank (Optional)',
          icon: FontAwesomeIcons.alignRight,
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        const Text(
          'Student Answer Input Method:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Typing'),
                value: 'typing',
                groupValue: _fillInInputMethod,
                onChanged: (String? value) {
                  setState(() {
                    _fillInInputMethod = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Multiple Choice'),
                value: 'multiple-choice',
                groupValue: _fillInInputMethod,
                onChanged: (String? value) {
                  setState(() {
                    _fillInInputMethod = value!;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_fillInInputMethod == 'typing' ||
            _fillInInputMethod == 'multiple-choice')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fillInInputMethod == 'typing'
                    ? 'Acceptable Typed Answer(s) for the Blank'
                    : 'Options for the Blank',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              ..._acceptableAnswers.asMap().entries.map((entry) {
                int index = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _acceptableAnswers[index],
                          onChanged: (value) {
                            _acceptableAnswers[index] = value;
                          },
                          decoration: InputDecoration(
                            labelText:
                                '${_fillInInputMethod == 'typing' ? 'Answer' : 'Option'} ${index + 1}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (value) =>
                              _acceptableAnswers
                                  .where((a) => a.trim().isNotEmpty)
                                  .isEmpty
                              ? 'At least one answer is required.'
                              : null,
                        ),
                      ),
                      if (_acceptableAnswers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _removeAcceptableAnswer(index),
                        ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addAcceptableAnswer,
                icon: const Icon(Icons.add_circle),
                label: const Text('Add Answer'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveQuestion,
        child: Text(
          widget.existingQuestion == null ? 'Add Question' : 'Save Changes',
        ),
      ),
    );
  }
}
