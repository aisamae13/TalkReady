import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:logger/logger.dart';
// Add these imports for navigation
import 'package:talkready_mobile/custom_animated_bottom_bar.dart';
import 'package:talkready_mobile/journal/journal_page.dart';
import 'homepage.dart';
import 'courses_page.dart';
import 'progress_page.dart';
import 'profile.dart';


class MyEnrolledClasses extends StatefulWidget {
  const MyEnrolledClasses({super.key});

  @override
  State<MyEnrolledClasses> createState() => _MyEnrolledClassesState();
}

class _MyEnrolledClassesState extends State<MyEnrolledClasses>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Controllers and Animation
  final TextEditingController _classCodeController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  List<Map<String, dynamic>> enrolledClasses = [];
  bool loading = true;
  String error = '';
  String joinError = '';
  String joinSuccess = '';
  bool isJoining = false;

  // Add navigation state
  int _selectedIndex = 2; // My Classes is index 2

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchClasses();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _classCodeController.dispose();
    super.dispose();
  }

  // Update the navigation method
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const HomePage();
        break;
      case 1:
        nextPage = const CoursesPage();
        break;
      case 2:
        // Already on MyEnrolledClasses
        return;
      case 3:
        nextPage = const JournalPage(); // Restore Journal
        break;
      case 4:
        nextPage = const ProgressTrackerPage();
        break;
      case 5:
        nextPage = const ProfilePage();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // Add the custom app bar with logo
  Widget _buildAppBarWithLogo() {
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0077B3),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            'images/TR Logo.png',
            height: 40,
            width: 40,
          ),
          const SizedBox(width: 12),
          const Text(
            'My Classes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> fetchClasses() async {
    final User? currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      setState(() {
        loading = false;
        error = "Please log in to see your enrolled classes.";
        enrolledClasses = [];
      });
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      final fetchedClasses = await getStudentEnrolledClasses(currentUser.uid);
      fetchedClasses.sort((a, b) => 
          (a['className'] ?? '').compareTo(b['className'] ?? ''));
      
      if (mounted) {
        setState(() {
          enrolledClasses = fetchedClasses;
          loading = false;
        });
      }
    } catch (err) {
      _logger.e("Error fetching student's enrolled classes: $err");
      if (mounted) {
        setState(() {
          error = "Failed to load your classes. Please try again.";
          enrolledClasses = [];
          loading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getStudentEnrolledClasses(String studentId) async {
    try {
      // Query classes where the student is enrolled
      final QuerySnapshot classesSnapshot = await _firestore
          .collection('trainerClass')
          .where('student', arrayContains: studentId)
          .get();

      List<Map<String, dynamic>> classes = [];
      
      for (QueryDocumentSnapshot classDoc in classesSnapshot.docs) {
        Map<String, dynamic> classData = classDoc.data() as Map<String, dynamic>;
        classData['id'] = classDoc.id;
        
        // Get trainer information
        String? trainerId = classData['trainerId'];
        if (trainerId != null) {
          try {
            DocumentSnapshot trainerDoc = await _firestore
                .collection('users')
                .doc(trainerId)
                .get();
            
            if (trainerDoc.exists) {
              Map<String, dynamic> trainerData = trainerDoc.data() as Map<String, dynamic>;
              classData['trainerName'] = trainerData['displayName'] ?? 
                                        trainerData['name'] ?? 
                                        'Unknown Trainer';
            }
          } catch (e) {
            _logger.w("Could not fetch trainer data for class ${classDoc.id}: $e");
            classData['trainerName'] = 'Unknown Trainer';
          }
        }
        
        // Add student count
        List<dynamic> student = classData['student'] ?? [];
        classData['studentCount'] = student.length;
        
        classes.add(classData);
      }
      
      return classes;
    } catch (e) {
      _logger.e("Error in getStudentEnrolledClasses: $e");
      rethrow;
    }
  }

  Future<void> handleJoinClass() async {
    final String classCode = _classCodeController.text.trim();
    
    if (classCode.isEmpty) {
      setState(() {
        joinError = "Please enter a class code.";
        joinSuccess = '';
      });
      return;
    }

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        joinError = "You must be logged in to join a class.";
        joinSuccess = '';
      });
      return;
    }

    setState(() {
      isJoining = true;
      joinError = '';
      joinSuccess = '';
    });

    try {
      final result = await joinClassWithCode(currentUser.uid, classCode);
      
      if (mounted) {
        setState(() {
          joinSuccess = result['message'] ?? 
                       'Successfully joined "${result['className']}"!';
          _classCodeController.clear();
        });
        
        // Refresh the list of enrolled classes
        fetchClasses();
      }
    } catch (err) {
      _logger.e("Error joining class with code: $err");
      if (mounted) {
        setState(() {
          joinError = err.toString().contains('Exception: ') 
              ? err.toString().replaceFirst('Exception: ', '')
              : "Failed to join class. Please check the code and try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isJoining = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> joinClassWithCode(String studentId, String classCode) async {
    try {
      // Find class by code
      final QuerySnapshot classQuery = await _firestore
          .collection('trainerClass')
          .where('classCode', isEqualTo: classCode.toUpperCase())
          .limit(1)
          .get();

      if (classQuery.docs.isEmpty) {
        throw Exception("Invalid class code. Please check and try again.");
      }

      final DocumentSnapshot classDoc = classQuery.docs.first;
      final Map<String, dynamic> classData = classDoc.data() as Map<String, dynamic>;
      
      // Check if student is already enrolled
      List<dynamic> currentStudent = classData['student'] ?? [];
      if (currentStudent.contains(studentId)) {
        throw Exception("You are already enrolled in this class.");
      }

      // Add student to the class
      await _firestore.collection('trainerClass').doc(classDoc.id).update({
        'student': FieldValue.arrayUnion([studentId])
      });

      return {
        'message': 'Successfully joined class!',
        'className': classData['className'] ?? 'Unnamed Class',
        'classId': classDoc.id,
      };
    } catch (e) {
      _logger.e("Error in joinClassWithCode: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // Remove the default AppBar and use custom header
      body: Column(
        children: [
          _buildAppBarWithLogo(), // Add the custom header with logo
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Join Class Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
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
                                FaIcon(
                                  FontAwesomeIcons.key,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Join a New Class',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Join Form
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _classCodeController,
                                    enabled: !isJoining,
                                    textCapitalization: TextCapitalization.characters,
                                    onChanged: (value) {
                                      setState(() {
                                        joinError = '';
                                        joinSuccess = '';
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Enter Class Code',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.blue[600]!),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: isJoining || _classCodeController.text.trim().isEmpty
                                      ? null
                                      : handleJoinClass,
                                  icon: isJoining
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const FaIcon(FontAwesomeIcons.signInAlt, size: 16),
                                  label: const Text('Join Class'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Error/Success Messages
                            if (joinError.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  joinError,
                                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                                ),
                              ),
                            ],
                            if (joinSuccess.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  joinSuccess,
                                  style: TextStyle(color: Colors.green[700], fontSize: 14),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Section Header
                      Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.chalkboardTeacher,
                            color: Color(0xFF0077B3),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'My Enrolled Classes',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF0077B3),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Content
                      if (loading)
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF0077B3),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading your classes...',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else if (error.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                              left: BorderSide(color: Colors.red, width: 4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.exclamationTriangle,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Error',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    Text(
                                      error,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (enrolledClasses.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 1200
                                ? 3
                                : MediaQuery.of(context).size.width > 800
                                    ? 2
                                    : 1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: enrolledClasses.length,
                          itemBuilder: (context, index) {
                            final cls = enrolledClasses[index];
                            return _buildClassCard(cls, theme);
                          },
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              style: BorderStyle.solid,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.chalkboardTeacher,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'You are not currently enrolled in any classes by a trainer.',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Once a trainer enrolls you, your classes will appear here.\nYou can also join a class using a code if provided by your trainer.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Update the bottom navigation bar
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          CustomBottomNavItem(icon: Icons.home, label: 'Home'),
          CustomBottomNavItem(icon: Icons.book, label: 'Courses'),
          CustomBottomNavItem(icon: Icons.school, label: 'My Classes'), // Changed from Icons.class_ to Icons.school
          CustomBottomNavItem(icon: Icons.library_books, label: 'Journal'),
          CustomBottomNavItem(icon: Icons.trending_up, label: 'Progress'),
          CustomBottomNavItem(icon: Icons.person, label: 'Profile'),
        ],
        activeColor: Colors.white,
        inactiveColor: Colors.grey[600]!,
        notchColor: const Color(0xFF0077B3),
        backgroundColor: Colors.white,
        selectedIconSize: 28.0,
        iconSize: 25.0,
        barHeight: 55,
        selectedIconPadding: 10,
        animationDuration: const Duration(milliseconds: 300),
        customNotchWidthFactor: 1.8,
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls, ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
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
            Text(
              cls['className'] ?? 'Unnamed Class',
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF0077B3),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
            
            // Trainer Name
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.chalkboardTeacher,
                  size: 14,
                  color: Colors.blue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Trainer: ${cls['trainerName'] ?? 'N/A'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            Text(
              'Subject: ${cls['subject'] ?? 'General'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Expanded(
              child: Text(
                cls['description'] ?? 'No description available.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              'Student: ${cls['studentCount'] ?? 0}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Divider
            Container(
              height: 1,
              color: Colors.grey[200],
            ),
            
            const SizedBox(height: 16),
            
            // View Class Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to class content - you can create a proper class content page
                  // For now, let's navigate to courses page as a placeholder
                  Navigator.pushNamed(
                    context,
                    '/courses', // You can create a specific route for class content later
                    arguments: {'classId': cls['id'], 'className': cls['className']},
                  );
                },
                icon: const FaIcon(FontAwesomeIcons.bookOpen, size: 14),
                label: const Text('View Class'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
    }