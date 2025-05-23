import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'TrainerProfile.dart';

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

      final classes = snapshot.docs.map((doc) => doc.data()).toList();
      classes.sort((a, b) => (b['createdAt'] as Timestamp?)?.toDate().compareTo(
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0)) ??
          0);

      setState(() {
        activeClassesCount = classes.length;
        recentClasses = classes.take(3).toList();
        // Optional: calculate student count from data
      });
    } catch (e) {
      setState(() {
        error = "Could not load dashboard data.";
        recentClasses = [];
        activeClassesCount = 0;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  // BottomNavigationBar items for Home and Profile
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

  // Switch between Home and Profile
  Widget _getBody() {
    if (_selectedIndex == 0) {
      // Home Dashboard
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard("Active Classes", activeClassesCount,
                    FontAwesomeIcons.users, Colors.blue),
                _buildStatCard("Total Students", totalStudents,
                    FontAwesomeIcons.users, Colors.green),
                _buildStatCard("Pending Submissions", pendingSubmissions,
                    FontAwesomeIcons.tasks, Colors.orange),
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
                _quickAction(context, "Create Class", FontAwesomeIcons.plusCircle,
                    "/create-class", Colors.blue),
                _quickAction(context, "Upload Materials",
                    FontAwesomeIcons.upload, "/upload", Colors.teal),
                _quickAction(context, "Create Assessment",
                    FontAwesomeIcons.tasks, "/new-assessment", Colors.indigo),
                _quickAction(context, "Student Reports",
                    FontAwesomeIcons.chartLine, "/reports", Colors.green),
                _quickAction(context, "Announcement",
                    FontAwesomeIcons.bullhorn, "/announcement", Colors.orange),
                _quickAction(context, "Manage Content",
                    FontAwesomeIcons.bookOpen, "/content", Colors.purple),
              ],
            ),
            const SizedBox(height: 32),
            const Text("My Recent Classes",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            ...recentClasses.map((cls) => _recentClassCard(context, cls)),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/cms-dashboard'),
                icon: const Icon(FontAwesomeIcons.cog),
                label: const Text("Access Full CMS Dashboard"),
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
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const TrainerProfile()),
        );
      });
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
        onTap: (index) {
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
                    style: const TextStyle(color: Colors.red, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text("$value",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, String label, IconData icon,
      String route, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _recentClassCard(BuildContext context, Map<String, dynamic> cls) {
    final className = cls['className'] ?? 'Untitled';
    final studentCount = cls['studentCount'] ?? 0;
    final date = (cls['createdAt'] as Timestamp?)?.toDate();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(className,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("$studentCount Student${studentCount == 1 ? '' : 's'}",
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            if (date != null)
              Text("Created: ${date.toLocal().toString().split(' ')[0]}",
                  style: const TextStyle(fontSize: 12, color: Colors.black38)),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                    onPressed: () => Navigator.pushNamed(
                        context, '/class/${cls['id']}/content'),
                    child: const Text("Manage Content")),
                TextButton(
                    onPressed: () => Navigator.pushNamed(
                        context, '/class/${cls['id']}/students'),
                    child: const Text("Manage Students")),
              ],
            )
          ],
        ),
      ),
    );
  }
}