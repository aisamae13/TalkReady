import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import '../Assessment/ViewAssessmentResultsPage.dart';
import '../Assessment/ReviewSpeakingSubmission.dart';

class TrainerReportsPage extends StatefulWidget {
  const TrainerReportsPage({super.key});

  @override
  _TrainerReportsPageState createState() => _TrainerReportsPageState();
}

class _TrainerReportsPageState extends State<TrainerReportsPage> with TickerProviderStateMixin {
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

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  StreamSubscription<QuerySnapshot>? _classesSubscription;
  StreamSubscription<QuerySnapshot>? _assessmentsSubscription;
  final Map<String, StreamSubscription<QuerySnapshot>> _submissionsSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut)
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)
    );

    _checkAuthState();
  }

  @override
  void dispose() {
    _classesSubscription?.cancel();
    _assessmentsSubscription?.cancel();
    for (var subscription in _submissionsSubscriptions.values) {
      subscription.cancel();
    }

    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _checkAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _authLoading = false;
          if (user != null) {
            _setupClassesListener();
          } else {
            _loadingClasses = false;
            _error = "Please log in to view reports.";
          }
        });
      }
    });
  }

  void _setupClassesListener() {
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
      _classesSubscription = FirebaseFirestore.instance
          .collection('trainerClass')
          .where('trainerId', isEqualTo: _currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            List<Map<String, dynamic>> classes = snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data()
            }).toList();

            classes.sort((a, b) {
              String nameA = a['className']?.toString().toLowerCase() ?? '';
              String nameB = b['className']?.toString().toLowerCase() ?? '';
              return nameA.compareTo(nameB);
            });

            _trainerClasses = classes;
            _loadingClasses = false;

            if (classes.isEmpty) {
              _error = "You haven't created any classes yet. No reports to display.";
            } else {
              _error = null;
            }

            _fadeController.forward();
            _slideController.forward();
          });
        }
      }, onError: (error) {
        print("Error listening to trainer classes: $error");
        if (mounted) {
          setState(() {
            _error = "Failed to load your classes. ${error.toString()}";
            _loadingClasses = false;
            _fadeController.forward();
            _slideController.forward();
          });
        }
      });
    } catch (e) {
      print("Error setting up classes listener: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to load your classes. ${e.toString()}";
          _loadingClasses = false;
          _fadeController.forward();
          _slideController.forward();
        });
      }
    }
  }

  void _setupAssessmentsListener(String classId) {
    _assessmentsSubscription?.cancel();

    for (var subscription in _submissionsSubscriptions.values) {
      subscription.cancel();
    }
    _submissionsSubscriptions.clear();

    if (mounted) setState(() => _loadingAssessments = true);
    _assessmentError = null;

    try {
      _assessmentsSubscription = FirebaseFirestore.instance
          .collection('trainerAssessments')
          .where('classId', isEqualTo: classId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          List<Map<String, dynamic>> assessments = snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data()
          }).toList();

          setState(() {
            _assessments = assessments;
            _loadingAssessments = false;
            _assessmentError = null;
          });

          for (var assessment in assessments) {
            _setupSubmissionsListener(assessment['id'] as String);
          }
        }
      }, onError: (error) {
        print("Error listening to assessments: $error");
        if (mounted) {
          setState(() {
            if (error.toString().contains('permission-denied')) {
              _assessmentError = 'Permission denied. Please check your Firestore security rules.';
            } else if (error.toString().contains('index')) {
              _assessmentError = 'Database index required. Please create the necessary indexes in Firestore.';
            } else {
              _assessmentError = 'Failed to load assessment data for "$_selectedClassName". Please try again later.';
            }
            _loadingAssessments = false;
          });
        }
      });
    } catch (e) {
      print("Error setting up assessments listener: $e");
      if (mounted) {
        setState(() {
          _assessmentError = 'Failed to load assessment data for "$_selectedClassName". Please try again later.';
          _loadingAssessments = false;
        });
      }
    }
  }

  void _setupSubmissionsListener(String assessmentId) {
    if (_submissionsSubscriptions.containsKey(assessmentId)) {
      return;
    }

    try {
      _submissionsSubscriptions[assessmentId] = FirebaseFirestore.instance
          .collection('studentSubmissions')
          .where('assessmentId', isEqualTo: assessmentId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          // Submissions already contain studentEmail from the submission document
          List<Map<String, dynamic>> submissions = snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data()
          }).toList();

          setState(() {
            _submissionsByAssessment[assessmentId] = submissions;
          });
        }
      }, onError: (error) {
        print('Error listening to submissions for $assessmentId: $error');
        if (mounted) {
          setState(() {
            _submissionsByAssessment[assessmentId] = [];
          });
        }
      });
    } catch (e) {
      print('Error setting up submissions listener for $assessmentId: $e');
      if (mounted) {
        setState(() {
          _submissionsByAssessment[assessmentId] = [];
        });
      }
    }
  }

  void _fetchDataForSelectedClass() {
    if (_selectedClassId == null) {
      _assessmentsSubscription?.cancel();
      for (var subscription in _submissionsSubscriptions.values) {
        subscription.cancel();
      }
      _submissionsSubscriptions.clear();

      if (mounted) {
        setState(() {
          _assessments = [];
          _submissionsByAssessment = {};
          _assessmentError = null;
        });
      }
      return;
    }

    _setupAssessmentsListener(_selectedClassId!);
  }


  Map<String, dynamic> _getAssessmentStats(String assessmentId) {
    final currentAssessment = _assessments.firstWhere((a) => a['id'] == assessmentId, orElse: () => {});
    final subs = _submissionsByAssessment[assessmentId] ?? [];
    final submissionCount = subs.length;

    // Check if this is a speaking assessment
    final assessmentType = currentAssessment['assessmentType'] ?? 'standard_quiz';
    final isSpeakingAssessment = assessmentType == 'speaking_assessment';

    num totalPossiblePoints;

    if (isSpeakingAssessment) {
      // Speaking assessments are always out of 100
      totalPossiblePoints = 100;
    } else {
      // Standard assessments calculate from questions
      totalPossiblePoints = (currentAssessment['questions'] as List?)
              ?.fold<num>(0, (sum, q) => sum + ((q as Map)['points'] as num? ?? 0)) ?? 0;

      if (submissionCount > 0 && subs[0]['totalPossiblePoints'] != null) {
        totalPossiblePoints = subs[0]['totalPossiblePoints'] as num;
      }
    }

    if (submissionCount == 0) {
      return {
        'submissionCount': 0,
        'averageScore': 'N/A',
        'totalPossiblePoints': totalPossiblePoints,
        'isSpeakingAssessment': isSpeakingAssessment
      };
    }

    final totalScoreSum = subs.fold<num>(0, (sum, sub) => sum + ((sub['score'] as num?) ?? 0));
    final averageScore = totalScoreSum / submissionCount;

    return {
      'submissionCount': submissionCount,
      'averageScore': double.parse(averageScore.toStringAsFixed(1)),
      'totalPossiblePoints': totalPossiblePoints,
      'isSpeakingAssessment': isSpeakingAssessment
    };
  }


  Widget _buildLoadingScreen(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.1),
                    const Color(0xFF059669).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF10B981)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String title, String message, {bool isAssessmentError = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.1),
            const Color(0xFFFF8E8E).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              FontAwesomeIcons.triangleExclamation,
              color: const Color(0xFFFF6B6B),
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (message.contains("haven't created any classes")) ...[
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.plus, size: 16),
                label: const Text(
                  "Create Your First Class",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/trainer/classes/create');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    if (_authLoading || (_loadingClasses && _currentUser != null)) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildModernAppBar(),
        body: Container(
          decoration: _buildBackgroundGradient(),
          child: SafeArea(
            child: _buildLoadingScreen("Loading report data..."),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(),
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 120,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  if (_error != null)
                    _buildErrorWidget("No Classes Found", _error!),

                  if (_selectedClassName != null && !_loadingAssessments && _error == null)
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildSelectedClassHeader(),
                    ),

                  if (_error == null && _trainerClasses.isNotEmpty)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildClassSelectionCard(),
                      ),
                    ),

                  if (_selectedClassId != null && _error == null) ...[
                    if (_loadingAssessments)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _buildLoadingScreen('Loading assessments for "$_selectedClassName"...'),
                      ),

                    if (!_loadingAssessments && _assessmentError != null)
                      _buildErrorWidget("Could Not Load Assessments", _assessmentError!, isAssessmentError: true),

                    if (!_loadingAssessments && _assessmentError == null && _assessments.isNotEmpty)
                      _buildAssessmentsSection(),

                    if (!_loadingAssessments && _assessmentError == null && _assessments.isEmpty && _selectedClassId != null)
                      _buildEmptyAssessmentsCard(),
                  ],

                  if (_selectedClassId == null && _error == null && _trainerClasses.isNotEmpty)
                    _buildWelcomeCard(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      title: Text(
        "Student Reports",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(FontAwesomeIcons.arrowLeft, size: 16),
        ),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, '/homepage');
          }
        },
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF0FDF4), Color(0xFFE6FFFA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
  }

  Widget _buildSelectedClassHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF059669).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              FontAwesomeIcons.chalkboardUser,
              color: const Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current Class",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedClassName!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelectionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 0),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981),
                        const Color(0xFF059669),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    FontAwesomeIcons.chartBar,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Select Class",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Choose a class to view assessment reports",
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      FontAwesomeIcons.chalkboardUser,
                      color: const Color(0xFF10B981),
                      size: 16,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                isExpanded: true,
                hint: Text(
                  "-- Choose a Class --",
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _selectedClassId,
                items: _trainerClasses.map((cls) {
                  final studentCount = cls['studentCount'] ?? 0;
                  return DropdownMenuItem<String>(
                    value: cls['id'] as String,
                    child: Text(
                      "${cls['className']} ($studentCount student${studentCount != 1 ? 's' : ''})",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
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
                      _fetchDataForSelectedClass();
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16, top: 8),
          child: Text(
            "Assessment Overview",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _assessments.length,
          itemBuilder: (context, index) {
            final assessment = _assessments[index];
            final stats = _getAssessmentStats(assessment['id'] as String);
            final isSpeakingAssessment = stats['isSpeakingAssessment'] as bool;
            final totalQuestions = isSpeakingAssessment ? 0 : (assessment['questions'] as List?)?.length ?? 0;
            final averageScore = stats['averageScore'];
            final totalPossiblePoints = stats['totalPossiblePoints'] as num;

            String averageScoreDisplay = 'N/A';
            Color scoreColor = const Color(0xFF64748B);

            if (stats['submissionCount'] > 0 && averageScore != 'N/A') {
              double percentage = 0;
              if (totalPossiblePoints > 0) {
                percentage = (averageScore as num) / totalPossiblePoints * 100;
              }
              averageScoreDisplay = "$averageScore / $totalPossiblePoints (${percentage.toStringAsFixed(0)}%)";

              if (percentage >= 80) {
                scoreColor = const Color(0xFF10B981);
              } else if (percentage >= 60) {
                scoreColor = const Color(0xFFF59E0B);
              } else {
                scoreColor = const Color(0xFFEF4444);
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (isSpeakingAssessment
                                  ? Colors.purple.withOpacity(0.2)
                                  : const Color(0xFF10B981).withOpacity(0.2)),
                                (isSpeakingAssessment
                                  ? Colors.purple.withOpacity(0.1)
                                  : const Color(0xFF059669).withOpacity(0.1)),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isSpeakingAssessment
                              ? FontAwesomeIcons.microphone
                              : FontAwesomeIcons.clipboardList,
                            color: isSpeakingAssessment
                              ? Colors.purple
                              : const Color(0xFF10B981),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assessment['title'] as String? ?? 'Untitled Assessment',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isSpeakingAssessment
                                    ? Colors.purple.withOpacity(0.1)
                                    : const Color(0xFF10B981).withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isSpeakingAssessment ? 'Speaking Assessment' : 'Standard Assessment',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSpeakingAssessment
                                      ? Colors.purple.shade700
                                      : const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats Row
                    Row(
                      children: [
                        if (!isSpeakingAssessment) ...[
                          _buildStatChip(
                            icon: FontAwesomeIcons.circleQuestion,
                            label: "$totalQuestions Question${totalQuestions != 1 ? 's' : ''}",
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 12),
                        ],
                        _buildStatChip(
                          icon: FontAwesomeIcons.star,
                          label: isSpeakingAssessment
                            ? "100 Points"
                            : "${stats['totalPossiblePoints']} Points",
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        _buildStatChip(
                          icon: FontAwesomeIcons.users,
                          label: "${stats['submissionCount']} Submissions",
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Average Score
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scoreColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.chartLine,
                            color: scoreColor,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Average Score: ",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              averageScoreDisplay,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: scoreColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981),
                            const Color(0xFF059669),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(FontAwesomeIcons.eye, size: 16),
                        label: const Text(
                          "View Detailed Results",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () {
                        final assessmentType = assessment['assessmentType'] ?? 'standard_quiz';

                        if (assessmentType == 'speaking_assessment') {
                          // For speaking assessments, show a list of submissions to choose from
                          final submissions = _submissionsByAssessment[assessment['id']] ?? [];

                          if (submissions.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No submissions yet for this assessment')),
                            );
                            return;
                          }

                          // If only one submission, go directly to it
                          if (submissions.length == 1) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReviewSpeakingSubmissionPage(
                                  submissionId: submissions[0]['id'],
                                ),
                              ),
                            );
                          } else {
                            // Multiple submissions - go to the standard results page that lists them
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewAssessmentResultsPage(
                                  assessmentId: assessment['id'],
                                  className: _selectedClassName,
                                ),
                              ),
                            );
                          }
                        } else {
                          // Standard assessments go to results page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewAssessmentResultsPage(
                                assessmentId: assessment['id'],
                                className: _selectedClassName,
                              ),
                            ),
                          );
                        }
                      },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
    );
  }

  Widget _buildStatChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAssessmentsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.1),
                  const Color(0xFF059669).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              FontAwesomeIcons.clipboardList,
              size: 40,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No Assessments Found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'There are no assessments created for "$_selectedClassName" yet.',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(FontAwesomeIcons.plus, size: 16),
              label: const Text(
                "Create Assessment",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/create-assessment', arguments: {'initialClassId': _selectedClassId});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.05),
            const Color(0xFF059669).withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.2),
                  const Color(0xFF059669).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              FontAwesomeIcons.chartBar,
              size: 32,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Ready for Insights?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Please select a class from the dropdown above to view its assessment reports and student performance analytics.",
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}