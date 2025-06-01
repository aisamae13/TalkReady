import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'CreateAssessmentPage.dart';
import 'ViewAssessmentResultsPage.dart';

class ClassAssessmentsListPage extends StatefulWidget {
  final String classId;
  const ClassAssessmentsListPage({required this.classId, super.key});

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
      // Fetch class details - Fix collection name
      final classDoc = await FirebaseFirestore.instance
          .collection('classes') // Changed from 'trainerClass' to 'classes'
          .doc(widget.classId)
          .get();

      if (!classDoc.exists) {
        throw Exception("Class not found.");
      }
      classDetails = classDoc.data();
      classDetails!['id'] = classDoc.id;

      // Fetch assessments for this class - Fix collection name
      final assessmentsSnapshot = await FirebaseFirestore.instance
          .collection('trainerAssessments') // Changed from 'assessments' to 'trainerAssessments'
          .where('classId', isEqualTo: widget.classId)
          .orderBy('createdAt', descending: true)
          .get();

      assessments = assessmentsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
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

    Widget buildEmptyState() => Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary.withOpacity(0.15), theme.colorScheme.secondary.withOpacity(0.10)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: FaIcon(FontAwesomeIcons.fileCircleXmark, size: 60, color: theme.colorScheme.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'No assessments found for this class yet.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create First Assessment'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateAssessmentPage(classId: widget.classId, initialClassId: null,), // Remove initialClassId parameter
                  ),
                ).then((_) => fetchData());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withOpacity(0.2),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );

    Widget buildAssessmentCard(Map<String, dynamic> assessment, int idx) {
      final title = assessment['title'] ?? 'Untitled Assessment';
      final questionsCount = (assessment['questions'] as List?)?.length ?? 0;
      final createdAt = assessment['createdAt'] as Timestamp?;

      return AnimatedContainer(
        duration: Duration(milliseconds: 350 + idx * 30),
        curve: Curves.easeInOut,
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          color: Colors.white.withOpacity(0.85),
          shadowColor: theme.colorScheme.primary.withOpacity(0.10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.13),
                  child: FaIcon(FontAwesomeIcons.fileLines, color: theme.colorScheme.primary, size: 26),
                ),
                title: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      '$questionsCount Question${questionsCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Created: ${_formatTimestamp(createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.primary, size: 28),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewAssessmentResultsPage(assessmentId: assessment['id']),
                      settings: RouteSettings(arguments: assessment['id']),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          classDetails != null
            ? 'Assessments: ${classDetails!['className'] ?? 'Class'}'
            : 'Assessments',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
            tooltip: "Refresh assessments",
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
        child: loading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)))
          : error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
                ),
              )
            : classDetails == null
              ? const Center(child: Text("Class details not found."))
              : assessments.isEmpty
                ? buildEmptyState()
                : RefreshIndicator(
                    onRefresh: fetchData,
                    color: theme.colorScheme.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 100, left: 8, right: 8, bottom: 80),
                      itemCount: assessments.length,
                      itemBuilder: (context, idx) => buildAssessmentCard(assessments[idx], idx),
                    ),
                  ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateAssessmentPage(classId: widget.classId, initialClassId: null,), // Remove initialClassId parameter
              ),
            ).then((value) {
              if (value == true) {
                fetchData();
              }
            });
          },
          label: const Text('New Assessment'),
          icon: const Icon(Icons.add),
          backgroundColor: const Color(0xFF6D5DF6),
          foregroundColor: Colors.white,
          elevation: 8,
        ),
      ),
    );
  }
}