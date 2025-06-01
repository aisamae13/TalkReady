import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';

// Firebase Service functions
Future<Map<String, dynamic>> getClassDetails(String classId) async {
  final doc = await FirebaseFirestore.instance.collection('classes').doc(classId).get();
  if (!doc.exists) throw Exception("Class not found");
  return {'id': doc.id, ...doc.data()!};
}

Future<void> updateTrainerClass(String classId, Map<String, dynamic> data) async {
  await FirebaseFirestore.instance.collection('classes').doc(classId).update(data);
}

class EditClassPage extends StatefulWidget {
  final String classId;

  const EditClassPage({super.key, required this.classId});

  @override
  State<EditClassPage> createState() => _EditClassPageState();
}

class _EditClassPageState extends State<EditClassPage> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Controllers
  final _classNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();

  // State variables
  bool _initialLoading = true;
  bool _isUpdating = false;
  String? _error;
  String? _success;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchClassData();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _classNameController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _fetchClassData() async {
    if (_currentUser == null) {
      setState(() {
        _error = "Authentication required.";
        _initialLoading = false;
      });
      return;
    }

    setState(() {
      _initialLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final details = await getClassDetails(widget.classId);
      if (details['trainerId'] != _currentUser!.uid) {
        setState(() {
          _error = "You are not authorized to edit this class.";
          _initialLoading = false;
        });
        return;
      }

      setState(() {
        _classNameController.text = details['className'] as String? ?? '';
        _descriptionController.text = details['description'] as String? ?? '';
        _subjectController.text = details['subject'] as String? ?? '';
        _initialLoading = false;
      });

      // Start animations after data is loaded
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _error = "Failed to load class details: ${e.toString()}";
        _initialLoading = false;
      });
    }
  }

  Future<void> _handleUpdateClass() async {
    if (_currentUser == null) {
      setState(() => _error = "Authentication error. Please log in again.");
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUpdating = true;
        _error = null;
        _success = null;
      });

      final updatedData = {
        'className': _classNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'subject': _subjectController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        await updateTrainerClass(widget.classId, updatedData);
        setState(() {
          _success = 'Class "${_classNameController.text}" updated successfully!';
        });
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } catch (e) {
        setState(() {
          _error = 'Failed to update class: ${e.toString()}';
        });
      } finally {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    if (_initialLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
                Color(0xFFf093fb),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  "Loading class details...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(isSmallScreen),
              Expanded(
                child: _buildFormContent(isSmallScreen),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.arrowLeft,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Edit Class",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_classNameController.text.isNotEmpty)
                        Text(
                          _classNameController.text,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent(bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) _buildErrorMessage(),
                        if (_success != null) _buildSuccessMessage(),
                        _buildFormField(
                          controller: _classNameController,
                          label: 'Class Name',
                          icon: FontAwesomeIcons.chalkboardUser,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a class name.';
                            }
                            return null;
                          },
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 24),
                        _buildFormField(
                          controller: _descriptionController,
                          label: 'Description (Optional)',
                          icon: FontAwesomeIcons.alignLeft,
                          maxLines: 3,
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 24),
                        _buildFormField(
                          controller: _subjectController,
                          label: 'Subject/Category (Optional)',
                          icon: FontAwesomeIcons.tag,
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 32 : 40),
                        _buildUpdateButton(isSmallScreen),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade100, Colors.red.shade50],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: Colors.red.shade700,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade100, Colors.green.shade50],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(
              FontAwesomeIcons.circleCheck,
              color: Colors.green.shade700,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _success!,
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        enabled: !_isUpdating,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: isSmallScreen ? 14 : 16,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.5),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.red.shade300,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isSmallScreen ? 16 : 20,
          ),
          errorStyle: TextStyle(
            color: Colors.red.shade200,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton(bool isSmallScreen) {
    return _isUpdating
        ? Container(
            height: isSmallScreen ? 50 : 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          )
        : Container(
            height: isSmallScreen ? 50 : 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4facfe),
                  Color(0xFF00f2fe),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4facfe).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleUpdateClass,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.floppyDisk,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}