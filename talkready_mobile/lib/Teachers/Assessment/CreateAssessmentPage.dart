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
import 'package:talkready_mobile/Teachers/Assessment/ClassAssessmentsListPage.dart';
import 'package:talkready_mobile/Teachers/Assessment/ViewAssessmentResultsPage.dart';

// Define a simple Question model
class Question {
  String id;
  String text;
  String type; // e.g., 'multiple-choice', 'fill-in-the-blank'
  List<String>? options; // For multiple-choice
  List<String>? correctAnswers; // Can be single or multiple
  int points;
  bool requiresReview; // NEW: Add this field

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    this.correctAnswers,
    this.points = 10,
    this.requiresReview = false, // NEW: Default to false
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'options': options,
      'correctAnswers': correctAnswers,
      'points': points,
      'requiresReview': requiresReview, // NEW: Include in map
    };
  }
}

class CreateAssessmentPage extends StatefulWidget {
  final String? classId;
  final String? initialClassId;
  const CreateAssessmentPage({super.key, this.classId, this.initialClassId});

  @override
  State<CreateAssessmentPage> createState() => _CreateAssessmentPageState();
}

class _CreateAssessmentPageState extends State<CreateAssessmentPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

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
  String? get _deadlineDisplay => _deadline == null ? null : _deadlineFmt.format(_deadline!);

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    if (widget.classId == null && widget.initialClassId == null) {
      _fetchTrainerClasses();
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
    super.dispose();
  }

  Future<void> _fetchTrainerClasses() async {
    if (currentUser == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('trainerId', isEqualTo: currentUser!.uid)
          .get();
      setState(() {
        _trainerClasses = snapshot.docs.map((doc) => {
          'id': doc.id, 
          'name': doc.data()['className'] ?? 'Unnamed Class'
        }).toList();
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load classes: ${e.toString()}";
      });
    }
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
                Text(
                  'Complete Basic Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewAssessmentResultsPage(
          assessmentId: assessmentId,
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
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
      final res = await _uploadXFileToStorage(xfile: picked, basePath: basePath);
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
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
      final res = await _uploadXFileToStorage(xfile: picked, basePath: basePath);
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
    return {
      'trainerId': currentUser?.uid,
      'classId': _selectedClassId ?? widget.classId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'assessmentType': _assessmentType,
      'status': 'published',
      'deadline': _deadline?.toIso8601String(),
      if (_assessmentHeaderImageUrl != null) 'assessmentHeaderImageUrl': _assessmentHeaderImageUrl,
      if (_assessmentHeaderImagePath != null) 'assessmentHeaderImagePath': _assessmentHeaderImagePath,
      'questions': _questions
          .map((q) => q.toMap()
            ..addAll({
              // If you attach per-question images from your editor, merge them here
              if (_currentQuestionImageUrl != null) 'questionImageUrl': _currentQuestionImageUrl,
              if (_currentQuestionImagePath != null) 'questionImagePath': _currentQuestionImagePath,
            }))
          .toList(),
    };
  }

  // Example save using payload
  Future<void> _saveAssessment() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_selectedClassId ?? widget.classId) == null) {
      setState(() => _error = 'Please select a class.');
      return;
    }
    if (_questions.isEmpty) {
      setState(() => _error = 'Please add at least one question.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      final data = _buildAssessmentPayload();
      final docRef = await FirebaseFirestore.instance.collection('trainerAssessments').add(data);
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
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    FontAwesomeIcons.checkCircle,
                    color: const Color(0xFF10B981),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Assessment created successfully!\nWhat would you like to do next?',
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context, true);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Go Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToViewResults(assessmentId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('View Results'),
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
      iconTheme: const IconThemeData(color: Colors.white), // Changed to white
      title: const Text(
        'Create Assessment',
        style: TextStyle(
          color: Colors.white, // Changed to white
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.list_alt_rounded, color: Colors.white), // Changed to white
          tooltip: 'View Assessments',
          onPressed: _navigateToAssessmentsList,
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF8B5CF6),
              Color(0xFF6366F1),
            ], // Changed to match the original background gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  // Update the _buildBackgroundGradient method:
  BoxDecoration _buildBackgroundGradient() {
    return const BoxDecoration(
      color: Colors.white, // Changed to solid white
    );
  }

  // NEW: Progress indicator showing completion status
  Widget _buildProgressIndicator() {
    bool titleComplete = _titleController.text.trim().isNotEmpty;
    bool classComplete = _selectedClassId != null || widget.classId != null;
    bool questionsComplete = _questions.isNotEmpty;
    
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
              _buildProgressStep('Questions', questionsComplete, classComplete),
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
      color: isComplete 
          ? const Color(0xFF10B981)
          : Colors.grey[300],
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
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                isRequired: true, // NEW: Mark as required
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

              // Questions Section (updated with validation)
              _buildQuestionsSection(),
              
              const SizedBox(height: 24),

              // Save Button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // Simplified save button
  Widget _buildSaveButton() {
    bool canSave = _titleController.text.trim().isNotEmpty && 
                  (_selectedClassId != null || widget.classId != null) &&
                  _questions.isNotEmpty;
    
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
                  : 'Locked',
          style: const TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 14,
          ),
        ),
        onPressed: _isLoading 
            ? null 
            : canSave 
                ? _saveAssessment
                : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSave 
              ? const Color(0xFF8B5CF6)
              : Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canSave ? 2 : 0,
        ),
      ),
    );
  }

  Widget _buildQuestionsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _canAddQuestions 
            ? const Color(0xFF8B5CF6).withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canAddQuestions 
              ? const Color(0xFF8B5CF6).withOpacity(0.2)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Simple header
          Row(
            children: [
              Icon(
                FontAwesomeIcons.questionCircle,
                color: _canAddQuestions 
                    ? const Color(0xFF8B5CF6)
                    : Colors.grey[400],
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Questions (${_questions.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _canAddQuestions 
                        ? const Color(0xFF1E293B)
                        : Colors.grey[600],
                  ),
                ),
              ),
              // Simple add button
              GestureDetector(
                onTap: _canAddQuestions ? _addQuestion : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _canAddQuestions 
                        ? const Color(0xFF10B981)
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _canAddQuestions 
                            ? FontAwesomeIcons.plus 
                            : FontAwesomeIcons.lock,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (_questions.isEmpty)
            _buildEmptyQuestionsState()
          else
            _buildQuestionsList(),
        ],
      ),
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
                // Simple header row
                Row(
                  children: [
                    // Question number
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
                    // Question text - takes available space
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
                    // Action buttons - fixed width
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
                
                // Compact info row
                Row(
                  children: [
                    // Type
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    // Points
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    // Review indicator
                    if (q.requiresReview) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

  // Simplified type names
  String _getShortQuestionType(String type) {
    switch (type) {
      case 'multiple-choice':
        return 'MC';
      case 'true-false':
        return 'T/F';
      case 'fill-in-the-blank':
        return 'Fill';
      case 'short-answer':
        return 'Short';
      default:
        return 'Other';
    }
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

  // Also update the text field method to include real-time validation
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
          // Update state when title or class changes to enable/disable questions
          if (isRequired) {
            setState(() {
              _error = null; // Clear errors when user starts typing
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          isDense: true,
        ),
        validator: validator,
      ),
    );
  }

  // Enhanced class dropdown with visual indicators
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
              hasValue ? FontAwesomeIcons.check : FontAwesomeIcons.chalkboardUser,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        value: _selectedClassId,
        items: _trainerClasses.map((cls) {
          return DropdownMenuItem<String>(
            value: cls['id'] as String,
            child: Text(cls['name'] as String),
          );
        }).toList(),
        onChanged: _isLoading ? null : (value) {
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

// Modern Question Editor Dialog with overflow prevention
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
  final TextEditingController _fillInAnswersController = TextEditingController();
  final TextEditingController _shortAnswerSampleController = TextEditingController();
  
  // NEW: Add controllers for advanced fill-in-the-blank features
  final TextEditingController _scenarioContextController = TextEditingController();
  final TextEditingController _textBeforeBlankController = TextEditingController();
  final TextEditingController _textAfterBlankController = TextEditingController();
  
  String _selectedType = 'multiple-choice';
  List<String> _options = ['', '', '', ''];
  List<bool> _correctAnswers = [false, false, false, false];
  
  // NEW: Add variables for fill-in-the-blank input method
  String _fillInInputMethod = 'typing'; // 'typing' or 'multiple-choice'
  List<String> _acceptableAnswers = [''];
  
  final List<String> _questionTypes = [
    'multiple-choice',
    'true-false',
    'fill-in-the-blank',
    'short-answer',
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.existingQuestion != null) {
      _questionTextController.text = widget.existingQuestion!.text;
      _pointsController.text = widget.existingQuestion!.points.toString();
      _selectedType = widget.existingQuestion!.type;
      
      if (widget.existingQuestion!.options != null) {
        _options = List.from(widget.existingQuestion!.options!);
        while (_options.length < 4) {
          _options.add('');
        }
      }
      
      if (widget.existingQuestion!.correctAnswers != null) {
        for (int i = 0; i < _options.length && i < _correctAnswers.length; i++) {
          _correctAnswers[i] = widget.existingQuestion!.correctAnswers!.contains(_options[i]);
        }
      }
      
      if (_selectedType == 'fill-in-the-blank' && widget.existingQuestion!.correctAnswers != null) {
        _acceptableAnswers = List.from(widget.existingQuestion!.correctAnswers!);
        // You can also load additional metadata if stored in the question
      }
      
      if (_selectedType == 'short-answer' && widget.existingQuestion!.correctAnswers != null) {
        _shortAnswerSampleController.text = widget.existingQuestion!.correctAnswers!.first;
      }
    } else {
      _pointsController.text = '10';
    }
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _pointsController.dispose();
    _fillInAnswersController.dispose();
    _shortAnswerSampleController.dispose();
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

    // Validate that at least one correct answer is selected for multiple choice
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    List<String>? options;
    List<String>? correctAnswers;
    bool requiresReview = false; // NEW: Initialize review flag

    if (_selectedType == 'multiple-choice') {
      options = _options.where((opt) => opt.trim().isNotEmpty).toList();
      correctAnswers = [];
      for (int i = 0; i < _options.length; i++) {
        if (_options[i].trim().isNotEmpty && _correctAnswers[i]) {
          correctAnswers.add(_options[i].trim());
        }
      }
    } else if (_selectedType == 'true-false') {
      options = ['True', 'False'];
      correctAnswers = _correctAnswers[0] ? ['True'] : ['False'];
    } else if (_selectedType == 'fill-in-the-blank') {
      // NEW: Updated logic for advanced fill-in-the-blank
      List<String> answers = _acceptableAnswers
          .where((answer) => answer.trim().isNotEmpty)
          .map((answer) => answer.trim())
          .toList();
      
      if (answers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please provide at least one acceptable answer'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
      
      correctAnswers = answers;
      
      // If using multiple choice for fill-in-blank, set options
      if (_fillInInputMethod == 'multiple-choice') {
        options = List.from(answers);
        // Add some wrong options for multiple choice
        options.addAll(['Wrong Answer 1', 'Wrong Answer 2']);
      }
    } else if (_selectedType == 'short-answer') {
      // NEW: Short answers always require manual review
      requiresReview = true;
      correctAnswers = _shortAnswerSampleController.text.trim().isNotEmpty 
          ? [_shortAnswerSampleController.text.trim()] 
          : ['[Sample answer for grading reference]'];
    }

    final question = Question(
      id: widget.existingQuestion?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: _questionTextController.text.trim(),
      type: _selectedType,
      options: options,
      correctAnswers: correctAnswers,
      points: int.tryParse(_pointsController.text) ?? 10,
      requiresReview: requiresReview, // NEW: Set review flag
    );

    widget.onSave(question);
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for better responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 40 : 16,
        vertical: 20,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight - 40, // More conservative height
          maxWidth: screenWidth > 600 ? 600 : screenWidth,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important: Let content determine size
          children: [
            // Header - Fixed at top
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6),
                    const Color(0xFF6366F1),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.existingQuestion != null 
                          ? FontAwesomeIcons.pencil 
                          : FontAwesomeIcons.plus,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.existingQuestion != null ? 'Edit Question' : 'Add New Question',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Create engaging questions',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(
                      FontAwesomeIcons.xmark,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            
            // Form Content - Flexible scrollable section
            Flexible( // Changed from Expanded to Flexible
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20, 
                    16, 
                    20, 
                    keyboardHeight > 0 ? 16 : 8, // Adjust for keyboard
                  ),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min, // Important for responsive height
                    children: [
                      // Question Type
                      _buildCompactDialogSection(
                        title: 'Question Type',
                        icon: FontAwesomeIcons.listCheck,
                        color: const Color(0xFF3B82F6),
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: _buildCompactInputDecoration(),
                          items: _questionTypes.map((type) {
                            String displayName = type.split('-').map((word) => 
                              word[0].toUpperCase() + word.substring(1)
                            ).join(' ');
                            
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(displayName, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                              if (_selectedType == 'true-false') {
                                _options = ['True', 'False'];
                                _correctAnswers = [false, false];
                              } else if (_selectedType == 'multiple-choice') {
                                _options = ['', '', '', ''];
                                _correctAnswers = [false, false, false, false];
                              } else if (_selectedType == 'fill-in-the-blank') {
                                _options = [];
                                _correctAnswers = [false, false, false, false];
                                _acceptableAnswers = [''];
                              } else if (_selectedType == 'short-answer') {
                                _options = [];
                                _correctAnswers = [false, false, false, false];
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Question Text
                      _buildCompactDialogSection(
                        title: 'Question Text *',
                        icon: FontAwesomeIcons.questionCircle,
                        color: const Color(0xFF10B981),
                        child: TextFormField(
                          controller: _questionTextController,
                          decoration: _buildCompactInputDecoration(
                            hintText: 'Enter your question here...',
                          ),
                          maxLines: 2, // Reduced from 3 to 2
                          style: const TextStyle(fontSize: 14),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Question text is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Options for multiple choice and true/false
                      if (_selectedType == 'multiple-choice' || _selectedType == 'true-false') ...[
                        _buildCompactDialogSection(
                          title: 'Answer Options *',
                          icon: FontAwesomeIcons.listOl,
                          color: const Color(0xFFF59E0B),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedType == 'true-false')
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCompactCheckboxOption('True', 0),
                                    const SizedBox(height: 6),
                                    _buildCompactCheckboxOption('False', 1),
                                  ],
                                )
                              else
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...List.generate(_options.length, (index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: _buildCompactOptionField(index),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(FontAwesomeIcons.plus, size: 10),
                                        label: const Text('Add Option', style: TextStyle(fontSize: 12)),
                                        onPressed: _addOption,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          minimumSize: const Size(0, 32),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // NEW: Advanced Fill-in-the-blank sections
                      if (_selectedType == 'fill-in-the-blank') ...[
                        // Scenario Context - Compact version
                        _buildCompactDialogSection(
                          title: 'Context (Optional)',
                          icon: FontAwesomeIcons.fileText,
                          color: const Color(0xFF8B5CF6),
                          child: TextFormField(
                            controller: _scenarioContextController,
                            decoration: _buildCompactInputDecoration(
                              hintText: 'e.g., Customer says: ...',
                            ),
                            maxLines: 2, // Reduced from 3
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Text Before Blank - Compact version
                        _buildCompactDialogSection(
                          title: 'Text Before Blank (Optional)',
                          icon: FontAwesomeIcons.alignLeft,
                          color: const Color(0xFF3B82F6),
                          child: TextFormField(
                            controller: _textBeforeBlankController,
                            decoration: _buildCompactInputDecoration(
                              hintText: 'e.g., I can certainly...',
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Visual blank representation - Compact
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '--- [BLANK] ---',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Text After Blank - Compact version
                        _buildCompactDialogSection(
                          title: 'Text After Blank (Optional)',
                          icon: FontAwesomeIcons.alignRight,
                          color: const Color(0xFF3B82F6),
                          child: TextFormField(
                            controller: _textAfterBlankController,
                            decoration: _buildCompactInputDecoration(
                              hintText: 'e.g., ...for you.',
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Student Answer Input Method - Compact
                        _buildCompactDialogSection(
                          title: 'Input Method',
                          icon: FontAwesomeIcons.keyboard,
                          color: const Color(0xFFF59E0B),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCompactRadioTile('Typing', 'Students type answer', 'typing'),
                              _buildCompactRadioTile('Multiple Choice', 'Students select option', 'multiple-choice'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Acceptable Answers - Compact version
                        _buildCompactDialogSection(
                          title: 'Acceptable Answers *',
                          icon: FontAwesomeIcons.checkCircle,
                          color: const Color(0xFF10B981),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enter acceptable answers',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(_acceptableAnswers.length, (index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: _acceptableAnswers[index],
                                          decoration: _buildCompactInputDecoration(
                                            hintText: 'Answer ${index + 1}',
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          onChanged: (value) {
                                            _acceptableAnswers[index] = value;
                                          },
                                          validator: (value) {
                                            if (index == 0 && (value == null || value.trim().isEmpty)) {
                                              return 'Required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      if (_acceptableAnswers.length > 1) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(
                                            FontAwesomeIcons.trash,
                                            color: Colors.red[400],
                                            size: 12,
                                          ),
                                          onPressed: () => _removeAcceptableAnswer(index),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(FontAwesomeIcons.plus, size: 12),
                                  label: const Text('Add Answer', style: TextStyle(fontSize: 12)),
                                  onPressed: _addAcceptableAnswer,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    minimumSize: const Size(0, 32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Short-answer section - IMPROVED
                      if (_selectedType == 'short-answer') ...[
                        _buildCompactDialogSection(
                          title: 'Grading Info (Optional)',
                          icon: FontAwesomeIcons.lightbulb,
                          color: const Color(0xFF3B82F6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFBBF24).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      FontAwesomeIcons.circleInfo,
                                      color: const Color(0xFFFBBF24),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Requires manual review',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFFF59E0B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _shortAnswerSampleController,
                                decoration: _buildCompactInputDecoration(
                                  hintText: 'Grading criteria or sample answer...',
                                ),
                                maxLines: 3,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Points - Compact version
                      _buildCompactDialogSection(
                        title: 'Points',
                        icon: FontAwesomeIcons.star,
                        color: const Color(0xFFEF4444),
                        child: SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _pointsController,
                            decoration: _buildCompactInputDecoration(hintText: '10'),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      
                      // Add extra bottom padding for keyboard
                      SizedBox(height: keyboardHeight > 0 ? 60 : 20),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons - Fixed at bottom
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(FontAwesomeIcons.floppyDisk, size: 14),
                      label: const Text('Save Question', style: TextStyle(fontSize: 14)),
                      onPressed: _saveQuestion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Compact helper methods to reduce space usage
  Widget _buildCompactDialogSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10), // Reduced from 12
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4), // Reduced from 6
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 14), // Reduced from 16
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                  fontSize: 13, // Reduced font size
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Reduced from 12
          child,
        ],
      ),
    );
  }

  InputDecoration _buildCompactInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6), // Reduced from 8
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(10), // Reduced from 12
      isDense: true, // Makes the field more compact
    );
  }

  Widget _buildCompactCheckboxOption(String title, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedType == 'true-false') {
            _correctAnswers = [false, false];
            _correctAnswers[index] = true;
          } else {
            _correctAnswers[index] = !_correctAnswers[index];
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(10), // Reduced from 12
        decoration: BoxDecoration(
          color: _correctAnswers[index] ? const Color(0xFF10B981).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _correctAnswers[index] ? const Color(0xFF10B981) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18, // Reduced from 20
              height: 18,
              decoration: BoxDecoration(
                color: _correctAnswers[index] ? const Color(0xFF10B981) : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: _correctAnswers[index] ? const Color(0xFF10B981) : Colors.grey[400]!,
                ),
              ),
              child: _correctAnswers[index]
                  ? const Icon(FontAwesomeIcons.check, color: Colors.white, size: 10)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              title, 
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactOptionField(int index) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _correctAnswers[index] = !_correctAnswers[index];
            });
          },
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _correctAnswers[index] ? const Color(0xFF10B981) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _correctAnswers[index] ? const Color(0xFF10B981) : Colors.grey[400]!,
              ),
            ),
            child: _correctAnswers[index]
                ? const Icon(FontAwesomeIcons.check, color: Colors.white, size: 10)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            initialValue: _options[index],
            decoration: _buildCompactInputDecoration(hintText: 'Option ${index + 1}'),
            style: const TextStyle(fontSize: 14),
            onChanged: (value) {
              _options[index] = value;
            },
            validator: (value) {
              if (index < 2 && (value == null || value.trim().isEmpty)) {
                return 'Required';
              }
              return null;
            },
          ),
        ),
        if (_options.length > 2) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(FontAwesomeIcons.trash, color: Colors.red[400], size: 12),
            onPressed: () => _removeOption(index),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactRadioTile(String title, String subtitle, String value) {
    return InkWell(
      onTap: () {
        setState(() {
          _fillInInputMethod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _fillInInputMethod == value ? const Color(0xFF8B5CF6) : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: _fillInInputMethod == value
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}