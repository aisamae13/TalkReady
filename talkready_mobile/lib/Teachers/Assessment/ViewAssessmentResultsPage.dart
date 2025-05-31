import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting

class ViewAssessmentResultsPage extends StatefulWidget {
  final String assessmentId;
  const ViewAssessmentResultsPage({required this.assessmentId, Key? key}) : super(key: key);

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
          .collection('assessments')
          .doc(widget.assessmentId)
          .get();

      if (!assessmentDoc.exists) {
        throw Exception("Assessment not found.");
      }
      _assessmentDetails = assessmentDoc.data();
      _assessmentDetails!['id'] = assessmentDoc.id;

      // Fetch submissions for this assessment
      // This assumes you have a 'submissions' collection
      // and each submission has an 'assessmentId' field and 'studentId' field.
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('submissions') // Or 'assessmentSubmissions'
          .where('assessmentId', isEqualTo: widget.assessmentId)
          .orderBy('submittedAt', descending: true)
          .get();

      List<Map<String, dynamic>> fetchedSubmissions = [];
      for (var subDoc in submissionsSnapshot.docs) {
        Map<String, dynamic> submissionData = {'id': subDoc.id, ...subDoc.data() as Map<String, dynamic>};
        // Optionally, fetch student details (name, email) if not stored directly in submission
        final studentId = submissionData['studentId'];
        if (studentId != null) {
          final studentDoc = await FirebaseFirestore.instance.collection('users').doc(studentId).get(); // Assuming 'users' collection for students
          if (studentDoc.exists) {
            submissionData['studentName'] = studentDoc.data()?['displayName'] ?? 'Unknown Student';
            submissionData['studentEmail'] = studentDoc.data()?['email'] ?? 'No Email';
          }
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
        appBar: AppBar(
          title: const Text("Loading Results..."),
          backgroundColor: theme.colorScheme.surfaceVariant,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          elevation: 0,
        ),
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary))),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Error"),
          backgroundColor: theme.colorScheme.errorContainer,
          foregroundColor: theme.colorScheme.onErrorContainer,
        ),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
        )),
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
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(assessmentTitle, style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: theme.colorScheme.surfaceVariant,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: "Refresh results",
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_assessmentDetails!['description'] ?? 'No description.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FaIcon(FontAwesomeIcons.listOl, size: 16, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('${_assessmentDetails!['questions']?.length ?? 0} Questions', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                        const SizedBox(width: 20),
                        FaIcon(FontAwesomeIcons.checkDouble, size: 16, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('Total Points: $totalPossiblePoints', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                      ],
                    ),
                  ],
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
                          Text('No submissions for this assessment yet.', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: theme.colorScheme.primary,
                  child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      itemCount: _submissions.length,
                      itemBuilder: (context, idx) {
                        final sub = _submissions[idx];
                        final studentName = sub['studentName'] ?? 'Unknown Student';
                        final score = sub['score'] ?? 0; 
                        final submittedAt = sub['submittedAt'] as Timestamp?;
                        final scoreColor = score >= totalPossiblePoints * 0.7 
                                           ? Colors.green.shade600 
                                           : (score >= totalPossiblePoints * 0.4 ? Colors.orange.shade600 : Colors.red.shade600);

                        return Card(
                          elevation: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          color: theme.colorScheme.surface,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.tertiaryContainer,
                              child: FaIcon(FontAwesomeIcons.userGraduate, color: theme.colorScheme.onTertiaryContainer, size: 20),
                            ),
                            title: Text(studentName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text('Score: $score / $totalPossiblePoints', style: theme.textTheme.bodyMedium?.copyWith(color: scoreColor, fontWeight: FontWeight.bold)),
                                if (submittedAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text('Submitted: ${_formatTimestamp(submittedAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))),
                                  ),
                              ],
                            ),
                            trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                            onTap: () {
                              // TODO: Navigate to individual submission review page
                              // Navigator.push(context, MaterialPageRoute(builder: (_) => SubmissionReviewPage(submissionId: sub['id'])));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reviewing ${sub['id']} - Feature coming soon!')),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ),
          ),
        ],
      ),
    );
  }
}