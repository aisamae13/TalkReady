import 'package:animations/animations.dart';
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
import 'dart:ui'; // Add this import for BackdropFilter

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({Key? key}) : super(key: key);

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final int _selectedIndex = 0;
  bool loading = true;
  String? error;
  int activeClassesCount = 0;
  int totalStudents = 0;
  int pendingSubmissions = 0;
  List<Map<String, dynamic>> recentClasses = [];

  // Add this variable:
  String? firstName;

  @override
  void initState() {
    super.initState();
    fetchUserFirstName();
    fetchDashboardData();
  }

  // Add this method to fetch firstName from Firestore:
  Future<void> fetchUserFirstName() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (doc.exists) {
        setState(() {
          firstName = doc.data()?['firstName'] ?? "Trainer";
        });
      }
    } catch (e) {
      setState(() {
        firstName = "Trainer";
      });
    }
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
          Text(
            "Welcome back, ${firstName ?? 'Trainer'}!",
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.blue[800]),
          ),
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
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _quickAction(context, "My Classes", FontAwesomeIcons.layerGroup,
                  "/trainer/classes", Colors.purple),
              _quickAction(context, "Create Class", FontAwesomeIcons.plusCircle,
                  "/trainer/classes/create", Colors.blue),
              _quickAction(context, "Upload", FontAwesomeIcons.upload,
                  "/trainer/content/upload", Colors.teal),
              _quickAction(context, "Assessment", FontAwesomeIcons.filePen,
                  "/create-assessment", Colors.indigo),
              _quickAction(context, "Reports", FontAwesomeIcons.chartLine,
                  "/trainer/reports", Colors.green),
              _quickAction(context, "Announce", FontAwesomeIcons.bullhorn,
                  "/trainer/announcements/create", Colors.orange),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            "My Recent Classes",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (recentClasses.isEmpty && !loading)
            Center(
              child: Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: SizedBox(
                  width: 320, // Slightly wider card
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          "No classes found.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Create a class to get started!",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ...recentClasses.map((cls) => _recentClassCard(context, cls)),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 260,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.indigo.withOpacity(0.18),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.pushNamed(context, '/trainer/classes'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.10),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(FontAwesomeIcons.cog, color: Colors.indigo, size: 22),
                      ),
                      const SizedBox(width: 16),
                      const Flexible(
                        child: Text(
                          "Manage All Classes",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  // 1. Use a constant for border radius and padding
  static const double kCardRadius = 16.0;
  static const EdgeInsets kCardPadding = EdgeInsets.all(12.0);
  static const double kButtonRadius = 12.0;
  static const EdgeInsets kButtonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  // 2. Update _buildStatCard for uniformity
  Widget _buildStatCard(
      String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      child: Container(
        height: 150, // Increased height to fully prevent overflow
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), // Slightly reduced padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.13),
              child: Icon(icon, color: color, size: 24),
              radius: 22,
            ),
            const SizedBox(height: 4), // Reduced spacing
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              "$value",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, String label, IconData icon,
      String route, Color color) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      openColor: Colors.white,
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      closedBuilder: (context, action) => _QuickActionButton(
        label: label,
        icon: icon,
        color: color,
        onTap: action,
      ),
      openBuilder: (context, action) {
        // Return the actual page/widget you want to show
        switch (route) {
          case "/trainer/classes":
            return const MyClassesPage();
          case "/trainer/classes/create":
            return const CreateClassForm();
          case "/trainer/content/upload":
            return const QuickUploadMaterialPage();
          case "/create-assessment":
            return const CreateAssessmentPage(initialClassId: null);
          case "/trainer/reports":
            return const TrainerReportsPage();
          case "/trainer/announcements/create":
            return const CreateAnnouncementPage();
          default:
            return const SizedBox.shrink();
        }
      },
      tappable: true,
      transitionDuration: const Duration(milliseconds: 400),
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
              spacing: 10,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(FontAwesomeIcons.fileLines, size: 16, color: Colors.teal),
                  onPressed: () => Navigator.pushNamed(
                      context, '/trainer/classes/$classId/content'),
                  label: const Text("Content"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kButtonRadius)),
                    padding: kButtonPadding,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(FontAwesomeIcons.usersCog, size: 16, color: Colors.orange),
                  onPressed: () => Navigator.pushNamed(
                      context, '/trainer/classes/$classId/students'),
                  label: const Text("Students"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kButtonRadius)),
                    padding: kButtonPadding,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(FontAwesomeIcons.listCheck, size: 16, color: Colors.indigo),
                  onPressed: () => Navigator.pushNamed(
                      context, '/class/$classId/assessments', arguments: classId),
                  label: const Text("Assessments"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: const BorderSide(color: Colors.indigo, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kButtonRadius)),
                    padding: kButtonPadding,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class AnimatedQuickAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  final void Function()? onTap;

  const AnimatedQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
    this.onTap,
  });

  @override
  State<AnimatedQuickAction> createState() => _AnimatedQuickActionState();
}

class _AnimatedQuickActionState extends State<AnimatedQuickAction> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _elevationAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _elevationAnim = Tween<double>(begin: 10, end: 26).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _pressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _pressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double kCardRadius = 22.0;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(_pressed ? kCardRadius + 8 : kCardRadius),
                border: Border.all(
                  color: widget.color.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.13),
                    blurRadius: _elevationAnim.value,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kCardRadius + 8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(kCardRadius + 8),
                      splashColor: widget.color.withOpacity(0.13),
                      highlightColor: Colors.transparent,
                      onTap: widget.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.color.withOpacity(0.10),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Icon(widget.icon, color: widget.color, size: 30),
                            ),
                            const SizedBox(height: 14),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double kCardRadius = 22.0;
    return InkWell(
      borderRadius: BorderRadius.circular(kCardRadius + 8),
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(
            color: color.withOpacity(0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}