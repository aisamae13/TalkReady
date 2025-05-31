import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Assuming you have these service functions defined elsewhere, similar to MyClassesPage
// e.g., in a firebase_services.dart file

// Placeholder for your actual service functions
// You'll need to implement these based on your Firebase structure
Future<List<Map<String, dynamic>>> getTrainerClasses(String trainerId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('classes')
      .where('trainerId', isEqualTo: trainerId)
      .orderBy('createdAt', descending: true) // Changed 'className' to 'createdAt' and added descending
      .get();
  return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
}

Future<List<Map<String, dynamic>>> getClassAssessments(String classId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('assessments') // Assuming 'assessments' collection
      .where('classId', isEqualTo: classId)
      .orderBy('createdAt', descending: true)
      .get();
  return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
}

Future<List<Map<String, dynamic>>> getAssessmentSubmissions(String assessmentId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('submissions') // Assuming 'submissions' collection
      .where('assessmentId', isEqualTo: assessmentId)
      .get();
  return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
}
// End of placeholder service functions


class TrainerReportsPage extends StatefulWidget {
  const TrainerReportsPage({Key? key}) : super(key: key);

  @override
  _TrainerReportsPageState createState() => _TrainerReportsPageState();
}

class _TrainerReportsPageState extends State<TrainerReportsPage> {
  User? _currentUser;
  bool _authLoading = true;

  List<Map<String, dynamic>> _trainerClasses = [];
  String? _selectedClassId;
  String? _selectedClassName;

  List<Map<String, dynamic>> _assessments = [];
  Map<String, List<Map<String, dynamic>>> _submissionsByAssessment = {};

  bool _loadingClasses = true;
  bool _loadingAssessments = false;
  String? _error;
  String? _assessmentError;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _authLoading = false;
          if (user != null) {
            _fetchClasses();
          } else {
            _loadingClasses = false;
            _error = "Please log in to view reports.";
          }
        });
      }
    });
  }

  Future<void> _fetchClasses() async {
    if (_currentUser == null || _currentUser!.uid.isEmpty) {
      if (mounted) {
        setState(() {
          _error = "Authentication details are missing. Please log in.";
          _loadingClasses = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loadingClasses = true);
    _error = null;
    try {
      final classes = await getTrainerClasses(_currentUser!.uid);
      if (mounted) {
        setState(() {
          classes.sort((a, b) { // Add this sort
      String nameA = a['className']?.toString().toLowerCase() ?? '';
      String nameB = b['className']?.toString().toLowerCase() ?? '';
      return nameA.compareTo(nameB);
    });
    _trainerClasses = classes;
    if (classes.isEmpty) {
      _error = "You haven't created any classes yet. No reports to display.";
    }
        });
      }
    } catch (err) {
      print("Error fetching trainer classes: $err");
      if (mounted) {
        setState(() {
          _error = "Failed to load your classes. ${err.toString()}";
        });
      }
    } finally {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  Future<void> _fetchDataForSelectedClass() async {
    if (_selectedClassId == null) {
      if (mounted) {
        setState(() {
          _assessments = [];
          _submissionsByAssessment = {};
        });
      }
      return;
    }

    if (mounted) setState(() => _loadingAssessments = true);
    _assessmentError = null;
    _assessments = [];
    _submissionsByAssessment = {};

    try {
      final fetchedAssessments = await getClassAssessments(_selectedClassId!);
      if (mounted) {
        setState(() {
          _assessments = fetchedAssessments;
        });
      }

      if (fetchedAssessments.isNotEmpty) {
        Map<String, List<Map<String, dynamic>>> submissionsMap = {};
        for (var assessment in fetchedAssessments) {
          final subs = await getAssessmentSubmissions(assessment['id']);
          submissionsMap[assessment['id']] = subs;
        }
        if (mounted) {
          setState(() {
            _submissionsByAssessment = submissionsMap;
          });
        }
      }
    } catch (err) {
      print("Error fetching data for selected class: $err");
      if (mounted) {
        setState(() {
          _assessmentError = 'Failed to load assessment data for "$_selectedClassName". ${err.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingAssessments = false);
    }
  }

  Map<String, dynamic> _getAssessmentStats(String assessmentId) {
    final currentAssessment = _assessments.firstWhere((a) => a['id'] == assessmentId, orElse: () => {});
    final subs = _submissionsByAssessment[assessmentId] ?? [];
    final submissionCount = subs.length;

    num totalPossiblePoints = (currentAssessment['questions'] as List?)
            ?.fold<num>(0, (sum, q) => sum + ((q as Map)['points'] as num? ?? 0)) ?? 0;

    if (submissionCount > 0 && subs[0]['totalPossiblePoints'] != null) {
        totalPossiblePoints = subs[0]['totalPossiblePoints'] as num;
    }
    
    if (submissionCount == 0) {
      return {'submissionCount': 0, 'averageScore': 'N/A', 'totalPossiblePoints': totalPossiblePoints};
    }

    final totalScoreSum = subs.fold<num>(0, (sum, sub) => sum + ((sub['score'] as num?) ?? 0));
    final averageScore = totalScoreSum / submissionCount;

    return {
      'submissionCount': submissionCount,
      'averageScore': double.parse(averageScore.toStringAsFixed(1)),
      'totalPossiblePoints': totalPossiblePoints
    };
  }

  Widget _buildLoadingScreen(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String title, String message, {bool isAssessmentError = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAssessmentError ? Colors.orange[50] : Colors.red[50],
        border: Border(
          left: BorderSide(
            color: isAssessmentError ? Colors.orange.shade500 : Colors.red.shade500,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            FontAwesomeIcons.triangleExclamation,
            color: isAssessmentError ? Colors.orange.shade700 : Colors.red.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAssessmentError ? Colors.orange.shade800 : Colors.red.shade800,
                  ),
                ),
                Text(message, style: TextStyle(color: isAssessmentError ? Colors.orange.shade700 : Colors.red.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_authLoading || (_loadingClasses && _currentUser != null)) {
      return Scaffold(
        appBar: AppBar(title: const Text("Student Reports")),
        body: _buildLoadingScreen("Loading report data..."),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Student Reports"),
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/homepage'); // Adjust to your trainer dashboard route
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedClassName != null && !_loadingAssessments)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Reports for: $_selectedClassName",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ),

            if (_error != null) _buildErrorWidget("Error", _error!),

            if (_error == null && _trainerClasses.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select a Class to View Reports:",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        prefixIcon: Icon(FontAwesomeIcons.chalkboardUser, color: Colors.grey[600]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      isExpanded: true,
                      hint: const Text("-- Choose a Class --"),
                      value: _selectedClassId,
                      items: _trainerClasses.map((cls) {
                        final studentCount = cls['studentCount'] ?? 0;
                        return DropdownMenuItem<String>(
                          value: cls['id'] as String,
                          child: Text("${cls['className']} ($studentCount student${studentCount != 1 ? 's' : ''})"),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final selectedClass = _trainerClasses.firstWhere((c) => c['id'] == value);
                          setState(() {
                            _selectedClassId = value;
                            _selectedClassName = selectedClass['className'] as String?;
                            _fetchDataForSelectedClass();
                          });
                        } else {
                           setState(() {
                            _selectedClassId = null;
                            _selectedClassName = null;
                            _assessments = [];
                            _submissionsByAssessment = {};
                            _assessmentError = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

            if (_selectedClassId != null) ...[
              if (_loadingAssessments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: _buildLoadingScreen('Loading assessments for "$_selectedClassName"...'),
                ),
              if (!_loadingAssessments && _assessmentError != null)
                _buildErrorWidget("Could Not Load Assessments", _assessmentError!, isAssessmentError: true),
              
              if (!_loadingAssessments && _assessmentError == null && _assessments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                  child: Text(
                    "Assessment Overview",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _assessments.length,
                  itemBuilder: (context, index) {
                    final assessment = _assessments[index];
                    final stats = _getAssessmentStats(assessment['id'] as String);
                    final totalQuestions = (assessment['questions'] as List?)?.length ?? 0;
                    final averageScore = stats['averageScore'];
                    final totalPossiblePoints = stats['totalPossiblePoints'] as num;
                    String averageScoreDisplay = 'N/A';
                    if (stats['submissionCount'] > 0 && averageScore != 'N/A') {
                         double percentage = 0;
                         if (totalPossiblePoints > 0) {
                            percentage = (averageScore as num) / totalPossiblePoints * 100;
                         }
                         averageScoreDisplay = "$averageScore / $totalPossiblePoints (${percentage.toStringAsFixed(0)}%)";
                    }


                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assessment['title'] as String? ?? 'Untitled Assessment',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(FontAwesomeIcons.circleQuestion, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text("$totalQuestions Question${totalQuestions != 1 ? 's' : ''}", style: TextStyle(color: Colors.grey[700])),
                                const Text("  |  ", style: TextStyle(color: Colors.grey)),
                                Text("Points: ${stats['totalPossiblePoints']}", style: TextStyle(color: Colors.grey[700])),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(FontAwesomeIcons.users, size: 14, color: Theme.of(context).primaryColorLight),
                                const SizedBox(width: 6),
                                Text("Submissions: ${stats['submissionCount']}", style: TextStyle(color: Colors.grey[800])),
                              ],
                            ),
                            const SizedBox(height: 4),
                             Row(
                              children: [
                                Icon(FontAwesomeIcons.percentage, size: 14, color: Colors.green[600]),
                                const SizedBox(width: 6),
                                Text("Average Score: $averageScoreDisplay", style: TextStyle(color: Colors.grey[800])),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(FontAwesomeIcons.eye, size: 16),
                                label: const Text("View Detailed Results"),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/trainer/assessment/${assessment['id']}/results');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (!_loadingAssessments && _assessmentError == null && _assessments.isEmpty && _selectedClassId != null)
                _buildEmptyStateCard(
                  icon: FontAwesomeIcons.listUl,
                  title: "No Assessments Found",
                  message: 'There are no assessments created for "$_selectedClassName" yet.',
                  actionButton: ElevatedButton.icon(
                    icon: const Icon(FontAwesomeIcons.plusCircle, size: 16),
                    label: const Text("Create Assessment"),
                    onPressed: () {
                      Navigator.pushNamed(context, '/create-assessment', arguments: {'initialClassId': _selectedClassId});
                    },
                     style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                     ),
                  ),
                ),
            ],

            if (_selectedClassId == null && _error == null && _trainerClasses.isNotEmpty)
              _buildEmptyStateCard(
                icon: FontAwesomeIcons.chartBar,
                title: "Ready for Insights?",
                message: "Please select a class from the dropdown above to view its assessment reports.",
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard({required IconData icon, required String title, required String message, Widget? actionButton}) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid, width: 1.5),
         boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
            )
          ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FaIcon(icon, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 20),
              actionButton,
            ]
          ],
        ),
      ),
    );
  }
}