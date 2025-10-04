import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../notification_service.dart';

// --- Data Models (Simplified) ---
class ClassDetails {
  final String id;
  final String className;
  final String trainerId;
  final int studentCount;

  ClassDetails({required this.id, required this.className, required this.trainerId, required this.studentCount});

  factory ClassDetails.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ClassDetails(
      id: doc.id,
      className: data['className'] ?? 'Unnamed Class',
      trainerId: data['trainerId'] ?? '',
      studentCount: data['studentCount'] ?? 0,
    );
  }
}

class EnrolledStudent {
  final String id; // Enrollment document ID
  final String studentId; // User UID
  final String studentName;
  final String studentEmail;
  final Timestamp enrolledAt;

  EnrolledStudent({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.enrolledAt,
  });

  factory EnrolledStudent.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return EnrolledStudent(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'N/A',
      studentEmail: data['studentEmail'] ?? 'N/A',
      enrolledAt: data['enrolledAt'] ?? Timestamp.now(),
    );
  }
}

class UserSearchResult {
  final String uid;
  final String? displayName;
  final String? email;

  UserSearchResult({required this.uid, this.displayName, this.email});

  factory UserSearchResult.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserSearchResult(
      uid: doc.id,
      displayName: data['displayName'] ?? data['firstName'] ?? 'Unnamed User',
      email: data['email'] ?? '',
    );
  }
}

// --- Firebase Service Functions ---
Future<ClassDetails> fetchClassDetailsFromService(String classId) async {
  final doc = await FirebaseFirestore.instance.collection('trainerClass').doc(classId).get();
  if (!doc.exists) throw Exception("Class not found");
  return ClassDetails.fromFirestore(doc);
}

Future<List<EnrolledStudent>> fetchEnrolledStudentsFromService(String classId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('enrollments')
      .where('classId', isEqualTo: classId)
      .get();
  return snapshot.docs.map((doc) => EnrolledStudent.fromFirestore(doc)).toList();
}

Future<List<UserSearchResult>> searchUsersByEmailFromService(String email) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email.trim())
      .where('userType', isEqualTo: 'student')
      .get();
  return snapshot.docs.map((doc) => UserSearchResult.fromFirestore(doc)).toList();
}

Future<DocumentReference> enrollStudentInClassService(String classId, String studentId, String studentName, String studentEmail, String trainerId) async {
  final enrollmentRef = await FirebaseFirestore.instance.collection('enrollments').add({
    'classId': classId,
    'studentId': studentId,
    'studentName': studentName,
    'studentEmail': studentEmail,
    'trainerId': trainerId,
    'enrolledAt': FieldValue.serverTimestamp(),
  });
  await FirebaseFirestore.instance.collection('trainerClass').doc(classId).update({
    'student': FieldValue.arrayUnion([studentId])
  });
  return enrollmentRef;
}

Future<void> removeStudentFromClassService(String enrollmentId, String classId) async {
  await FirebaseFirestore.instance.collection('enrollments').doc(enrollmentId).delete();
  await FirebaseFirestore.instance.collection('trainerClass').doc(classId).update({
    'studentCount': FieldValue.increment(-1),
  });
}

class ManageClassStudentsPage extends StatefulWidget {
  final String classId;

  const ManageClassStudentsPage({super.key, required this.classId});

  @override
  _ManageClassStudentsPageState createState() => _ManageClassStudentsPageState();
}

class _ManageClassStudentsPageState extends State<ManageClassStudentsPage> with TickerProviderStateMixin {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();

  ClassDetails? _classDetails;
  List<EnrolledStudent> _enrolledStudents = [];
  List<UserSearchResult> _searchResults = [];

  bool _isLoading = true;
  String? _error;
  String? _actionError;
  bool _isSearching = false;
  String? _enrollingStudentId;
  String? _removingEnrollmentId;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _fetchClassAndStudentData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClassAndStudentData({bool showLoading = true}) async {
    if (_currentUser == null) {
      setState(() {
        _error = "Authentication required.";
        _isLoading = false;
      });
      return;
    }
    if (showLoading) setState(() => _isLoading = true);
    _error = null;
    _actionError = null;

    try {
      final details = await fetchClassDetailsFromService(widget.classId);
      if (details.trainerId != _currentUser.uid) {
        setState(() {
          _error = "You are not authorized to manage students for this class.";
          _classDetails = null;
          _enrolledStudents = [];
          _isLoading = false;
        });
        return;
      }
      final students = await fetchEnrolledStudentsFromService(widget.classId);
      students.sort((a, b) => a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));

      setState(() {
        _classDetails = details;
        _enrolledStudents = students;
      });

      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() => _error = "Failed to load data: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSearchStudents() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      setState(() {
        _searchResults = [];
        _actionError = "Please enter an email to search.";
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _actionError = null;
      _searchResults = [];
    });
    try {
      final users = await searchUsersByEmailFromService(searchTerm);
      final enrolledStudentUids = _enrolledStudents.map((s) => s.studentId).toSet();
      final filteredResults = users.where((user) => !enrolledStudentUids.contains(user.uid)).toList();

      setState(() {
        _searchResults = filteredResults;
        if (filteredResults.isEmpty) {
          _actionError = 'No new students found for "$searchTerm". Ensure email is correct and user is registered as a student.';
        }
      });
    } catch (e) {
      setState(() {
        _actionError = "Search failed: ${e.toString()}";
        _searchResults = [];
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _handleEnrollStudent(UserSearchResult studentToEnroll) async {
  if (_classDetails == null || _currentUser == null) {
    setState(() => _actionError = "Cannot enroll: Class/trainer info missing.");
    return;
  }
  if (_enrollingStudentId == studentToEnroll.uid) return;

  setState(() => _enrollingStudentId = studentToEnroll.uid);
  _actionError = null;

  try {
    // Enroll the student
    await enrollStudentInClassService(
      widget.classId,
      studentToEnroll.uid,
      studentToEnroll.displayName ?? "Student",
      studentToEnroll.email ?? "",
      _currentUser.uid,
    );

    // Send notification to the student about enrollment
    final trainerName = _currentUser!.displayName ?? 'Your trainer';

    await NotificationService.notifyStudentEnrollment(
      studentId: studentToEnroll.uid,
      className: _classDetails!.className,
      classId: widget.classId,
      trainerName: trainerName,
    );

    debugPrint('📧 Enrollment notification sent to: ${studentToEnroll.displayName}');

    await _fetchClassAndStudentData(showLoading: false);
    setState(() {
       _searchResults.removeWhere((s) => s.uid == studentToEnroll.uid);
       _searchController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${studentToEnroll.displayName} enrolled successfully!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  } catch (e) {
    setState(() => _actionError = "Enrollment failed: ${e.toString()}");
  } finally {
    if (mounted) setState(() => _enrollingStudentId = null);
  }
}

  Future<void> _handleRemoveStudent(EnrolledStudent enrollment) async {
  bool confirm = await _showModernConfirmDialog(
    title: 'Remove Student',
    content: 'Are you sure you want to remove ${enrollment.studentName} from the class?',
    confirmText: 'Remove',
    isDestructive: true,
  );

  if (!confirm) return;
  if (_removingEnrollmentId == enrollment.id) return;

  setState(() => _removingEnrollmentId = enrollment.id);
  _actionError = null;

  try {
    // Remove student from class
    await removeStudentFromClassService(enrollment.id, widget.classId);

    // Send notification to the student about removal
    if (_classDetails != null && _currentUser != null) {
      // Get trainer name from Firebase Auth
      final trainerName = _currentUser!.displayName ?? 'Your trainer';

      await NotificationService.notifyStudentRemoval(
        studentId: enrollment.studentId,
        className: _classDetails!.className,
        trainerName: trainerName,
      );

      debugPrint('📧 Removal notification sent to: ${enrollment.studentName}');
    }

    // Refresh the student list
    await _fetchClassAndStudentData(showLoading: false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${enrollment.studentName} removed successfully!'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  } catch (e) {
    setState(() => _actionError = "Removal failed: ${e.toString()}");
  } finally {
    if (mounted) setState(() => _removingEnrollmentId = null);
  }
}

  Future<bool> _showModernConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDestructive ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isDestructive ? FontAwesomeIcons.triangleExclamation : FontAwesomeIcons.circleQuestion,
                    color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: isDestructive
                                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                : [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isDestructive ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6)).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            confirmText,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ) ?? false;
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
  }

  void _clearSearchFieldAndResults() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _actionError = null;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(),
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingScreen()
              : _error != null
                  ? _buildErrorWidget()
                  : _classDetails == null
                      ? _buildNoDataWidget()
                      : RefreshIndicator(
                          onRefresh: () => _fetchClassAndStudentData(showLoading: false),
                          color: const Color(0xFF8B5CF6),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    _buildAddStudentSection(),
                                    const SizedBox(height: 24),
                                    _buildEnrolledStudentsSection(),
                                    const SizedBox(height: 100),
                                  ],
                                ),
                              ),
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
        _classDetails?.className ?? "Manage Students",
        style: const TextStyle(
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
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(FontAwesomeIcons.arrowsRotate, size: 16),
            ),
            onPressed: _isLoading ? null : () => _fetchClassAndStudentData(),
            tooltip: "Refresh Data",
          ),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
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
        colors: [Color(0xFFF8FAFC), Color(0xFFE3F0FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
  }

  Widget _buildLoadingScreen() {
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
                    const Color(0xFF8B5CF6).withOpacity(0.1),
                    const Color(0xFF6366F1).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Loading class data...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
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
              ),
              child: const Icon(
                FontAwesomeIcons.triangleExclamation,
                color: Color(0xFFFF6B6B),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Error Loading Data",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return const Center(
      child: Text(
        "Class details not available.",
        style: TextStyle(
          fontSize: 16,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildAddStudentSection() {
    return Container(
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
            color: const Color(0xFF8B5CF6).withOpacity(0.08),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.userPlus,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Add New Student",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Search by email to add students to your class",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_actionError != null && !_actionError!.toLowerCase().contains("removal failed"))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      FontAwesomeIcons.circleExclamation,
                      color: Color(0xFFFF6B6B),
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _actionError!,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: _buildModernTextField(
                      controller: _searchController,
                      hintText: "Student Email",
                      prefixIcon: FontAwesomeIcons.envelope,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isSearching,
                      onChanged: (_) {
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
                    label: const Text(
                      "Search",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: _isSearching ? null : _handleSearchStudents,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "Searching...",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (!_isSearching && _searchResults.isNotEmpty)
              _buildSearchResultsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Search Results:",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final user = _searchResults[index];
            final bool isCurrentlyEnrolling = _enrollingStudentId == user.uid;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.userGraduate,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                title: Text(
                  user.displayName ?? "N/A",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  user.email ?? "N/A",
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                  ),
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: isCurrentlyEnrolling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(FontAwesomeIcons.userPlus, size: 14),
                    label: const Text(
                      "Enroll",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: isCurrentlyEnrolling ? null : () => _handleEnrollStudent(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnrolledStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                FontAwesomeIcons.users,
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
                    "Enrolled Students (${_classDetails?.studentCount ?? _enrolledStudents.length})",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Manage your current students",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_actionError != null && _actionError!.toLowerCase().contains("removal failed"))
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B6B).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  FontAwesomeIcons.circleExclamation,
                  color: Color(0xFFFF6B6B),
                  size: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _actionError!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _enrolledStudents.isEmpty
            ? _buildEmptyStudentsWidget()
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _enrolledStudents.length,
                itemBuilder: (context, index) {
                  final student = _enrolledStudents[index];
                  final bool isCurrentlyRemoving = _removingEnrollmentId == student.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.1),
                        child: Text(
                          student.studentName.isNotEmpty ? student.studentName[0].toUpperCase() : "?",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5CF6),
                            fontSize: 18,
                          ),
                        ),
                      ),
                      title: Text(
                        student.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            student.studentEmail,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible, // <-- allow wrapping
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Enrolled: ${_formatTimestamp(student.enrolledAt)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: isCurrentlyRemoving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFEF4444),
                                  ),
                                )
                              : const Icon(
                                  FontAwesomeIcons.userMinus,
                                  color: Color(0xFFEF4444),
                                  size: 18,
                                ),
                          onPressed: isCurrentlyRemoving ? null : () => _handleRemoveStudent(student),
                          tooltip: "Remove Student",
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildEmptyStudentsWidget() {
    return Container(
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
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                  const Color(0xFF6366F1).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              FontAwesomeIcons.userGroup,
              size: 40,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Students Enrolled",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Start building your class by adding students using the search feature above.",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
  required TextEditingController controller,
  required String hintText,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool enabled = true,
  void Function(String)? onChanged,
  void Function()? onSubmitted,
}) {
  return TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
    style: const TextStyle(
      fontSize: 17,
      color: Color(0xFF1E293B),
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      fontFamily: 'RobotoMono', // Monospace font for better email readability
    ),
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 15,
        fontWeight: FontWeight.w400,
        fontFamily: 'RobotoMono', // Match input font
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Color(0xFF8B5CF6), size: 20)
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
      ),
      isDense: true, // Make the field more compact
    ),
    scrollPadding: const EdgeInsets.all(20),
    maxLines: 1,
    minLines: 1,
    textInputAction: TextInputAction.search,
    onChanged: onChanged,
    onSubmitted: (_) => onSubmitted?.call(),
    scrollPhysics: const BouncingScrollPhysics(),
    textAlignVertical: TextAlignVertical.center,
    // Add this to allow horizontal scrolling for long emails:
    expands: false,
    textAlign: TextAlign.start,
    // This ensures the text scrolls horizontally if it's too long
    keyboardAppearance: Brightness.light,
  );
}
}