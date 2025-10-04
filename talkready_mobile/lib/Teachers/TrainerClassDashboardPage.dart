import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../Teachers/Assessment/ClassAssessmentsListPage.dart';
import '../Teachers/ClassManager/ManageClassContent.dart';
import '../Teachers/ClassManager/ManageClassStudents.dart';
import '../Teachers/ClassManager/EditClassPage.dart';
import '../Teachers/Assessment/CreateAssessmentPage.dart';

class TrainerClassDashboardPage extends StatefulWidget {
  final String classId;

  const TrainerClassDashboardPage({super.key, required this.classId});

  @override
  State<TrainerClassDashboardPage> createState() =>
      _TrainerClassDashboardPageState();
}

class _TrainerClassDashboardPageState extends State<TrainerClassDashboardPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _classDetails;
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _assessments = [];
  bool _loading = true;
  String? _error;
  bool _copied = false;

  // Stream subscriptions for real-time updates
  StreamSubscription<DocumentSnapshot>? _classSubscription;
  StreamSubscription<QuerySnapshot>? _materialsSubscription;
  StreamSubscription<QuerySnapshot>? _studentsSubscription;
  StreamSubscription<QuerySnapshot>? _assessmentsSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    // Cancel all subscriptions to prevent memory leaks
    _classSubscription?.cancel();
    _materialsSubscription?.cancel();
    _studentsSubscription?.cancel();
    _assessmentsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListeners() {
    if (_currentUser == null) {
      setState(() {
        _error = "Please log in to view class dashboard.";
        _loading = false;
      });
      return;
    }

    // Listen to class details changes
    _classSubscription = FirebaseFirestore.instance
        .collection('trainerClass')
        .doc(widget.classId)
        .snapshots()
        .listen(
          (classDoc) {
            if (!mounted) return;

            if (!classDoc.exists) {
              setState(() {
                _error = "Class not found.";
                _loading = false;
              });
              return;
            }

            final classData = {'id': classDoc.id, ...classDoc.data()!};

            // Check if current user is the trainer
            if (classData['trainerId'] != _currentUser!.uid) {
              setState(() {
                _error = "You are not authorized to view this class.";
                _loading = false;
              });
              return;
            }

            setState(() {
              _classDetails = classData;
              _error = null;
              if (_loading) _loading = false;
            });
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _error = "Failed to load class details: $error";
                _loading = false;
              });
            }
          },
        );

    // Listen to materials changes
    _materialsSubscription = FirebaseFirestore.instance
        .collection('classMaterials')
        .where('classId', isEqualTo: widget.classId)
        .orderBy('createdAt', descending: true) // Match web version ordering
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            final materials = snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();

            setState(() {
              _materials = materials;
            });
          },
          onError: (error) {
            print('Error listening to materials: $error');
          },
        );

    // Listen to students changes - UPDATED to use 'enrollments' collection like web
    _studentsSubscription = FirebaseFirestore.instance
        .collection(
          'enrollments',
        ) // Changed from 'classStudents' to 'enrollments'
        .where('classId', isEqualTo: widget.classId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            final students = snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();

            // Sort by studentName
            students.sort((a, b) {
              final nameA = (a['studentName'] as String?) ?? '';
              final nameB = (b['studentName'] as String?) ?? '';
              return nameA.compareTo(nameB);
            });

            setState(() {
              _students = students;
            });
          },
          onError: (error) {
            print('Error listening to students: $error');
          },
        );

    // Listen to assessments changes - UPDATED to use 'trainerAssessments' collection like web
    _assessmentsSubscription = FirebaseFirestore.instance
        .collection(
          'trainerAssessments',
        ) // Changed from 'assessments' to 'trainerAssessments'
        .where('classId', isEqualTo: widget.classId)
        .orderBy('createdAt', descending: true) // Match web version ordering
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            final assessments = snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();

            setState(() {
              _assessments = assessments;
            });
          },
          onError: (error) {
            print('Error listening to assessments: $error');
          },
        );
  }

  void _copyClassCode() {
    if (_classDetails?['classCode'] != null) {
      Clipboard.setData(ClipboardData(text: _classDetails!['classCode']));
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(FontAwesomeIcons.checkCircle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Class code copied!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: Container(
          decoration: _buildBackgroundGradient(),
          child: SafeArea(child: _buildLoadingScreen()),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: Container(
          decoration: _buildBackgroundGradient(),
          child: SafeArea(child: _buildErrorScreen()),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // Refresh will happen automatically via real-time listeners
              // Just show a brief feedback
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dashboard refreshed!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            color: const Color(0xFF8B5CF6),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildClassHeader(),
                  const SizedBox(height: 24),
                  _buildClassCodeSection(),
                  const SizedBox(height: 32),
                  _buildSectionCards(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        "Class Dashboard",
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
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(FontAwesomeIcons.penToSquare, size: 16),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditClassPage(classId: widget.classId),
                ),
              ).then((result) {
                // Refresh dashboard if class was updated
                if (result == true) {
                  _setupRealtimeListeners();
                }
              });
            },
            tooltip: "Edit Class",
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
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF8B5CF6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Loading class dashboard...",
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

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withOpacity(0.1),
                    const Color(0xFFFF5252).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                FontAwesomeIcons.triangleExclamation,
                size: 48,
                color: const Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something Went Wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
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
                  colors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                ),
              ),
              child: ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.arrowsRotate, size: 16),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _setupRealtimeListeners();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
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
  }

  Widget _buildClassHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 0),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const FaIcon(
                  FontAwesomeIcons.chalkboardUser,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _classDetails?['className'] ?? 'Unnamed Class',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_classDetails?['subject'] != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade100,
                              Colors.blue.shade100,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _classDetails!['subject'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_classDetails?['description'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _classDetails!['description'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClassCodeSection() {
    if (_classDetails?['classCode'] == null) return const SizedBox.shrink();

    return Container(
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
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Code',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _classDetails!['classCode'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _copied
                  ? const Color(0xFF10B981)
                  : const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color:
                      (_copied
                              ? const Color(0xFF10B981)
                              : const Color(0xFF8B5CF6))
                          .withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _copyClassCode,
              icon: FaIcon(
                _copied ? FontAwesomeIcons.check : FontAwesomeIcons.copy,
                color: Colors.white,
                size: 16,
              ),
              tooltip: _copied ? 'Copied!' : 'Copy Code',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCards() {
    return Column(
      children: [
        _buildMaterialsCard(),
        const SizedBox(height: 20),
        _buildStudentsCard(),
        const SizedBox(height: 20),
        _buildAssessmentsCard(),
      ],
    );
  }

  // Update the materials card onManage
  Widget _buildMaterialsCard() {
    return _buildSectionCard(
      title: 'Materials',
      count: _materials.length,
      icon: FontAwesomeIcons.book,
      iconColor: const Color(0xFF0EA5E9),
      items: _materials
          .take(4)
          .map(
            (material) => _buildListItem(
              title: material['title'] ?? 'Untitled Material',
              subtitle: _formatDate(material['createdAt']),
              icon: FontAwesomeIcons.fileLines,
              onTap: () {}, // Empty function since we don't want clicks
            ),
          )
          .toList(),
      onManage: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ManageClassContentPage(classId: widget.classId),
          ),
        );
      },
      onAdd: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ManageClassContentPage(classId: widget.classId),
          ),
        );
      },
      emptyMessage: 'No materials uploaded yet.',
    );
  }

  Widget _buildStudentsCard() {
    return _buildSectionCard(
      title: 'Students',
      count: _students.length,
      icon: FontAwesomeIcons.users,
      iconColor: const Color(0xFF10B981),
      items: _students
          .take(4)
          .map(
            (student) => _buildListItem(
              title: student['studentName'] ?? 'Unknown Student',
              subtitle: 'Enrolled ${_formatDate(student['enrolledAt'])}',
              icon: FontAwesomeIcons.user,
              onTap: () {}, // Empty function since we don't want clicks
            ),
          )
          .toList(),
      onManage: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ManageClassStudentsPage(classId: widget.classId),
          ),
        );
      },
      onAdd: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ManageClassStudentsPage(classId: widget.classId),
          ),
        );
      },
      emptyMessage: 'No students enrolled yet.',
    );
  }

  // Update the assessments card onAdd
  Widget _buildAssessmentsCard() {
    return _buildSectionCard(
      title: 'Assessments',
      count: _assessments.length,
      icon: FontAwesomeIcons.clipboardList,
      iconColor: const Color(0xFF8B5CF6),
      items: _assessments
          .take(4)
          .map(
            (assessment) => _buildListItem(
              title: assessment['title'] ?? 'Untitled Assessment',
              subtitle:
                  '${(assessment['questions'] as List?)?.length ?? 0} Questions',
              icon: FontAwesomeIcons.clipboard,
              onTap: () {}, // Empty function since we don't want clicks
            ),
          )
          .toList(),
      onManage: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ClassAssessmentsListPage(classId: widget.classId),
          ),
        );
      },
      onAdd: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateAssessmentPage(classId: widget.classId),
          ),
        );
      },
      emptyMessage: 'No assessments created yet.',
    );
  }

  Widget _buildSectionCard({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required List<Widget> items,
    required VoidCallback onManage,
    required VoidCallback onAdd,
    required String emptyMessage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: iconColor.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 0),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '$count ${title.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildActionButton(
                      icon: FontAwesomeIcons.plus,
                      color: iconColor,
                      onPressed: onAdd,
                      tooltip: 'Add ${title.substring(0, title.length - 1)}',
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: FontAwesomeIcons.gear,
                      color: const Color(0xFF64748B),
                      onPressed: onManage,
                      tooltip: 'Manage $title',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            Container(height: 1, color: Colors.grey.shade200),
            ...items,
          ] else ...[
            Container(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                emptyMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback
    onTap, // Keep parameter for compatibility but don't use it
  }) {
    return Container(
      // Changed from Material + InkWell to just Container
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(icon, size: 14, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Removed the chevron icon since items are no longer clickable
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: FaIcon(icon, size: 14, color: color),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMd().format(timestamp.toDate());
    } else if (timestamp is String) {
      try {
        return DateFormat.yMd().format(DateTime.parse(timestamp));
      } catch (e) {
        // Handle error silently
      }
    }
    return "Not set";
  }
}
