import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../notification_service.dart';

Future<Map<String, dynamic>?> getAnnouncementById(String announcementId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('classAnnouncements')
        .doc(announcementId)
        .get();

    if (doc.exists) {
      return {'id': doc.id, ...doc.data()!};
    }
    return null;
  } catch (e) {
    throw Exception("Failed to load announcement: ${e.toString()}");
  }
}

Future<void> updateClassAnnouncement({
  required String announcementId,
  required String title,
  required String content,
  required String trainerId,
  required String classId,
  String? className,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('classAnnouncements')
        .doc(announcementId)
        .update({
      'title': title,
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
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

    // Notify students about the update
    await NotificationService.createNotificationsForStudents(
      classId: classId,
      message: '$trainerName updated an announcement: $title',
      className: className,
      link: '/student/class/$classId#announcements',
    );
  } catch (e) {
    throw Exception("Failed to update announcement: ${e.toString()}");
  }
}

class EditAnnouncementPage extends StatefulWidget {
  final String announcementId;

  const EditAnnouncementPage({
    super.key,
    required this.announcementId,
  });

  @override
  _EditAnnouncementPageState createState() => _EditAnnouncementPageState();
}

class _EditAnnouncementPageState extends State<EditAnnouncementPage>
    with TickerProviderStateMixin {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  Map<String, dynamic>? _announcement;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _loadError;
  String? _updateError;
  String? _updateSuccess;
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
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _loadAnnouncement();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncement() async {
    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
        _loadError = "User not logged in. Please log in to edit announcements.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final announcement = await getAnnouncementById(widget.announcementId);

      if (announcement == null) {
        setState(() {
          _loadError = "Announcement not found.";
          _isLoading = false;
        });
        return;
      }

      // Verify the trainer owns this announcement
      if (announcement['trainerId'] != _currentUser.uid) {
        setState(() {
          _loadError = "You don't have permission to edit this announcement.";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _announcement = announcement;
        _titleController.text = announcement['title'] ?? '';
        _contentController.text = announcement['content'] ?? '';
        _isLoading = false;
      });

      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

Future<void> _handleUpdateAnnouncement() async {
  if (_currentUser == null) {
    setState(() {
      _updateError = "User not logged in.";
    });
    return;
  }

  if (_formKey.currentState?.validate() ?? false) {
    setState(() {
      _isUpdating = true;
      _updateError = null;
      _updateSuccess = null;
    });

    try {
      await updateClassAnnouncement(
        announcementId: widget.announcementId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        trainerId: _currentUser.uid,
        classId: _announcement!['classId'], // Add this
        className: _announcement!['className'], // Add this
      );

        if (mounted) {
          setState(() {
            _updateSuccess = "Announcement updated successfully!";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(FontAwesomeIcons.checkCircle,
                      color: Colors.white, size: 16),
                  SizedBox(width: 12),
                  Text("Announcement updated!",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
            _updateError = e.toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(FontAwesomeIcons.triangleExclamation,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text("Error: ${e.toString()}",
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUpdating = false;
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    'Your announcement has been updated successfully.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
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
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(); // Go back to previous page
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
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
      canPop: !_isUpdating,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _isUpdating) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please wait for the announcement to finish updating',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFFFF8C00),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
            child: _isLoading
                ? _buildLoadingIndicator("Loading announcement...")
                : _loadError != null
                    ? _buildErrorDisplay(_loadError!)
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
        'Edit Announcement',
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
        onPressed: _isUpdating
            ? null
            : () {
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

  Widget _buildErrorDisplay(String error) {
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
              "Error Loading Announcement",
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
                icon: const Icon(FontAwesomeIcons.arrowLeft, size: 16),
                label: const Text('Go Back'),
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
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
                    _buildClassInfoDisplay(),
                    const SizedBox(height: 20),
                    _buildTitleField(),
                    const SizedBox(height: 20),
                    _buildContentField(),
                    const SizedBox(height: 32),
                    _buildErrorSuccessMessages(),
                    _buildUpdateButton(),
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
            FontAwesomeIcons.penToSquare,
            color: Color(0xFFFF8C00),
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Edit Announcement",
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
          "Update your class announcement",
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

  Widget _buildClassInfoDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF8C00).withOpacity(0.05),
            const Color(0xFFFF7A00).withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF8C00).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              FontAwesomeIcons.chalkboardUser,
              color: Color(0xFFFF8C00),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Class',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _announcement?['className'] ?? 'Unknown Class',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a title';
          }
          return null;
        },
        enabled: !_isUpdating,
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
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
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
        enabled: !_isUpdating,
      ),
    );
  }

  Widget _buildErrorSuccessMessages() {
    return Column(
      children: [
        if (_updateError != null)
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
                    _updateError!,
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
        if (_updateSuccess != null)
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
                    _updateSuccess!,
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

  Widget _buildUpdateButton() {
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
        onPressed: _isUpdating ? null : _handleUpdateAnnouncement,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isUpdating ? const Color(0xFF94A3B8) : const Color(0xFFFF8C00),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isUpdating
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
                    'Updating...',
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
                      FontAwesomeIcons.floppyDisk,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Update Announcement',
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
}