import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:talkready_mobile/Teachers/Assessment/ReviewSpeakingSubmission.dart';
import 'EditAssessmentPage.dart';
import 'package:intl/intl.dart';
import 'ReviewSpeakingSubmission.dart'; // Import the new page

class ViewAssessmentResultsPage extends StatefulWidget {
  final String assessmentId;
  final String? className; // This can still be a fallback

  const ViewAssessmentResultsPage({
    Key? key,
    required this.assessmentId,
    this.className,
  }) : super(key: key);

  @override
  _ViewAssessmentResultsPageState createState() =>
      _ViewAssessmentResultsPageState();
}

class _ViewAssessmentResultsPageState extends State<ViewAssessmentResultsPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _assessmentDetails;
  List<Map<String, dynamic>> _submissions = [];
  String? _fetchedClassName;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Fetch the assessment details
      final assessmentDoc = await FirebaseFirestore.instance
          .collection('trainerAssessments')
          .doc(widget.assessmentId)
          .get();

      if (!assessmentDoc.exists) {
        throw Exception("Assessment not found.");
      }
      _assessmentDetails = assessmentDoc.data();

      // 2. Determine the classId from the assessment
      final classId = _assessmentDetails?['classId'] as String?;

      // 3. Fetch the className using the classId
      // Use the className from the widget first as a fallback
      if (widget.className != null) {
        _fetchedClassName = widget.className;
      } else if (classId != null) {
        final classDoc = await FirebaseFirestore.instance
            .collection('trainerClass')
            .doc(classId)
            .get();
        _fetchedClassName = classDoc.data()?['className'] as String?;
      } else {
        _fetchedClassName = 'N/A';
      }

      // 4. Fetch student submissions with their IDs
      final submissionQuery = await FirebaseFirestore.instance
          .collection('studentSubmissions')
          .where('assessmentId', isEqualTo: widget.assessmentId)
          .get();

      _submissions = submissionQuery.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return 'N/A';
    }
    if (timestamp is Timestamp) {
      return DateFormat('MM/dd/yyyy, hh:mm a').format(timestamp.toDate());
    }
    if (timestamp is String) {
      try {
        final dateTime = DateTime.parse(timestamp);
        return DateFormat('MM/dd/yyyy, hh:mm a').format(dateTime);
      } catch (e) {
        return 'Invalid Date';
      }
    }
    return 'Unknown Date Format';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0FDFA),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            "Loading Results...",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF0FDFA), Color(0xFFCCFDF7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Loading assessment results...',
                  style: TextStyle(
                    color: Color(0xFF0F766E),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFEF2F2),
        appBar: AppBar(
          title: const Text(
            "Error",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade400,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_assessmentDetails == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Error"),
          backgroundColor: theme.colorScheme.errorContainer,
          foregroundColor: theme.colorScheme.onErrorContainer,
        ),
        body: const Center(child: Text("Assessment details not found.")),
      );
    }

    final assessmentTitle = _assessmentDetails!['title'] ?? 'Assessment Results';
    final assessmentDescription = _assessmentDetails!['description'] ?? 'No description.';
    final totalPossiblePoints = (_assessmentDetails!['questions'] as List?)
            ?.fold(0, (sum, q) => sum + (q['points'] ?? 0) as int) ??
        0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          assessmentTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditAssessmentPage(
                      assessmentId: widget.assessmentId,
                    ),
                  ),
                );
              },
              tooltip: "Edit assessment",
            ),
          ),
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchData,
              tooltip: "Refresh results",
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0FDFA), Color(0xFFCCFDF7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 120, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14B8A6).withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.assessment,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Assessment Overview",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assessmentDescription,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF374151),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF14B8A6).withOpacity(0.05),
                                    const Color(0xFF0D9488).withOpacity(0.02),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF14B8A6).withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.class_,
                                        size: 18,
                                        color: const Color(0xFF0F766E),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _fetchedClassName ?? 'Class Not Found',
                                          style: const TextStyle(
                                            color: Color(0xFF0F766E),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.quiz_outlined,
                                              size: 18,
                                              color: const Color(0xFF0F766E),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${_assessmentDetails!['questions']?.length ?? 0} Questions',
                                              style: const TextStyle(
                                                color: Color(0xFF0F766E),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.grade_outlined,
                                            size: 18,
                                            color: const Color(0xFF0F766E),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Total Points: $totalPossiblePoints',
                                            style: const TextStyle(
                                              color: Color(0xFF0F766E),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_submissions.isEmpty)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF14B8A6).withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF14B8A6).withOpacity(0.1),
                                const Color(0xFF0D9488).withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: const Color(0xFF14B8A6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Submissions Yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Students haven\'t submitted any responses to this assessment yet.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchData,
                  color: const Color(0xFF14B8A6),
                  backgroundColor: Colors.white,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    itemCount: _submissions.length,
                    itemBuilder: (context, idx) {
                      final sub = _submissions[idx];
                      final studentName = sub['studentName'] ?? 'Unknown Student';
                      final studentEmail = sub['studentEmail'] ?? 'No Email';
                      final score = sub['score'] ?? 0;
                      final submissionTotalPossiblePoints =
                          sub['totalPossiblePoints'] ?? totalPossiblePoints;
                      final submittedAt = sub['submittedAt'];
                      final assessmentType = sub['assessmentType'] ?? 'standard';

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300 + idx * 50),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF14B8A6).withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (assessmentType == 'speaking_assessment') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReviewSpeakingSubmissionPage(
                                        submissionId: sub['id'],
                                      ),
                                    ),
                                  );
                                } else {
                                  _showSubmissionDetails(context, sub);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF14B8A6).withOpacity(0.15),
                                            const Color(0xFF0D9488).withOpacity(0.10),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        assessmentType == 'speaking_assessment' 
                                          ? Icons.mic
                                          : Icons.person,
                                        color: const Color(0xFF0F766E),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            studentName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F766E),
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            studentEmail,
                                            style: TextStyle(
                                              color: const Color(0xFF6B7280),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: assessmentType == 'speaking_assessment' 
                                                ? Colors.purple.withOpacity(0.1)
                                                : const Color(0xFF14B8A6).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              assessmentType == 'speaking_assessment' 
                                                ? 'Speaking' 
                                                : 'Standard',
                                              style: TextStyle(
                                                color: assessmentType == 'speaking_assessment' 
                                                  ? Colors.purple.shade700
                                                  : const Color(0xFF0F766E),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF14B8A6),
                                                const Color(0xFF0D9488),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Score: $score',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatTimestamp(submittedAt),
                                          style: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSubmissionDetails(BuildContext context, Map<String, dynamic> submission) {
    final theme = Theme.of(context);
    final questions = _assessmentDetails?['questions'] as List<dynamic>? ?? [];
    final studentAnswers = submission['answers'] as List<dynamic>? ?? [];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    submission['studentName'] ?? 'Unknown Student',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Submission Details',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF14B8A6).withOpacity(0.05),
                                      const Color(0xFF0D9488).withOpacity(0.02),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF14B8A6).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _buildDetailRow('Email', submission['studentEmail'] ?? 'N/A', theme),
                                    _buildDetailRow('Score', '${submission['score'] ?? 0} / ${submission['totalPossiblePoints'] ?? 0}', theme),
                                    _buildDetailRow('Submitted', _formatTimestamp(submission['submittedAt']), theme),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Student Answers',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: questions.length,
                                  itemBuilder: (context, index) {
                                    final question = questions[index];
                                    final studentAnswerData = studentAnswers.firstWhere(
                                      (ans) => ans['questionId'] == question['questionId'],
                                      orElse: () => null,
                                    );
                                    return _buildModernQuestionReviewCard(
                                      question,
                                      studentAnswerData,
                                      index + 1,
                                      theme,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernQuestionReviewCard(Map<String, dynamic> question, Map<String, dynamic>? studentAnswerData, int questionNumber, ThemeData theme) {
    final isCorrect = studentAnswerData?['isCorrect'] ?? false;
    final pointsEarned = studentAnswerData?['pointsEarned'] ?? 0;
    final questionPoints = question['points'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect 
            ? const Color(0xFF10B981).withOpacity(0.3)
            : Colors.red.withOpacity(0.3),
          width: 2,
        ),
        gradient: LinearGradient(
          colors: isCorrect
            ? [
                const Color(0xFF10B981).withOpacity(0.05),
                const Color(0xFF059669).withOpacity(0.02),
              ]
            : [
                Colors.red.withOpacity(0.05),
                Colors.red.withOpacity(0.02),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCorrect 
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCorrect ? Icons.check : Icons.close,
                    color: isCorrect 
                      ? const Color(0xFF059669)
                      : Colors.red.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question $questionNumber',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCorrect 
                            ? const Color(0xFF059669)
                            : Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question['text'] ?? 'No text',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCorrect
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [Colors.red.shade500, Colors.red.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pointsEarned / $questionPoints pts',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildModernAnswerDetails(question, studentAnswerData, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAnswerDetails(Map<String, dynamic> question, Map<String, dynamic>? studentAnswerData, ThemeData theme) {
    if (studentAnswerData == null) {
      return const Text('No answer submitted.', style: TextStyle(fontStyle: FontStyle.italic));
    }

    final type = question['type'];

    if (type == 'multiple-choice') {
      return _buildModernMultipleChoiceAnswer(question, studentAnswerData, theme);
    } else if (type == 'fill-in-the-blank') {
      return _buildModernFillInTheBlankAnswer(question, studentAnswerData, theme);
    }

    return Text('Review for this question type ($type) is not yet supported.');
  }

  Widget _buildModernMultipleChoiceAnswer(Map<String, dynamic> question, Map<String, dynamic> studentAnswerData, ThemeData theme) {
    final options = question['options'] as List<dynamic>? ?? [];
    final correctOptionIds = List<String>.from(question['correctOptionIds'] ?? []);
    final selectedOptionIds = List<String>.from(studentAnswerData['selectedOptionIds'] ?? (studentAnswerData['selectedOptionId'] != null ? [studentAnswerData['selectedOptionId']] : []));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: options.map((option) {
        final optionId = option['optionId'];
        final optionText = option['text'];
        final isSelected = selectedOptionIds.contains(optionId);
        final isCorrect = correctOptionIds.contains(optionId);

        Color textColor = Colors.black87;
        FontWeight fontWeight = FontWeight.normal;
        IconData? icon;
        Color? iconColor;

        if (isSelected && isCorrect) {
          textColor = Colors.green.shade700;
          fontWeight = FontWeight.bold;
          icon = Icons.check_circle;
          iconColor = Colors.green.shade700;
        } else if (isSelected && !isCorrect) {
          textColor = Colors.red.shade700;
          fontWeight = FontWeight.bold;
          icon = Icons.cancel;
          iconColor = Colors.red.shade700;
        } else if (!isSelected && isCorrect) {
          textColor = Colors.green.shade700;
          fontWeight = FontWeight.w500;
          icon = Icons.check_circle_outline;
          iconColor = Colors.green.shade400;
        } else {
          textColor = Colors.grey.shade700;
          icon = Icons.radio_button_unchecked;
          iconColor = Colors.grey.shade400;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Text(optionText, style: TextStyle(color: textColor, fontWeight: fontWeight, fontSize: 16)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModernFillInTheBlankAnswer(Map<String, dynamic> question, Map<String, dynamic> studentAnswerData, ThemeData theme) {
    final studentAnswer = studentAnswerData['studentAnswer'] ?? 'Not answered';
    final correctAnswers = List<String>.from(question['correctAnswers'] ?? []);
    final isCorrect = studentAnswerData['isCorrect'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Student\'s Answer:', style: TextStyle(fontWeight: FontWeight.bold)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(studentAnswer, style: TextStyle(color: isCorrect ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        if (!isCorrect && correctAnswers.isNotEmpty) ...[
          const Text('Correct Answer(s):', style: TextStyle(fontWeight: FontWeight.bold)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(correctAnswers.join(' / '), style: TextStyle(color: Colors.grey.shade800, fontSize: 15)),
          ),
        ]
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F766E),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}