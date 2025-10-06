import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../TrainerDashboard.dart';
import '../../notification_service.dart';

// Placeholder for your actual service functions.
Future<List<Map<String, dynamic>>> getTrainerClasses(String trainerId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('trainerClass')
        .where('trainerId', isEqualTo: trainerId)
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  } catch (e) {
    throw Exception("Failed to load classes: ${e.toString()}");
  }
}
Future<void> createNotificationsForStudents({
  required String classId,
  required String message,
  required String? className,
  required String link,
}) async {
  try {
    // Get all students enrolled in this class
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('trainerClass')
        .doc(classId)
        .collection('students')
        .get();

    if (studentsSnapshot.docs.isEmpty) {
      debugPrint('No students found in class $classId');
      return;
    }

    // Create notifications in batch
    final batch = FirebaseFirestore.instance.batch();

    for (var studentDoc in studentsSnapshot.docs) {
      final studentId = studentDoc.id;
      final notificationRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();

      batch.set(notificationRef, {
        'userId': studentId,
        'message': message,
        'className': className,
        'link': link,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('✅ Created ${studentsSnapshot.docs.length} notifications');
  } catch (e) {
    debugPrint('❌ Error creating notifications: $e');
    // Don't throw - notifications are not critical
  }
}
Future<void> postClassAnnouncement({
  required String classId,
  required String title,
  required String content,
  required String trainerId,
  String? className,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('classAnnouncements')
        .add({
      'classId': classId,
      'className': className,
      'title': title,
      'content': content,
      'trainerId': trainerId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'published',
    });

    // Get trainer's name
    String trainerName = 'Your trainer';
    try {
      final trainerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(trainerId)
          .get();

      if (trainerDoc.exists) {
        final trainerData = trainerDoc.data()!;
        trainerName = '${trainerData['firstName'] ?? ''} ${trainerData['lastName'] ?? ''}'.trim();
        if (trainerName.isEmpty) {
          trainerName = trainerData['displayName'] ?? 'Your trainer';
        }
      }
    } catch (e) {
      debugPrint('Could not fetch trainer name: $e');
    }

    // Create notifications for all students
    await NotificationService.createNotificationsForStudents(
      classId: classId,
      message: '$trainerName posted a new announcement: $title',
      className: className,
      link: '/student/class/$classId#announcements',
    );
  } catch (e) {
    throw Exception("Failed to post announcement: ${e.toString()}");
  }
}


class CreateAnnouncementPage extends StatefulWidget {
  const CreateAnnouncementPage({super.key});

  @override
  _CreateAnnouncementPageState createState() => _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState extends State<CreateAnnouncementPage> with TickerProviderStateMixin {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _trainerClasses = [];
  String? _selectedClassId;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isPosting = false;
  String? _postError;
  String? _postSuccess;

  bool _loadingClasses = true;
  String? _classesError;

  bool _hasNavigated = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut)
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)
    );

    if (_currentUser != null) {
      _fetchTrainerClasses();
    } else {
      setState(() {
        _loadingClasses = false;
        _classesError = "User not logged in. Please log in to create announcements.";
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrainerClasses() async {
    if (_currentUser == null) return;
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    try {
      final classes = await getTrainerClasses(_currentUser.uid);
      setState(() {
        _trainerClasses = classes;
        if (_trainerClasses.isEmpty) {
           _classesError = "No classes found. You need to create a class first.";
        }
        _loadingClasses = false;
      });

      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _classesError = e.toString();
        _loadingClasses = false;
      });
    }
  }

  Future<void> _handlePostAnnouncement() async {
    if (_currentUser == null) {
      setState(() {
        _postError = "User not logged in.";
      });
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedClassId == null) {
        setState(() {
          _postError = "Please select a class.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(FontAwesomeIcons.triangleExclamation, color: Colors.white, size: 16),
                SizedBox(width: 12),
                Text("Please select a class.", style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFFFF8C00),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      setState(() {
        _isPosting = true;
        _postError = null;
        _postSuccess = null;
      });

      try {
        final selectedClass = _trainerClasses.firstWhere(
          (cls) => cls['id'] == _selectedClassId,
          orElse: () => {'className': 'Unknown Class'},
        );

        await postClassAnnouncement(
          classId: _selectedClassId!,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          trainerId: _currentUser.uid,
          className: selectedClass['className'] as String?,
        );

        if (mounted) {
          setState(() {
            _postSuccess = "Announcement posted successfully!";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(FontAwesomeIcons.checkCircle, color: Colors.white, size: 16),
                  SizedBox(width: 12),
                  Text("Announcement posted!", style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          if (!_hasNavigated) {
            _hasNavigated = true;
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _showSuccessDialog();
              }
            });
          }
        }

      } catch (e) {
        if (mounted) {
          setState(() {
            _postError = e.toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(FontAwesomeIcons.triangleExclamation, color: Colors.white, size: 16),
                  const SizedBox(width: 12),
                  Expanded(child: Text("Error: ${e.toString()}", style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isPosting = false;
          });
        }
      }
    }
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
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
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.checkCircle,
                      color: Color(0xFF10B981),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Success!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your announcement has been posted successfully.',
                    style: TextStyle(
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
                            onPressed: () {
                              Navigator.of(context).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _titleController.clear();
                                    _contentController.clear();
                                    _selectedClassId = null;
                                    _postSuccess = null;
                                    _hasNavigated = false;
                                  });
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'Create Another',
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
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8C00), Color(0xFFFF7A00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8C00).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const TrainerDashboard()),
                                    (route) => false,
                                  );
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'OK',
                              style: TextStyle(fontWeight: FontWeight.w600),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isPosting,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _isPosting) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please wait for the announcement to finish posting',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFFFF8C00),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildModernAppBar(),
        body: Container(
          decoration: _buildBackgroundGradient(),
          child: SafeArea(
            child: _currentUser == null
                ? _buildAuthError()
                : _loadingClasses
                    ? _buildLoadingIndicator("Loading classes...")
                    : _classesError != null && _trainerClasses.isEmpty
                        ? _buildErrorDisplay(_classesError!, FontAwesomeIcons.listUl, onRetry: _fetchTrainerClasses)
                        : FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildForm(),
                            ),
                          ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      title: const Text(
        'Create Announcement',
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
        onPressed: _isPosting ? null : () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        },
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF8C00), Color(0xFFFF7A00)],
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
        colors: [Color(0xFFFFF8F1), Color(0xFFFFF2E6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
  }

  Widget _buildLoadingIndicator(String message) {
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
                    const Color(0xFFFF8C00).withOpacity(0.1),
                    const Color(0xFFFF7A00).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
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

  Widget _buildAuthError() {
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
                FontAwesomeIcons.userLock,
                color: Color(0xFFFF6B6B),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Authentication Required",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _classesError ?? "You must be logged in to create announcements.",
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

  Widget _buildErrorDisplay(String error, IconData icon, {VoidCallback? onRetry}) {
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
              child: Icon(
                icon,
                color: const Color(0xFFFF6B6B),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Classes Available",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8C00), Color(0xFFFF7A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C00).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(FontAwesomeIcons.arrowsRotate, size: 16),
                  label: const Text('Retry'),
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 15),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFFFF8C00).withOpacity(0.08),
                  blurRadius: 60,
                  offset: const Offset(0, 0),
                  spreadRadius: -20,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    if (_trainerClasses.isNotEmpty) ...[
                      _buildClassDropdown(),
                      const SizedBox(height: 20),
                      _buildTitleField(),
                      const SizedBox(height: 20),
                      _buildContentField(),
                      const SizedBox(height: 32),
                      _buildErrorSuccessMessages(),
                      _buildPostButton(),
                    ] else
                      _buildNoClassesMessage(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF8C00).withOpacity(0.1),
                const Color(0xFFFF7A00).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF8C00).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: const Icon(
            FontAwesomeIcons.bullhorn,
            color: Color(0xFFFF8C00),
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Create Announcement",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Share important updates with your class",
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildClassDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Select Class *',
          labelStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              FontAwesomeIcons.chalkboardUser,
              color: Color(0xFFFF8C00),
              size: 18,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        value: _selectedClassId,
        hint: const Text("-- Choose a Class --"),
        isExpanded: true,
        items: _trainerClasses.map((Map<String, dynamic> cls) {
          return DropdownMenuItem<String>(
            value: cls['id'] as String,
            child: Text(
              cls['className'] as String? ?? 'Unnamed Class',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedClassId = newValue;
            _postError = null;
          });
        },
        validator: (value) => value == null ? 'Please select a class' : null,
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: _titleController,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          labelText: 'Announcement Title *',
          labelStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              FontAwesomeIcons.heading,
              color: Color(0xFFFF8C00),
              size: 18,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a title';
          }
          return null;
        },
        enabled: !_isPosting,
      ),
    );
  }

  Widget _buildContentField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: _contentController,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          labelText: 'Announcement Content *',
          labelStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              FontAwesomeIcons.alignLeft,
              color: Color(0xFFFF8C00),
              size: 18,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          alignLabelWithHint: true,
        ),
        maxLines: 5,
        minLines: 3,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter content for the announcement';
          }
          return null;
        },
        enabled: !_isPosting,
      ),
    );
  }

  Widget _buildErrorSuccessMessages() {
    return Column(
      children: [
        if (_postError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.triangleExclamation,
                    color: Color(0xFFEF4444),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _postError!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_postSuccess != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.checkCircle,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _postSuccess!,
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPostButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFFF8C00).withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 0),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isPosting || _trainerClasses.isEmpty) ? null : _handlePostAnnouncement,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isPosting
              ? const Color(0xFF94A3B8)
              : const Color(0xFFFF8C00),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isPosting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Posting...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.paperPlane,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Post Announcement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNoClassesMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF8C00).withOpacity(0.1),
            const Color(0xFFFF7A00).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF8C00).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              FontAwesomeIcons.chalkboardUser,
              color: Color(0xFFFF8C00),
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Classes Available",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "You need to create a class before posting announcements.",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}