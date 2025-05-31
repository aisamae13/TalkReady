import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'TrainerProfile.dart';
import 'Assessment/ClassAssessmentsListPage.dart';
import 'Assessment/CreateAssessmentPage.dart';
import 'Assessment/ViewAssessmentResultsPage.dart';
import 'ClassManager/MyClassesPage.dart';
import 'ClassManager/CreateClassForm.dart';
import '../custom_animated_bottom_bar.dart'; // <-- Import AnimatedBottomNavBar
import 'Reports/TrainerReports.dart'; // <-- Import TrainerReportsPage
import 'Announcement/CreateAnnouncementPage.dart'; // <-- Import CreateAnnouncementPage
import 'package:talkready_mobile/Teachers/Contents/QuickUploadMaterialPage.dart';
import 'package:talkready_mobile/Teachers/Contents/SelectClassForContentPage.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({Key? key}) : super(key: key);

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final int _selectedIndex = 0; // Dashboard is always index 0 for this page
  bool loading = true;
  String? error;
  int activeClassesCount = 0;
  int totalStudents = 0;
  int pendingSubmissions = 0;
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

      int currentTotalStudents = 0;
      for (var cls in classes) {
        currentTotalStudents += (cls['studentCount'] as int? ?? 0);
      }

      setState(() {
        activeClassesCount = classes.length;
        recentClasses = classes.take(3).toList();
        totalStudents = currentTotalStudents;
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

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // Already on this page or same index

    Widget nextPage;
    switch (index) {
      case 0:
        // Should not happen if _selectedIndex is 0, but as a fallback:
        nextPage = const TrainerDashboard();
        break;
      case 1:
        nextPage = const TrainerProfile();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child; // No page transition animation
        },
        transitionDuration: Duration.zero,
      ),
    );
  }

  Widget _buildDashboardContent() {
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
              _quickAction(context, "Upload Materials",
                  FontAwesomeIcons.upload, "/trainer/content/upload", Colors.teal),
              _quickAction(context, "Create Assessment",
                  FontAwesomeIcons.filePen, "/create-assessment", Colors.indigo),
              _quickAction(context, "Student Reports",
                  FontAwesomeIcons.chartLine, "/trainer/reports", Colors.green), // Updated route
              _quickAction(context, "Announcement",
                  FontAwesomeIcons.bullhorn, "/trainer/announcements/create", Colors.orange), // Updated route
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar( // Added AppBar for context
        title: const Text("Trainer Dashboard"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // No back button if this is a top-level tab
      ),
      body: SafeArea(child: _buildDashboardContent()),
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          CustomBottomNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
          CustomBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        activeColor: Colors.white, // Icon color on the notch
        inactiveColor: Colors.grey[600]!,
        notchColor: Colors.blue[700]!, // Color of the notch (active item background)
        backgroundColor: Colors.white,
        selectedIconSize: 28.0,
        iconSize: 25.0,
        barHeight: 55,
        selectedIconPadding: 10,
        animationDuration: const Duration(milliseconds: 300),
        customNotchWidthFactor: 0.5, // <-- Added this line
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
             Navigator.pushNamed(context, route, arguments: {'initialClassId': null});
          } else if (route == "/trainer/announcements/create") { // Specific handling if needed, otherwise general pushNamed is fine
             Navigator.pushNamed(context, route);
          }
          else {
             Navigator.pushNamed(context, route);
          }
      },
      child: Container(
        width: MediaQuery.of(context).size.width / 3.8,
        constraints: const BoxConstraints(minHeight: 100),
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
          padding: const EdgeInsets.all(8.0),
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