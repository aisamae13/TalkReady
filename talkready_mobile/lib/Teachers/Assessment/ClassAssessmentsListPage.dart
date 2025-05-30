import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'CreateAssessmentPage.dart';
import 'ViewAssessmentResultsPage.dart';

class ClassAssessmentsListPage extends StatefulWidget {
  final String classId;
  const ClassAssessmentsListPage({required this.classId, Key? key}) : super(key: key);

  @override
  State<ClassAssessmentsListPage> createState() => _ClassAssessmentsListPageState();
}

class _ClassAssessmentsListPageState extends State<ClassAssessmentsListPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> assessments = [];
  Map<String, dynamic>? classDetails;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() { loading = true; error = null; });
    try {
      // Fetch class details
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      if (!classDoc.exists) {
        throw Exception("Class not found.");
      }
      classDetails = classDoc.data();
      classDetails!['id'] = classDoc.id;


      // Fetch assessments for this class
      final assessmentsSnapshot = await FirebaseFirestore.instance
          .collection('assessments')
          .where('classId', isEqualTo: widget.classId)
          .orderBy('createdAt', descending: true) // Optional: order by creation date
          .get();

      assessments = assessmentsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();

    } catch (e) {
      error = "Failed to load assessments: ${e.toString()}";
    }
    setState(() { loading = false; });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('MMM d, yyyy - hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
          appBar: AppBar(title: const Text("Loading Assessments...")),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text("Error")),
          body: Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
          )));
    }
    if (classDetails == null) {
      return Scaffold(
          appBar: AppBar(title: const Text("Error")),
          body: const Center(child: Text("Class details not found.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Assessments: ${classDetails!['className'] ?? 'Class'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
          )
        ],
      ),
      body: assessments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.fileCircleXmark, size: 60, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text('No assessments found for this class yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Assessment'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateAssessmentPage(classId: widget.classId),
                        ),
                      ).then((_) => fetchData()); // Refresh list after creating
                    },
                  )
                ],
              ),
            )
          : RefreshIndicator(
            onRefresh: fetchData,
            child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: assessments.length,
                itemBuilder: (context, idx) {
                  final assessment = assessments[idx];
                  final title = assessment['title'] ?? 'Untitled Assessment';
                  final questionsCount = (assessment['questions'] as List?)?.length ?? 0;
                  final createdAt = assessment['createdAt'] as Timestamp?;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo[100],
                        child: FaIcon(FontAwesomeIcons.fileLines, color: Colors.indigo[700], size: 20),
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$questionsCount Question${questionsCount == 1 ? '' : 's'}'),
                          if (createdAt != null)
                            Text('Created: ${_formatTimestamp(createdAt)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Pass assessmentId via arguments or directly
                            builder: (_) => ViewAssessmentResultsPage(assessmentId: assessment['id']),
                            settings: RouteSettings(arguments: assessment['id']) // For onGenerateRoute if needed
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateAssessmentPage(classId: widget.classId),
            ),
          ).then((value) {
            // If an assessment was created (or any change happened), refresh the list
            if (value == true) { // You can have CreateAssessmentPage return true on successful save
              fetchData();
            }
          });
        },
        label: const Text('New Assessment'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}