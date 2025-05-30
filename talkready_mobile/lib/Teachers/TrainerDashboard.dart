import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'TrainerProfile.dart';
import 'Assessment/ClassAssessmentsListPage.dart';
import 'Assessment/CreateAssessmentPage.dart';
import 'Assessment/ViewAssessmentResultsPage.dart';
// Import ClassManager pages that might be directly navigated to from dashboard actions
import 'ClassManager/MyClassesPage.dart';
import 'ClassManager/CreateClassForm.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({Key? key}) : super(key: key);

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0; // 0: Home, 1: Profile
  bool loading = true;
  String? error;
  int activeClassesCount = 0;
  int totalStudents = 0; // Placeholder
  int pendingSubmissions = 0; // Placeholder
  List<Map<String, dynamic>> recentClasses = [];

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    if (currentUser == null) {
      setState(() {
        error = "User not found. Please re-login.";
        loading = false;
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('trainerId', isEqualTo: currentUser!.uid)
          .get();

      final classes = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
      classes.sort((a, b) => (b['createdAt'] as Timestamp?)?.toDate().compareTo(
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0)) ??
          0);

      // Calculate total students
      int currentTotalStudents = 0;
      for (var cls in classes) {
        currentTotalStudents += (cls['studentCount'] as int? ?? 0);
      }

      setState(() {
        activeClassesCount = classes.length;
        recentClasses = classes.take(3).toList();
        totalStudents = currentTotalStudents;
        // Optional: calculate student count from data
      });
    } catch (e) {
      setState(() {
        error = "Could not load dashboard data. ${e.toString()}";
        recentClasses = [];
        activeClassesCount = 0;
        totalStudents = 0;
      });
    } finally {
      if(mounted){
        setState(() => loading = false);
      }
    }
  }

  List<BottomNavigationBarItem> _bottomNavBarItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  Widget _getBody() {
    if (_selectedIndex == 0) {
      if (currentUser == null) {
        return loadingScreen("Initializing Dashboard...");
      }
      if (loading) {
        return loadingScreen("Loading Trainer Dashboard...");
      }
      if (error != null) {
        return errorScreen(error!, fetchDashboardData);
      }
      final firstName = currentUser!.displayName?.split(" ").first ?? "Trainer";
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome back, $firstName!",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: Colors.blue[800])),
            const SizedBox(height: 8),
            const Text("Here's an overview of your activities and tools."),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard("Active Classes", activeClassesCount,
                      FontAwesomeIcons.chalkboardUser, Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard("Total Students", totalStudents,
                      FontAwesomeIcons.users, Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard("Pending Submissions", pendingSubmissions,
                      FontAwesomeIcons.fileCircleCheck, Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text("Quick Actions",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _quickAction(context, "My Classes", FontAwesomeIcons.layerGroup,
                    "/trainer/classes", Colors.purple),
                _quickAction(context, "Create Class", FontAwesomeIcons.plusCircle,
                    "/trainer/classes/create", Colors.blue),
                _quickAction(context, "Upload Materials", // Placeholder route, adjust as needed
                    FontAwesomeIcons.upload, "/upload", Colors.teal),
                _quickAction(context, "Create Assessment",
                    FontAwesomeIcons.filePen, "/create-assessment", Colors.indigo),
                _quickAction(context, "Student Reports", // Placeholder route
                    FontAwesomeIcons.chartLine, "/reports", Colors.green),
                _quickAction(context, "Announcement", // Placeholder route
                    FontAwesomeIcons.bullhorn, "/announcement", Colors.orange),
              ],
            ),
            const SizedBox(height: 32),
            const Text("My Recent Classes",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            if (recentClasses.isEmpty && !loading)
              const Center(child: Text("No classes found.")),
            ...recentClasses.map((cls) => _recentClassCard(context, cls)),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/trainer/classes'),
                icon: const Icon(FontAwesomeIcons.cog),
                label: const Text("Manage All Classes"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            )
          ],
        ),
      );
    } else {
      // Navigate to TrainerProfile page
      // Using Future.microtask to ensure setState is not called during build
      Future.microtask(() {
        // Check if the current route is already TrainerProfile to avoid pushing it again
        // This is a simple check; more robust solutions might involve route observers
        // or a different state management approach for the bottom navigation.
        if (ModalRoute.of(context)?.settings.name != '/trainer-profile') {
             Navigator.pushReplacement( // Using pushReplacement to avoid building up stack
                context,
                MaterialPageRoute(builder: (context) => const TrainerProfile()),
             );
        }
      });
      // Return a placeholder while navigation happens
      return const Center(child: CircularProgressIndicator());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(child: _getBody()),
      bottomNavigationBar: BottomNavigationBar(
        items: _bottomNavBarItems(),
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        onTap: (index) {
          if (_selectedIndex == index && index == 1) {
            // If already on profile tab and tapped again, do nothing or refresh profile
            return;
          }
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget loadingScreen(String message) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(message),
            ],
          ),
        ),
      );

  Widget errorScreen(String errorMsg, VoidCallback onRetry) => Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FontAwesomeIcons.triangleExclamation,
                    size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(errorMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Try Again"),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildStatCard(
      String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              softWrap: true,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              "$value",
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, String label, IconData icon,
      String route, Color color) {
    return GestureDetector(
      onTap: () {
          if (route == "/create-assessment") {
             Navigator.pushNamed(context, route, arguments: {'initialClassId': null}); // Pass null if no specific class context
          } else {
             Navigator.pushNamed(context, route);
          }
      },
      child: Container(
        width: MediaQuery.of(context).size.width / 3.8, // Adjust width as needed
        constraints: const BoxConstraints(minHeight: 100), // Ensure minimum height
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 3),
              )
            ]),
        child: Padding(
          padding: const EdgeInsets.all(8.0), // Add padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentClassCard(BuildContext context, Map<String, dynamic> cls) {
    final className = cls['className'] ?? 'Untitled Class';
    final studentCount = cls['studentCount'] ?? 0;
    final date = (cls['createdAt'] as Timestamp?)?.toDate();
    final classId = cls['id'] as String?;

    if (classId == null) {
      return const Card(child: ListTile(title: Text("Error: Class ID missing")));
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(className,
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue[700])),
            const SizedBox(height: 4),
            Text("$studentCount Student${studentCount == 1 ? '' : 's'}",
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            if (date != null)
              Text("Created: ${date.toLocal().toString().split(' ')[0]}",
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                TextButton.icon(
                    icon: const Icon(FontAwesomeIcons.fileLines, size: 16),
                    onPressed: () => Navigator.pushNamed(
                        context, '/trainer/classes/$classId/content'),
                    label: const Text("Content"),
                    style: TextButton.styleFrom(foregroundColor: Colors.teal)),
                TextButton.icon(
                    icon: const Icon(FontAwesomeIcons.usersCog, size: 16),
                    onPressed: () => Navigator.pushNamed(
                        context, '/trainer/classes/$classId/students'),
                    label: const Text("Students"),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange)),
                TextButton.icon(
                    icon: const Icon(FontAwesomeIcons.listCheck, size: 16),
                    onPressed: () => Navigator.pushNamed(
                        context, '/class/$classId/assessments', arguments: classId),
                    label: const Text("Assessments"),
                    style: TextButton.styleFrom(foregroundColor: Colors.indigo)),
              ],
            )
          ],
        ),
      ),
    );
  }
}