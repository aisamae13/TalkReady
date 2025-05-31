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
  // ThemeData? _theme;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _theme = Theme.of(context);
  // }

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
    final theme = Theme.of(context);

    if (loading) {
      return Scaffold(
          appBar: AppBar(
            title: const Text("Loading Assessments..."),
            backgroundColor: theme.colorScheme.surfaceVariant,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            elevation: 0,
          ),
          body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary))));
    }
    if (error != null) {
      return Scaffold(
          appBar: AppBar(
            title: const Text("Error"),
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            elevation: 0,
          ),
          body: Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
          )));
    }
    if (classDetails == null) {
      return Scaffold(
          appBar: AppBar(
            title: const Text("Error"),
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
          ),
          body: const Center(child: Text("Class details not found.")));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text('Assessments: ${classDetails!['className'] ?? 'Class'}', style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: theme.colorScheme.surfaceVariant,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
            tooltip: "Refresh assessments",
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
      body: assessments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(FontAwesomeIcons.fileCircleXmark, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    const SizedBox(height: 20),
                    Text('No assessments found for this class yet.', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create First Assessment'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateAssessmentPage(classId: widget.classId),
                          ),
                        ).then((_) => fetchData()); // Refresh list after creating
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    )
                  ],
                ),
              ),
            )
          : RefreshIndicator(
            onRefresh: fetchData,
            color: theme.colorScheme.primary,
            child: ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: assessments.length,
                itemBuilder: (context, idx) {
                  final assessment = assessments[idx];
                  final title = assessment['title'] ?? 'Untitled Assessment';
                  final questionsCount = (assessment['questions'] as List?)?.length ?? 0;
                  final createdAt = assessment['createdAt'] as Timestamp?;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: theme.colorScheme.surface,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: FaIcon(FontAwesomeIcons.fileLines, color: theme.colorScheme.onPrimaryContainer, size: 20),
                      ),
                      title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('$questionsCount Question${questionsCount == 1 ? '' : 's'}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          if (createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text('Created: ${_formatTimestamp(createdAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))),
                            ),
                        ],
                      ),
                      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
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
            if (value == true) { 
              fetchData();
            }
          });
        },
        label: const Text('New Assessment'),
        icon: const Icon(Icons.add),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
      ),
    );
  }
}