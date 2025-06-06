import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting

class ViewAssessmentResultsPage extends StatefulWidget {
  final String assessmentId;
  const ViewAssessmentResultsPage({required this.assessmentId, super.key});

  @override
  State<ViewAssessmentResultsPage> createState() => _ViewAssessmentResultsPageState();
}

class _ViewAssessmentResultsPageState extends State<ViewAssessmentResultsPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _assessmentDetails;
  List<Map<String, dynamic>> _submissions = []; 
  // ThemeData? _theme;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _theme = Theme.of(context);
  // }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      // Fetch assessment details
      final assessmentDoc = await FirebaseFirestore.instance
          .collection('trainerAssessments')
          .doc(widget.assessmentId)
          .get();

      if (!assessmentDoc.exists) {
        throw Exception("Assessment not found.");
      }
      _assessmentDetails = assessmentDoc.data();
      _assessmentDetails!['id'] = assessmentDoc.id;

      // Fetch submissions for this assessment from the correct collection
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('studentSubmissions') // Changed from 'submissions' to 'studentSubmissions'
          .where('assessmentId', isEqualTo: widget.assessmentId)
          .orderBy('submittedAt', descending: true)
          .get();

      List<Map<String, dynamic>> fetchedSubmissions = [];
      for (var subDoc in submissionsSnapshot.docs) {
        Map<String, dynamic> submissionData = {'id': subDoc.id, ...subDoc.data()};
        
        // Use the existing studentName, studentEmail from the submission document
        // No need to fetch from users collection since the data is already there
        if (!submissionData.containsKey('studentName')) {
          submissionData['studentName'] = 'Unknown Student';
        }
        if (!submissionData.containsKey('studentEmail')) {
          submissionData['studentEmail'] = 'No Email';
        }
        
        fetchedSubmissions.add(submissionData);
      }
      _submissions = fetchedSubmissions;

    } catch (e) {
      _error = "Failed to load results: ${e.toString()}";
    }
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('MMM d, yyyy - hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Loading Results..."),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D5DF6), Color(0xFF46C2CB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Error"),
          backgroundColor: theme.colorScheme.errorContainer,
          foregroundColor: theme.colorScheme.onErrorContainer,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
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
    final totalPossiblePoints = (_assessmentDetails!['questions'] as List?)
        ?.fold(0, (sum, q) => sum + (q['points'] ?? 0) as int) ?? 0;


    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(assessmentTitle, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: "Refresh results",
          )
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D5DF6), Color(0xFF46C2CB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFF), Color(0xFFE3F0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                color: Colors.white.withOpacity(0.85),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_assessmentDetails!['description'] ?? 'No description.',
                              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              FaIcon(FontAwesomeIcons.listOl, size: 16, color: theme.colorScheme.secondary),
                              const SizedBox(width: 8),
                              Text('${_assessmentDetails!['questions']?.length ?? 0} Questions',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                              const SizedBox(width: 20),
                              FaIcon(FontAwesomeIcons.checkDouble, size: 16, color: theme.colorScheme.secondary),
                              const SizedBox(width: 8),
                              Text('Total Points: $totalPossiblePoints',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _submissions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(FontAwesomeIcons.faceSadTear, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            const SizedBox(height: 20),
                            Text('No submissions for this assessment yet.',
                                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      color: theme.colorScheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                        itemCount: _submissions.length,
                        itemBuilder: (context, idx) {
                          final sub = _submissions[idx];
                          final studentName = sub['studentName'] ?? 'Unknown Student';
                          final score = sub['score'] ?? 0;
                          final submissionTotalPossiblePoints = sub['totalPossiblePoints'] ?? totalPossiblePoints; // Use from submission or assessment
                          final submittedAt = sub['submittedAt'] as Timestamp?;
                          final scoreColor = score >= submissionTotalPossiblePoints * 0.7
                              ? Colors.green.shade600
                              : (score >= submissionTotalPossiblePoints * 0.4 ? Colors.orange.shade600 : Colors.red.shade600);

                          return AnimatedContainer(
                            duration: Duration(milliseconds: 350 + idx * 30),
                            curve: Curves.easeInOut,
                            child: Card(
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: Colors.white.withOpacity(0.93),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.13),
                                  child: FaIcon(FontAwesomeIcons.userGraduate, color: theme.colorScheme.primary, size: 20),
                                ),
                                title: Text(studentName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    )),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text('Score: $score / $submissionTotalPossiblePoints',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: scoreColor,
                                          fontWeight: FontWeight.bold,
                                        )),
                                    if (submittedAt != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          'Submitted: ${_formatTimestamp(submittedAt)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                  
                                  ],
                                ),
                                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.primary.withOpacity(0.7)),
                                onTap: () {
                                  // Show detailed submission review
                                  _showSubmissionDetails(context, sub);
                                },
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
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.person, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      submission['studentName'] ?? 'Unknown Student',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              
              // Submission Details
              _buildDetailRow('Email', submission['studentEmail'] ?? 'N/A', theme),
              _buildDetailRow('Score', '${submission['score'] ?? 0} / ${submission['totalPossiblePoints'] ?? 0}', theme),
              _buildDetailRow('Submitted', _formatTimestamp(submission['submittedAt']), theme),
              _buildDetailRow('Reviewed', submission['isReviewed'] == true ? 'Yes' : 'No', theme),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Detailed review feature coming soon!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Review Answers'),
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

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}