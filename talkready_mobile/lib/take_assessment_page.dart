import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'firebase_service.dart';

class TakeAssessmentPage extends StatefulWidget {
  final String assessmentId;
  final String? classId; // Optional, for navigation back

  const TakeAssessmentPage({
    super.key,
    required this.assessmentId,
    this.classId,
  });

  @override
  State<TakeAssessmentPage> createState() => _TakeAssessmentPageState();
}

class _TakeAssessmentPageState extends State<TakeAssessmentPage>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // State variables
  Map<String, dynamic>? assessment;
  Map<String, dynamic> answers = {};
  bool loading = true;
  bool isSubmitting = false;
  bool hasAlreadySubmitted = false;
  bool isDeadlinePassed = false;
  String error = '';
  String? existingSubmissionId;
  Map<String, dynamic>? submissionResult;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchAssessmentAndCheckSubmission();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchAssessmentAndCheckSubmission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        error = "Please log in to take an assessment.";
        loading = false;
      });
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      // Check if student has already submitted
      await _checkIfAlreadySubmitted(user.uid);

      if (hasAlreadySubmitted) {
        // Fetch minimal assessment data for display
        final assessmentData = await _firebaseService.getAssessmentDetails(
          widget.assessmentId,
        );
        setState(() {
          assessment = assessmentData;
          loading = false;
        });
        return;
      }

      // Fetch full assessment data
      final assessmentData = await _firebaseService.getAssessmentDetails(
        widget.assessmentId,
      );

      if (assessmentData == null) {
        setState(() {
          error = "Assessment not found or could not be loaded.";
          loading = false;
        });
        return;
      }

      // Check deadline
      if (assessmentData['deadline'] != null) {
        final deadline = (assessmentData['deadline'] as Timestamp).toDate();
        final now = DateTime.now();
        if (now.isAfter(deadline)) {
          setState(() {
            isDeadlinePassed = true;
            error =
                "This assessment was due on ${_formatDateTime(deadline)}. The deadline has passed.";
            assessment = assessmentData;
            loading = false;
          });
          return;
        }
      }

      // Initialize answers
      _initializeAnswers(assessmentData);

      setState(() {
        assessment = assessmentData;
        loading = false;
      });

      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      _logger.e("Error fetching assessment: $e");
      setState(() {
        error = "Failed to load assessment. Please try again.";
        loading = false;
      });
    }
  }

  Future<void> _checkIfAlreadySubmitted(String studentId) async {
    try {
      final submissionQuery = await _firestore
          .collection('studentSubmissions')
          .where('studentId', isEqualTo: studentId)
          .where('assessmentId', isEqualTo: widget.assessmentId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();

      if (submissionQuery.docs.isNotEmpty) {
        setState(() {
          hasAlreadySubmitted = true;
          existingSubmissionId = submissionQuery.docs.first.id;
        });
      }
    } catch (e) {
      _logger.e("Error checking submission status: $e");
      // Continue without blocking if this fails
    }
  }

  void _initializeAnswers(Map<String, dynamic> assessmentData) {
    final questions = assessmentData['questions'] as List?;
    if (questions == null) return;

    Map<String, dynamic> initialAnswers = {};

    for (var question in questions) {
      final questionId = question['questionId'];
      final type = question['type'];

      if (type == 'multiple-choice') {
        final correctOptions = question['correctOptionIds'] as List?;
        if (correctOptions != null && correctOptions.length > 1) {
          // Multi-select
          initialAnswers[questionId] = <String>[];
        } else {
          // Single select
          initialAnswers[questionId] = null;
        }
      } else if (type == 'fill-in-the-blank') {
        final answerMode = question['answerInputMode'];
        if (answerMode == 'multipleChoice') {
          initialAnswers[questionId] = null;
        } else {
          initialAnswers[questionId] = '';
        }
      }
    }

    setState(() {
      answers = initialAnswers;
    });
  }

  void _handleMCQAnswer(
    String questionId,
    String optionId,
    bool isMultiSelect,
  ) {
    if (isDeadlinePassed || hasAlreadySubmitted) return;

    setState(() {
      if (isMultiSelect) {
        final currentList = List<String>.from(answers[questionId] ?? []);
        if (currentList.contains(optionId)) {
          currentList.remove(optionId);
        } else {
          currentList.add(optionId);
        }
        answers[questionId] = currentList;
      } else {
        answers[questionId] = optionId;
      }
    });
  }

  void _handleFITBAnswer(String questionId, String value) {
    if (isDeadlinePassed || hasAlreadySubmitted) return;

    setState(() {
      answers[questionId] = value;
    });
  }

  Future<void> _submitAssessment() async {
    if (hasAlreadySubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already submitted this assessment.'),
        ),
      );
      return;
    }

    if (isDeadlinePassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot submit, the deadline has passed.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || assessment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot submit. Please try again.')),
      );
      return;
    }

    // Check if all questions are answered
    final questions = assessment!['questions'] as List;
    int answeredCount = 0;

    for (var question in questions) {
      final questionId = question['questionId'];
      final answer = answers[questionId];

      if (question['type'] == 'multiple-choice') {
        final isMultiSelect =
            (question['correctOptionIds'] as List?)?.length != null &&
            (question['correctOptionIds'] as List).length > 1;
        if (isMultiSelect) {
          if (answer is List && answer.isNotEmpty) answeredCount++;
        } else {
          if (answer != null) answeredCount++;
        }
      } else if (question['type'] == 'fill-in-the-blank') {
        if (question['answerInputMode'] == 'multipleChoice') {
          if (answer != null) answeredCount++;
        } else {
          if (answer != null && answer.toString().trim().isNotEmpty)
            answeredCount++;
        }
      }
    }

    if (answeredCount < questions.length) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incomplete Assessment'),
          content: Text(
            'You have answered $answeredCount out of ${questions.length} questions. '
            'Are you sure you want to submit?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continue Answering'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit Anyway'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }

    setState(() {
      isSubmitting = true;
      error = '';
    });

    try {
      final result = await _submitToFirebase(user.uid);
      setState(() {
        submissionResult = result;
        isSubmitting = false;
      });
    } catch (e) {
      _logger.e("Error submitting assessment: $e");
      setState(() {
        error = "Failed to submit assessment. Please try again.";
        isSubmitting = false;
      });
    }
  }
  Future<Map<String, dynamic>> _submitToFirebase(String studentId) async {
    // Get student details
    String studentName = "Unknown Student";
    String studentEmail = "No email";

    try {
      final userDoc = await _firestore.collection('users').doc(studentId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        studentName =
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        if (studentName.isEmpty) {
          studentName = userData['displayName'] ?? "Unknown Student";
        }
        studentEmail = userData['email'] ?? "No email";
      }
    } catch (e) {
      _logger.w("Could not fetch student details: $e");
    }

    // Calculate score
    int totalScore = 0;
    int totalPossiblePoints = 0;
    List<Map<String, dynamic>> processedAnswers = [];

    final questions = assessment!['questions'] as List;

    for (var question in questions) {
      final questionPoints = (question['points'] ?? 0) as int;
      totalPossiblePoints += questionPoints;

      final questionId = question['questionId'];
      final studentAnswer = answers[questionId];
      bool isCorrect = false;
      int pointsEarned = 0;

      Map<String, dynamic> answerDetail = {
        'questionId': questionId,
        'type': question['type'],
        'pointsEarned': 0,
        'isCorrect': false,
      };

      if (question['type'] == 'multiple-choice') {
        final correctIds = List<String>.from(
          question['correctOptionIds'] ?? [],
        );
        final isMultiSelect = correctIds.length > 1;

        if (isMultiSelect) {
          final selectedIds = List<String>.from(studentAnswer ?? []);
          answerDetail['selectedOptionIds'] = selectedIds;

          if (selectedIds.length == correctIds.length &&
              selectedIds.every((id) => correctIds.contains(id))) {
            isCorrect = true;
          }
        } else {
          answerDetail['selectedOptionId'] = studentAnswer;
          if (studentAnswer != null && correctIds.contains(studentAnswer)) {
            isCorrect = true;
          }
        }
      } else if (question['type'] == 'fill-in-the-blank') {
        answerDetail['answerInputMode'] = question['answerInputMode'];

        if (question['answerInputMode'] == 'multipleChoice') {
          answerDetail['selectedOptionId'] = studentAnswer;
          if (studentAnswer != null &&
              studentAnswer == question['correctOptionIdForFITB']) {
            isCorrect = true;
          }
        } else {
          final studentTypedAnswer = (studentAnswer ?? '')
              .toString()
              .trim()
              .toLowerCase();
          answerDetail['studentAnswer'] = studentAnswer ?? '';

          final correctAnswers = List<String>.from(
            question['correctAnswers'] ?? [],
          );
          if (correctAnswers.any(
            (ans) => ans.trim().toLowerCase() == studentTypedAnswer,
          )) {
            isCorrect = true;
          }
        }
      }

      if (isCorrect) {
        pointsEarned = questionPoints;
        totalScore += pointsEarned;
      }

      answerDetail['isCorrect'] = isCorrect;
      answerDetail['pointsEarned'] = pointsEarned;
      processedAnswers.add(answerDetail);
    }

    // Submit to Firestore
    final submissionData = {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'assessmentId': widget.assessmentId,
      'classId': assessment!['classId'],
      'trainerId': assessment!['trainerId'],
      'assessmentType': assessment!['assessmentType'] ?? 'standard_quiz',
      'submittedAt': FieldValue.serverTimestamp(),
      'answers': processedAnswers,
      'score': totalScore,
      'totalPossiblePoints': totalPossiblePoints,
      'isReviewed': true,
    };

    final submissionRef = await _firestore
        .collection('studentSubmissions')
        .add(submissionData);

    return {
      'submissionId': submissionRef.id,
      'score': totalScore,
      'totalPossiblePoints': totalPossiblePoints,
      'message': 'Assessment submitted successfully!',
    };
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Show already submitted screen
    if (hasAlreadySubmitted && !loading) {
      return _buildAlreadySubmittedScreen();
    }

    // Show deadline passed screen
    if (isDeadlinePassed && !loading) {
      return _buildDeadlinePassedScreen();
    }

    // Show submission result screen
    if (submissionResult != null) {
      return _buildSubmissionResultScreen();
    }

    // Show main assessment screen
    return Scaffold(
      appBar: AppBar(
        title: Text(assessment?['title'] ?? 'Assessment'),
        backgroundColor: const Color(0xFF0077B3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? _buildLoadingScreen()
          : error.isNotEmpty
          ? _buildErrorScreen()
          : _buildAssessmentContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0077B3)),
          SizedBox(height: 16),
          Text('Loading Assessment...'),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.exclamationTriangle,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Error Loading Assessment',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const FaIcon(FontAwesomeIcons.arrowLeft),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadySubmittedScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Already Taken'),
        backgroundColor: const Color(0xFF0077B3),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.checkCircle,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Assessment Already Taken',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0077B3),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You have already submitted this assessment${assessment?['title'] != null ? ' ("${assessment!['title']}")' : ''}. You can review your previous submission.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (existingSubmissionId != null) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to review submission (implement this later)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Submission review coming soon!'),
                      ),
                    );
                  },
                  icon: const FaIcon(FontAwesomeIcons.eye),
                  label: const Text('Review Your Submission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0077B3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const FaIcon(FontAwesomeIcons.arrowLeft),
                label: const Text('Back to Class'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlinePassedScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Closed'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.lock,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              const Text(
                'Assessment Closed',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const FaIcon(FontAwesomeIcons.arrowLeft),
                label: const Text('Back to Class'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionResultScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Submitted'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.checkCircle,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Assessment Submitted!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              if (submissionResult!['message'] != null)
                Text(
                  submissionResult!['message'],
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your Score',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0077B3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${submissionResult!['score']} / ${submissionResult!['totalPossiblePoints']}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0077B3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to review submission (implement this later)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Review feature coming soon!'),
                        ),
                      );
                    },
                    icon: const FaIcon(FontAwesomeIcons.eye),
                    label: const Text('Review Your Answers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0077B3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const FaIcon(FontAwesomeIcons.arrowLeft),
                    label: const Text('Back to Class'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
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

  Widget _buildAssessmentContent() {
    if (assessment == null) return Container();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          onRefresh: _fetchAssessmentAndCheckSubmission,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assessment Header
                _buildAssessmentHeader(),
                const SizedBox(height: 24),

                // Questions
                _buildQuestions(),

                const SizedBox(height: 32),

                // Submit Button
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077B3), Color(0xFF005f8c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assessment header image
          if (assessment!['assessmentHeaderImageUrl'] != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  assessment!['assessmentHeaderImageUrl'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: FaIcon(
                          FontAwesomeIcons.image,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          Text(
            assessment!['title'] ?? 'Assessment',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (assessment!['description'] != null &&
              assessment!['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              assessment!['description'],
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],

          // Show deadline if exists
          if (assessment!['deadline'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(
                    FontAwesomeIcons.clock,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Due: ${_formatDateTime((assessment!['deadline'] as Timestamp).toDate())}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestions() {
    final questions = assessment!['questions'] as List;

    return Column(
      children: questions.asMap().entries.map((entry) {
        final index = entry.key;
        final question = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: _buildQuestionCard(question, index + 1),
        );
      }).toList(),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int questionNumber) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question $questionNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0077B3),
                ),
              ),
              if (question['points'] != null && question['points'] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0077B3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${question['points']} Point${question['points'] != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0077B3),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Question image
          if (question['questionImageUrl'] != null) ...[
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    question['questionImageUrl'],
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: FaIcon(
                            FontAwesomeIcons.image,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],

          // Question content based on type
          if (question['type'] == 'multiple-choice')
            _buildMultipleChoiceQuestion(question)
          else if (question['type'] == 'fill-in-the-blank')
            _buildFillInTheBlankQuestion(question),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceQuestion(Map<String, dynamic> question) {
    final questionId = question['questionId'];
    final correctOptions = List<String>.from(
      question['correctOptionIds'] ?? [],
    );
    final isMultiSelect = correctOptions.length > 1;
    final options = question['options'] as List?;
    final currentAnswer = answers[questionId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question['text'] ?? '',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),

        const SizedBox(height: 16),

        if (options != null)
          ...options.map((option) {
            final optionId = option['optionId'];
            final isSelected = isMultiSelect
                ? (currentAnswer as List?)?.contains(optionId) ?? false
                : currentAnswer == optionId;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: isSelected ? Colors.blue.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () =>
                      _handleMCQAnswer(questionId, optionId, isMultiSelect),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0077B3)
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: isMultiSelect
                                ? BoxShape.rectangle
                                : BoxShape.circle,
                            borderRadius: isMultiSelect
                                ? BorderRadius.circular(4)
                                : null,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0077B3)
                                  : Colors.grey,
                              width: 2,
                            ),
                            color: isSelected
                                ? const Color(0xFF0077B3)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? Icon(
                                  isMultiSelect ? Icons.check : Icons.circle,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option['text'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? const Color(0xFF0077B3)
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildFillInTheBlankQuestion(Map<String, dynamic> question) {
    final questionId = question['questionId'];
    final answerMode = question['answerInputMode'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scenario text if available
        if (question['scenarioText'] != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: Colors.purple.shade400, width: 4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(
                  FontAwesomeIcons.commentDots,
                  color: Colors.purple.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Scenario: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: question['scenarioText'],
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Question text with blank
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
            children: [
              if (question['questionTextBeforeBlank'] != null)
                TextSpan(text: question['questionTextBeforeBlank']),
              const TextSpan(
                text: ' _____ ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              if (question['questionTextAfterBlank'] != null)
                TextSpan(text: question['questionTextAfterBlank']),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Answer input based on mode
        if (answerMode == 'multipleChoice')
          _buildFITBMultipleChoice(question)
        else
          _buildFITBTextInput(question),
      ],
    );
  }

  Widget _buildFITBMultipleChoice(Map<String, dynamic> question) {
    final questionId = question['questionId'];
    final options = question['options'] as List?;
    final currentAnswer = answers[questionId];

    if (options == null) {
      return const Text(
        'No options provided for this question.',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      children: options.map((option) {
        final optionId = option['optionId'];
        final isSelected = currentAnswer == optionId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _handleFITBAnswer(questionId, optionId),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0077B3)
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0077B3)
                              : Colors.grey,
                          width: 2,
                        ),
                        color: isSelected
                            ? const Color(0xFF0077B3)
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 12,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option['text'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? const Color(0xFF0077B3)
                              : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFITBTextInput(Map<String, dynamic> question) {
    final questionId = question['questionId'];

    return TextField(
      onChanged: (value) => _handleFITBAnswer(questionId, value),
      decoration: InputDecoration(
        hintText: 'Type your answer for the blank...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0077B3), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton.icon(
        onPressed: isSubmitting ? null : _submitAssessment,
        icon: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const FaIcon(FontAwesomeIcons.paperPlane),
        label: Text(isSubmitting ? 'Submitting...' : 'Submit Assessment'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
