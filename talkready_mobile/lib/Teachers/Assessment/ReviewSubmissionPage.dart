// src/components/StudentSection/assessments/ReviewSubmissionPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:logger/logger.dart';

class ReviewSubmissionPage extends StatefulWidget {
  final String submissionId;
  final String assessmentId;

  const ReviewSubmissionPage({
    super.key,
    required this.submissionId,
    required this.assessmentId,
  });

  @override
  State<ReviewSubmissionPage> createState() => _ReviewSubmissionPageState();
}

class _ReviewSubmissionPageState extends State<ReviewSubmissionPage>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _error;

  // Data
  Map<String, dynamic>? _submission;
  Map<String, dynamic>? _assessment;
  List<Map<String, dynamic>> _reviewItems = [];

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _fetchData();
  }

  void _initializeAnimation() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch submission
      final submissionDoc = await _firestore
          .collection('studentSubmissions')
          .doc(widget.submissionId)
          .get();

      if (!submissionDoc.exists) {
        throw Exception('Submission not found');
      }

      final submissionData = submissionDoc.data()!;

      // Fetch assessment
      final assessmentDoc = await _firestore
          .collection('trainerAssessments')
          .doc(widget.assessmentId)
          .get();

      if (!assessmentDoc.exists) {
        throw Exception('Assessment not found');
      }

      final assessmentData = assessmentDoc.data()!;

      // Process review items
      final questions = assessmentData['questions'] as List;
      final answers = submissionData['answers'] as List;

      List<Map<String, dynamic>> items = [];

      for (var answer in answers) {
        final questionId = answer['questionId'];
        final question = questions.firstWhere(
          (q) => q['questionId'] == questionId,
          orElse: () => null,
        );

        if (question != null) {
          items.add({
            'question': question,
            'answer': answer,
          });
        }
      }

      setState(() {
        _submission = submissionData;
        _assessment = assessmentData;
        _reviewItems = items;
        _isLoading = false;
      });

      _fadeController.forward();
    } catch (e) {
      _logger.e('Error fetching review data: $e');
      setState(() {
        _error = 'Failed to load review data. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Your Answers'),
        backgroundColor: const Color(0xFF0077B3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingScreen()
          : _error != null
              ? _buildErrorScreen()
              : _buildReviewContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0077B3)),
          SizedBox(height: 16),
          Text('Loading your submission...'),
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
              'Error Loading Review',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An unknown error occurred',
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

  Widget _buildReviewContent() {
    if (_submission == null || _assessment == null) return Container();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildScoreCard(),
              const SizedBox(height: 24),
              _buildSubmissionInfo(),
              const SizedBox(height: 24),
              _buildQuestionsReview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final score = _submission!['score'] ?? 0;
    final totalPoints = _submission!['totalPossiblePoints'] ?? 0;
    final percentage = totalPoints > 0 ? (score / totalPoints * 100) : 0;

    Color scoreColor;
    IconData scoreIcon;
    String scoreLabel;

    if (percentage >= 90) {
      scoreColor = const Color(0xFF10B981);
      scoreIcon = FontAwesomeIcons.trophy;
      scoreLabel = 'Excellent!';
    } else if (percentage >= 75) {
      scoreColor = const Color(0xFF3B82F6);
      scoreIcon = FontAwesomeIcons.thumbsUp;
      scoreLabel = 'Great Job!';
    } else if (percentage >= 60) {
      scoreColor = const Color(0xFFF59E0B);
      scoreIcon = FontAwesomeIcons.circleCheck;
      scoreLabel = 'Good Effort!';
    } else {
      scoreColor = const Color(0xFFEF4444);
      scoreIcon = FontAwesomeIcons.circleXmark;
      scoreLabel = 'Keep Practicing!';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor, scoreColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          FaIcon(scoreIcon, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            scoreLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Score',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / $totalPoints',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionInfo() {
    final submittedAt = (_submission!['submittedAt'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.circleInfo,
                color: Color(0xFF0077B3),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Submission Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0077B3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            FontAwesomeIcons.fileLines,
            'Assessment',
            _assessment!['title'] ?? 'Untitled',
          ),
          const SizedBox(height: 8),
          if (submittedAt != null)
            _buildInfoRow(
              FontAwesomeIcons.clock,
              'Submitted',
              _formatDateTime(submittedAt),
            ),
          const SizedBox(height: 8),
          _buildInfoRow(
            FontAwesomeIcons.listCheck,
            'Questions',
            '${_reviewItems.length} questions',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        FaIcon(icon, size: 14, color: const Color(0xFF0077B3)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0077B3),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Answers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_reviewItems.length, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildQuestionReviewCard(
              _reviewItems[index],
              index + 1,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQuestionReviewCard(
    Map<String, dynamic> item,
    int questionNumber,
  ) {
    final question = item['question'] as Map<String, dynamic>;
    final answer = item['answer'] as Map<String, dynamic>;
    final isCorrect = answer['isCorrect'] ?? false;
    final pointsEarned = answer['pointsEarned'] ?? 0;
    final totalPoints = question['points'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
          width: 2,
        ),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        FaIcon(
                          isCorrect
                              ? FontAwesomeIcons.circleCheck
                              : FontAwesomeIcons.circleXmark,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCorrect ? 'Correct' : 'Incorrect',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Question $questionNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0077B3),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0077B3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pointsEarned / $totalPoints pts',
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

          // Question Image
          if (question['questionImageUrl'] != null) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  question['questionImageUrl'],
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
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
            const SizedBox(height: 16),
          ],

          // Question content based on type
          if (question['type'] == 'multiple-choice')
            _buildMultipleChoiceReview(question, answer)
          else if (question['type'] == 'fill-in-the-blank')
            _buildFillInTheBlankReview(question, answer),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceReview(
    Map<String, dynamic> question,
    Map<String, dynamic> answer,
  ) {
    final questionText = question['text'] ?? '';
    final options = question['options'] as List?;
    final correctOptionIds = List<String>.from(
      question['correctOptionIds'] ?? [],
    );
    final isMultiSelect = correctOptionIds.length > 1;

    // Get student's selection
    List<String> selectedIds = [];
    if (isMultiSelect) {
      selectedIds = List<String>.from(answer['selectedOptionIds'] ?? []);
    } else {
      final selected = answer['selectedOptionId'];
      if (selected != null) selectedIds = [selected];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        if (options != null)
          ...options.map((option) {
            final optionId = option['optionId'];
            final optionText = option['text'];
            final isCorrectOption = correctOptionIds.contains(optionId);
            final isSelected = selectedIds.contains(optionId);

            Color borderColor;
            Color bgColor;
            IconData? icon;

            if (isSelected && isCorrectOption) {
              // Selected and correct
              borderColor = Colors.green;
              bgColor = Colors.green.shade50;
              icon = FontAwesomeIcons.circleCheck;
            } else if (isSelected && !isCorrectOption) {
              // Selected but wrong
              borderColor = Colors.red;
              bgColor = Colors.red.shade50;
              icon = FontAwesomeIcons.circleXmark;
            } else if (!isSelected && isCorrectOption) {
              // Not selected but correct answer
              borderColor = Colors.green;
              bgColor = Colors.green.shade50;
              icon = FontAwesomeIcons.lightbulb;
            } else {
              // Not selected and not correct
              borderColor = Colors.grey.shade300;
              bgColor = Colors.white;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    FaIcon(
                      icon,
                      size: 18,
                      color: isCorrectOption ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      optionText ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected || isCorrectOption
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (!isSelected && isCorrectOption)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Correct Answer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildFillInTheBlankReview(
    Map<String, dynamic> question,
    Map<String, dynamic> answer,
  ) {
    final scenarioText = question['scenarioText'];
    final textBefore = question['questionTextBeforeBlank'] ?? '';
    final textAfter = question['questionTextAfterBlank'] ?? '';
    final answerMode = question['answerInputMode'];
    final isCorrect = answer['isCorrect'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scenario
        if (scenarioText != null && scenarioText.toString().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
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
                          text: scenarioText,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Question with blank
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
            children: [
              TextSpan(text: textBefore),
              TextSpan(
                text: ' _____ ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              TextSpan(text: textAfter),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Student's answer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCorrect ? Colors.green : Colors.red,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.user,
                    size: 14,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Your Answer:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getStudentAnswer(answer, answerMode, question),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Show correct answer if wrong
        if (!isCorrect) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.lightbulb,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Correct Answer:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getCorrectAnswer(question, answerMode),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getStudentAnswer(
    Map<String, dynamic> answer,
    String? answerMode,
    Map<String, dynamic> question,
  ) {
    if (answerMode == 'multipleChoice') {
      final selectedId = answer['selectedOptionId'];
      if (selectedId == null) return 'No answer provided';

      final options = question['options'] as List?;
      if (options == null) return selectedId;

      final option = options.firstWhere(
        (o) => o['optionId'] == selectedId,
        orElse: () => null,
      );

      return option != null ? option['text'] : selectedId;
    } else {
      return answer['studentAnswer']?.toString() ?? 'No answer provided';
    }
  }

  String _getCorrectAnswer(Map<String, dynamic> question, String? answerMode) {
    if (answerMode == 'multipleChoice') {
      final correctId = question['correctOptionIdForFITB'];
      if (correctId == null) return 'Answer not available';

      final options = question['options'] as List?;
      if (options == null) return correctId;

      final option = options.firstWhere(
        (o) => o['optionId'] == correctId,
        orElse: () => null,
      );

      return option != null ? option['text'] : correctId;
    } else {
      final correctAnswers = question['correctAnswers'] as List?;
      if (correctAnswers == null || correctAnswers.isEmpty) {
        return 'Answer not available';
      }

      // Show all acceptable answers with note about case insensitivity
      final answersText = correctAnswers.join(' / ');
      return '$answersText (case-insensitive)';
    }
  }
}