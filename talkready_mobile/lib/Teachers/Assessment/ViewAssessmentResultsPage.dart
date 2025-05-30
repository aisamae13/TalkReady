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
  List<Map<String, dynamic>> _submissions = []; // To store student submissions with details

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Loading Results...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        )),
      );
    }
    if (_assessmentDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Assessment details not found.")),
      );
    }

    final assessmentTitle = _assessmentDetails!['title'] ?? 'Assessment Results';
    final totalPossiblePoints = (_assessmentDetails!['questions'] as List?)
        ?.fold(0, (sum, q) => sum + (q['points'] ?? 0) as int) ?? 0;


    return Scaffold(
      appBar: AppBar(
        title: Text(assessmentTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_assessmentDetails!['description'] ?? 'No description.', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.listOl, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('${_assessmentDetails!['questions']?.length ?? 0} Questions'),
                        const SizedBox(width: 16),
                        const FaIcon(FontAwesomeIcons.checkDouble, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('Total Points: $totalPossiblePoints'),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FaIcon(FontAwesomeIcons.faceSadTear, size: 60, color: Colors.grey),
                        const SizedBox(height: 20),
                        const Text('No submissions for this assessment yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: _submissions.length,
                      itemBuilder: (context, idx) {
                        final sub = _submissions[idx];
                        final studentName = sub['studentName'] ?? 'Unknown Student';
                        final score = sub['score'] ?? 0; // Assuming score is calculated and stored
                        final submittedAt = sub['submittedAt'] as Timestamp?;

                        return Card(
                          elevation: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal[100],
                              child: FaIcon(FontAwesomeIcons.userGraduate, color: Colors.teal[700], size: 20),
                            ),
                            title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Score: $score / $totalPossiblePoints', style: TextStyle(color: score >= totalPossiblePoints * 0.7 ? Colors.green[700] : Colors.orange[700])),
                                if (submittedAt != null)
                                  Text('Submitted: ${_formatTimestamp(submittedAt)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
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