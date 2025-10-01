import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_service.dart';
import 'take_assessment_page.dart'; // Add this import
import 'take_speaking_assessment_page.dart'; // Add this import

class ClassContentPage extends StatefulWidget {
  final String classId;
  final String className;
  final Map<String, dynamic> classData;

  const ClassContentPage({
    super.key,
    required this.classId,
    required this.className,
    required this.classData,
  });

  @override
  State<ClassContentPage> createState() => _ClassContentPageState();
}

class _ClassContentPageState extends State<ClassContentPage>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // State variables
  Map<String, dynamic>? classDetails;
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> assessments = [];
  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> classMembers = [];
  Map<String, dynamic>? trainerInfo;

  bool loading = true;
  bool isEnrolled = false;
  bool enrollmentChecked = false;
  String error = '';

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkEnrollmentAndLoadData();
  }

  void _initializeAnimations() {
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

  Future<void> _checkEnrollmentAndLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        error = "You must be logged in to view class content.";
        loading = false;
      });
      return;
    }

    try {
      // Check enrollment
      await _checkEnrollment(user.uid);

      if (isEnrolled) {
        await _fetchClassData();
        _fadeController.forward();
      }
    } catch (e) {
      _logger.e("Error in initial load: $e");
      setState(() {
        error = "Failed to load class content.";
        loading = false;
      });
    }
  }

  Future<void> _checkEnrollment(String userId) async {
    try {
      final enrollmentQuery = await _firestore
          .collection('enrollments')
          .where('studentId', isEqualTo: userId)
          .where('classId', isEqualTo: widget.classId)
          .get();

      setState(() {
        isEnrolled = enrollmentQuery.docs.isNotEmpty;
        enrollmentChecked = true;
      });
    } catch (e) {
      _logger.e("Error checking enrollment: $e");
      setState(() {
        isEnrolled = false;
        enrollmentChecked = true;
      });
    }
  }

  Future<void> _fetchClassData() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      // Fetch all data in parallel
      final futures = await Future.wait([
        _fetchClassDetails(),
        _fetchMaterials(),
        _fetchAssessments(),
        _fetchAnnouncements(),
        _fetchClassMembers(),
      ]);

      // If class details were fetched successfully, get trainer info
      if (classDetails != null && classDetails!['trainerId'] != null) {
        await _fetchTrainerInfo(classDetails!['trainerId']);
      }

      setState(() {
        loading = false;
      });
    } catch (e) {
      _logger.e("Error fetching class data: $e");
      setState(() {
        error = "Failed to load class content.";
        loading = false;
      });
    }
  }

  Future<void> _fetchClassDetails() async {
    try {
      final doc = await _firestore
          .collection('trainerClass')
          .doc(widget.classId)
          .get();

      if (doc.exists) {
        setState(() {
          classDetails = {'id': doc.id, ...doc.data()!};
        });
      }
    } catch (e) {
      _logger.e("Error fetching class details: $e");
    }
  }

  Future<void> _fetchMaterials() async {
    try {
      final snapshot = await _firestore
          .collection('classMaterials')
          .where('classId', isEqualTo: widget.classId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        materials = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    } catch (e) {
      _logger.e("Error fetching materials: $e");
      setState(() {
        materials = [];
      });
    }
  }

  Future<void> _fetchAssessments() async {
    try {
      final snapshot = await _firestore
          .collection('trainerAssessments')
          .where('classId', isEqualTo: widget.classId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        assessments = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    } catch (e) {
      _logger.e("Error fetching assessments: $e");
      setState(() {
        assessments = [];
      });
    }
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final snapshot = await _firestore
          .collection('classAnnouncements')
          .where('classId', isEqualTo: widget.classId)
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        announcements = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    } catch (e) {
      _logger.e("Error fetching announcements: $e");
      setState(() {
        announcements = [];
      });
    }
  }

  Future<void> _fetchClassMembers() async {
    try {
      final enrollmentSnapshot = await _firestore
          .collection('enrollments')
          .where('classId', isEqualTo: widget.classId)
          .get();

      List<Map<String, dynamic>> members = [];

      for (var enrollment in enrollmentSnapshot.docs) {
        final enrollmentData = enrollment.data();
        final studentId = enrollmentData['studentId'];

        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(studentId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            members.add({
              'id': studentId,
              'displayName':
                  userData['displayName'] ??
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                      .trim() ??
                  'Unnamed Member',
              'email': userData['email'] ?? '',
            });
          }
        } catch (e) {
          _logger.w("Error fetching user data for $studentId: $e");
        }
      }

      setState(() {
        classMembers = members;
      });
    } catch (e) {
      _logger.e("Error fetching class members: $e");
      setState(() {
        classMembers = [];
      });
    }
  }

  Future<void> _fetchTrainerInfo(String trainerId) async {
    try {
      final doc = await _firestore.collection('users').doc(trainerId).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          trainerInfo = {
            'name':
                data['displayName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim() ??
                'Unknown Trainer',
          };
        });
      }
    } catch (e) {
      _logger.e("Error fetching trainer info: $e");
      setState(() {
        trainerInfo = {'name': 'Unknown Trainer'};
      });
    }
  }

  Future<void> _openMaterial(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
    }
  }

  Widget _getFileIcon(String? fileType) {
    if (fileType == null)
      return const FaIcon(FontAwesomeIcons.file, color: Colors.grey);

    if (fileType.startsWith('application/pdf')) {
      return const FaIcon(FontAwesomeIcons.filePdf, color: Colors.red);
    } else if (fileType.startsWith('video/')) {
      return const FaIcon(FontAwesomeIcons.fileVideo, color: Colors.blue);
    } else if (fileType.startsWith('audio/')) {
      return const FaIcon(FontAwesomeIcons.fileAudio, color: Colors.purple);
    } else if (fileType.startsWith('image/')) {
      return const FaIcon(FontAwesomeIcons.fileImage, color: Colors.green);
    }

    return const FaIcon(FontAwesomeIcons.file, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    // Show access denied if not enrolled
    if (enrollmentChecked && !isEnrolled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You are not enrolled in this class and cannot access its content.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const FaIcon(FontAwesomeIcons.arrowLeft),
                  label: const Text('Back to My Classes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show loading
    if (loading || !enrollmentChecked) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.className),
          backgroundColor: const Color(0xFF0077B3),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0077B3)),
              SizedBox(height: 16),
              Text('Loading class content...'),
            ],
          ),
        ),
      );
    }

    // Show error
    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.className),
          backgroundColor: const Color(0xFF0077B3),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  FontAwesomeIcons.exclamationTriangle,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                Text(
                  error,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _fetchClassData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main content
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: const Color(0xFF0077B3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _fetchClassData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class Header
                _buildClassHeader(),
                const SizedBox(height: 24),

                // Announcements Section
                _buildAnnouncementsSection(),
                const SizedBox(height: 24),

                // Materials Section
                _buildMaterialsSection(),
                const SizedBox(height: 24),

                // Assessments Section
                _buildAssessmentsSection(),
                const SizedBox(height: 24),

                // Class Members Section
                _buildClassMembersSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077B3), Color(0xFF005f8c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.chalkboardTeacher,
                color: Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.className,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (classDetails?['subject'] != null)
            Text(
              'Subject: ${classDetails!['subject']}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          if (trainerInfo != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(
                    FontAwesomeIcons.userTie,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trainer: ${trainerInfo!['name']}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          if (classDetails?['description'] != null &&
              classDetails!['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              classDetails!['description'],
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    return _buildSection(
      title: 'Class Announcements',
      icon: FontAwesomeIcons.bullhorn,
      count: announcements.length,
      child: announcements.isEmpty
          ? _buildEmptyState(
              icon: FontAwesomeIcons.bullhorn,
              message: 'No announcements posted yet.',
            )
          : Column(
              children: announcements.map((announcement) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (announcement['title'] != null) ...[
                        Text(
                          announcement['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0077B3),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        announcement['content'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Posted: ${_formatTimestamp(announcement['createdAt'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMaterialsSection() {
    return _buildSection(
      title: 'Class Materials',
      icon: FontAwesomeIcons.bookOpen,
      count: materials.length,
      child: materials.isEmpty
          ? _buildEmptyState(
              icon: FontAwesomeIcons.bookOpen,
              message: 'No materials uploaded yet.',
            )
          : Column(
              children: materials.map((material) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _openMaterial(material['downloadURL'] ?? ''),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _getFileIcon(material['fileType']),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    material['title'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (material['description'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      material['description'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    material['fileName'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const FaIcon(
                              FontAwesomeIcons.download,
                              color: Color(0xFF0077B3),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAssessmentsSection() {
    return _buildSection(
      title: 'Available Assessments',
      icon: FontAwesomeIcons.clipboardCheck,
      count: assessments.length,
      child: assessments.isEmpty
          ? _buildEmptyState(
              icon: FontAwesomeIcons.clipboardCheck,
              message: 'No assessments available yet.',
            )
          : Column(
              children: assessments.map((assessment) {
                final now = DateTime.now();
                bool isPastDeadline = false;
                String? deadlineString;
                DateTime? deadline;

                final dynamic deadlineValue = assessment['deadline'];

                if (deadlineValue != null) {
                  if (deadlineValue is Timestamp) {
                    deadline = deadlineValue.toDate();
                  } else if (deadlineValue is String) {
                    try {
                      deadline = DateTime.parse(deadlineValue);
                    } catch (e) {
                      _logger.w('Invalid deadline format: $deadlineValue');
                    }
                  }

                  if (deadline != null) {
                    deadlineString = 'Deadline: ${_formatTimestamp(deadline)}';
                    isPastDeadline = now.isAfter(deadline);
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPastDeadline
                        ? Colors.red.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPastDeadline
                          ? Colors.red.shade200
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assessment['title'] ?? 'Untitled Assessment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isPastDeadline
                              ? Colors.red.shade700
                              : const Color(0xFF0077B3),
                        ),
                      ),
                      if (assessment['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          assessment['description'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${(assessment['questions'] as List?)?.length ?? 0} Question(s)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (deadlineString != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.clock,
                              size: 12,
                              color: isPastDeadline
                                  ? Colors.red
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              deadlineString,
                              style: TextStyle(
                                fontSize: 12,
                                color: isPastDeadline
                                    ? Colors.red
                                    : Colors.grey[600],
                                fontWeight: isPastDeadline
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isPastDeadline
                              ? null
                              : () {
                                  // Check if it's a speaking assessment
                                  final assessmentType =
                                      assessment['assessmentType'] ??
                                      'standard_quiz';
                                  final questions =
                                      assessment['questions'] as List?;

                                  bool isSpeakingAssessment = false;

                                  // Check assessment type field
                                  if (assessmentType == 'speaking_assessment') {
                                    isSpeakingAssessment = true;
                                  }

                                  // Also check if questions contain speaking prompts
                                  if (questions != null &&
                                      questions.isNotEmpty) {
                                    final firstQuestion = questions.first;
                                    if (firstQuestion['type'] ==
                                            'speaking_prompt' ||
                                        firstQuestion['promptText'] != null) {
                                      isSpeakingAssessment = true;
                                    }
                                  }

                                  if (isSpeakingAssessment) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TakeSpeakingAssessmentPage(
                                              assessmentId: assessment['id'],
                                              classId: widget.classId,
                                            ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TakeAssessmentPage(
                                              assessmentId: assessment['id'],
                                              classId: widget.classId,
                                            ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPastDeadline
                                ? Colors.grey
                                : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isPastDeadline) ...[
                                const FaIcon(FontAwesomeIcons.lock, size: 16),
                                const SizedBox(width: 8),
                                const Text('Closed'),
                              ] else ...[
                                const Text('Start Assessment'),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildClassMembersSection() {
    return _buildSection(
      title: 'Class Members',
      icon: FontAwesomeIcons.users,
      count: classMembers.length,
      child: classMembers.isEmpty
          ? _buildEmptyState(
              icon: FontAwesomeIcons.users,
              message: 'No other members found.',
            )
          : Column(
              children: classMembers.map((member) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.userCircle,
                        color: Color(0xFF0077B3),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          member['displayName'] ?? 'Unknown Member',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required int count,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              FaIcon(icon, color: const Color(0xFF0077B3), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0077B3),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0077B3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count Total',
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
          child,
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            FaIcon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Date N/A';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Date N/A';
      }

      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Date N/A';
    }
  }
}