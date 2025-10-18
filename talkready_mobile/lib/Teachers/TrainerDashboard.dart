import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'TrainerProfile.dart';
import 'Assessment/CreateAssessmentPage.dart';
import 'ClassManager/MyClassesPage.dart';
import 'ClassManager/CreateClassForm.dart';
import '../custom_animated_bottom_bar.dart';
import 'Reports/TrainerReports.dart';
import 'Announcement/CreateAnnouncementPage.dart';
import '../Teachers/Contents/QuickUploadMaterialPage.dart';
import 'dart:ui';
import 'ClassManager/ManageClassContent.dart';
import 'package:shimmer/shimmer.dart';
import '../all_notifications_page.dart';
import 'package:flutter/services.dart';
import '../notification_badge.dart';
import 'Announcement/AnnouncementListPage.dart';
import 'Authorization/CertificateAuthorizationPage.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

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
  Map<String, dynamic>? mostRecentClass;
  String? firstName;
  int _unreadNotificationsCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>?
  _dashboardSubscription; // NEW: Store dashboard subscription

  @override
  void initState() {
    super.initState();
    fetchUserFirstName();
    _setupRealtimeDashboardListener();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _dashboardSubscription?.cancel(); // NEW: Cancel dashboard subscription
    super.dispose();
  }

  void _setupRealtimeDashboardListener() {
    if (currentUser == null) return;

    _dashboardSubscription?.cancel();

    _dashboardSubscription = FirebaseFirestore.instance
        .collection('trainerClass')
        .where('trainerId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) async {
            if (!mounted) return;

            int classCount = snapshot.docs.length;
            int studentSum = 0;
            Map<String, dynamic>? recentClass;

            // Calculate actual student count from enrollments
            for (var doc in snapshot.docs) {
              final classId = doc.id;
              final enrollmentCount = await FirebaseFirestore.instance
                  .collection('enrollments')
                  .where('classId', isEqualTo: classId)
                  .get();
              studentSum += enrollmentCount.docs.length;
            }

            if (snapshot.docs.isNotEmpty) {
              final doc = snapshot.docs.first;
              final classId = doc.id;

              // Get actual student count for recent class
              final enrollmentCount = await FirebaseFirestore.instance
                  .collection('enrollments')
                  .where('classId', isEqualTo: classId)
                  .get();

              recentClass = {
                'id': doc.id,
                ...doc.data(),
                'studentCount':
                    enrollmentCount.docs.length, // Override with actual count
              };
            }

            // Calculate pending submissions
            int pendingSum = 0;
            try {
              final submissionsQuery = await FirebaseFirestore.instance
                  .collection('studentSubmissions')
                  .where('trainerId', isEqualTo: currentUser!.uid)
                  .where('assessmentType', isEqualTo: 'speaking_assessment')
                  .where('isReviewed', isEqualTo: false)
                  .get();

              pendingSum = submissionsQuery.docs.length;
            } catch (e) {
              print('Error fetching pending submissions: $e');
            }

            setState(() {
              activeClassesCount = classCount;
              totalStudents = studentSum;
              pendingSubmissions = pendingSum;
              mostRecentClass = recentClass;
              loading = false;
              error = null;
            });
          },
          onError: (e) {
            if (!mounted) return;

            setState(() {
              error = "Could not load dashboard data. ${e.toString()}";
              activeClassesCount = 0;
              totalStudents = 0;
              pendingSubmissions = 0;
              loading = false;
            });
          },
        );
  }

  void _setupNotificationListener() {
    if (currentUser == null) {
      debugPrint('❌ No current user - cannot setup notification listener');
      return;
    }

    debugPrint(
      '🔔 Setting up notification listener for user: ${currentUser!.uid}',
    );

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint(
              '📬 Received notification snapshot: ${snapshot.docs.length} unread notifications',
            );

            if (mounted) {
              setState(() {
                _unreadNotificationsCount = snapshot.docs.length;
              });
              debugPrint(
                '✅ Updated unread count to: $_unreadNotificationsCount',
              );
            }
          },
          onError: (e) {
            debugPrint('❌ Error fetching notifications: $e');

            if (e.toString().contains('index')) {
              debugPrint('⚠️ FIRESTORE INDEX REQUIRED! Create an index for:');
              debugPrint('   Collection: notifications');
              debugPrint('   Fields: userId (Ascending), isRead (Ascending)');
            }
          },
        );
  }

  // NEW: Pull-to-refresh handler
  Future<void> _handleRefresh() async {
    debugPrint('🔄 Manual refresh triggered');

    // Refetch user first name
    await fetchUserFirstName();

    // The real-time listener will automatically update the data
    // But we can manually trigger a refresh by re-setting up the listener
    _setupRealtimeDashboardListener();
    _setupNotificationListener();

    // Add a small delay to show the refresh indicator
    await Future.delayed(const Duration(milliseconds: 500));

    debugPrint('✅ Manual refresh completed');
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Text('Exit TalkReady?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit the app?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  Future<void> fetchUserFirstName() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            firstName = doc.data()?['firstName'] ?? "Trainer";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          firstName = "Trainer";
        });
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    Widget nextPage;
    switch (index) {
      case 0:
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
          return child;
        },
        transitionDuration: Duration.zero,
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (currentUser == null) {
      return _buildDashboardWithShimmer();
    }
    if (loading) {
      return _buildDashboardWithShimmer();
    }
    if (error != null) {
      // NEW: Wrap error screen in RefreshIndicator
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: errorScreen(error!, () {
              _setupRealtimeDashboardListener();
            }),
          ),
        ),
      );
    }

    final displayName = firstName ?? "Trainer";

    // NEW: Wrap entire content in RefreshIndicator
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.blue[700],
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(), // NEW: Always allow scrolling for pull-to-refresh
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back, $displayName!",
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.blue[800]),
            ),
            const SizedBox(height: 8),
            const Text("Here's an overview of your activities and tools."),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Active Classes",
                    activeClassesCount,
                    FontAwesomeIcons.chalkboardUser,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    "Total Students",
                    totalStudents,
                    FontAwesomeIcons.users,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    "Pending Submissions",
                    pendingSubmissions,
                    FontAwesomeIcons.fileCircleCheck,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _quickAction(
                  context,
                  "My Classes",
                  FontAwesomeIcons.layerGroup,
                  "/trainer/classes",
                  Colors.purple,
                ),
                _quickAction(
                  context,
                  "Create Class",
                  FontAwesomeIcons.plusCircle,
                  "/trainer/classes/create",
                  Colors.blue,
                ),
                _quickAction(
                  context,
                  "Upload",
                  FontAwesomeIcons.upload,
                  "/trainer/content/upload",
                  Colors.teal,
                ),
                _quickAction(
                  context,
                  "Assessment",
                  FontAwesomeIcons.filePen,
                  "/create-assessment",
                  Colors.indigo,
                ),
                _quickAction(
                  context,
                  "Reports",
                  FontAwesomeIcons.chartLine,
                  "/trainer/reports",
                  Colors.green,
                ),
                _quickAction(
                  context,
                  "Announce",
                  FontAwesomeIcons.bullhorn,
                  "/trainer/announcements/create",
                  Colors.orange,
                ),
                // ✅ ADD THIS NEW ITEM BELOW
                _quickAction(
                  context,
                  "Authorize",
                  FontAwesomeIcons.certificate,
                  "/trainer/authorize",
                  Colors.deepPurple,
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              "My Most Recent Class",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (mostRecentClass == null && !loading)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.grey.shade50, Colors.grey.shade100],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          FontAwesomeIcons.graduationCap,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No classes found",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Create your first class to get started!",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateClassForm(),
                            ),
                          );
                        },
                        icon: const Icon(FontAwesomeIcons.plus, size: 16),
                        label: const Text("Create Class"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (mostRecentClass != null)
              _recentClassCard(context, mostRecentClass!),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        final shouldExit = await _onWillPop();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: _buildAppBar(),
        body: SafeArea(child: _buildDashboardContent()),
        bottomNavigationBar: AnimatedBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            CustomBottomNavItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
            ),
            CustomBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
          ],
          activeColor: Colors.white,
          inactiveColor: Colors.grey[600]!,
          notchColor: Colors.blue[700]!,
          backgroundColor: Colors.white,
          selectedIconSize: 28.0,
          iconSize: 25.0,
          barHeight: 55,
          selectedIconPadding: 10,
          animationDuration: const Duration(milliseconds: 300),
          customNotchWidthFactor: 0.5,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text("Trainer Dashboard"),
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      actions: [
        NotificationBadge(
          unreadCount: _unreadNotificationsCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AllNotificationsPage(),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget loadingScreen(String message) {
    return _buildDashboardWithShimmer();
  }

  Widget errorScreen(String errorMessage, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardWithShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 220,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 280,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatCardShimmer()),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCardShimmer()),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCardShimmer()),
            ],
          ),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 120,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(6, (index) => _buildQuickActionShimmer()),
          ),
          const SizedBox(height: 25),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 180,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentClassCardShimmer(),
        ],
      ),
    );
  }

  Widget _buildStatCardShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }

  Widget _buildRecentClassCardShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 220,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      child: Container(
        height: 150,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
              radius: 22,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
    BuildContext context,
    String label,
    IconData icon,
    String route,
    Color color,
  ) {
    // Special handling for Announce
    if (route == "/trainer/announcements/create") {
      return InkWell(
        onTap: () => _showAnnouncementDialog(context),
        borderRadius: BorderRadius.circular(22),
        child: _QuickActionButton(
          label: label,
          icon: icon,
          color: color,
          onTap: () => _showAnnouncementDialog(context),
        ),
      );
    }

    // Original OpenContainer for other routes
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
        switch (route) {
          case "/trainer/classes":
            return const MyClassesPage();
          case "/trainer/classes/create":
            return const CreateClassForm();
          case "/trainer/content/upload":
            return const QuickUploadMaterialPage();
          case "/create-assessment":
            return const CreateAssessmentPage(
              classId: null,
              initialClassId: null,
            );
          case "/trainer/reports":
            return const TrainerReportsPage();
          // ✅ ADD THIS NEW CASE BELOW
          case "/trainer/authorize":
            return const CertificateAuthorizationPage();
          default:
            return const SizedBox.shrink();
        }
      },
      tappable: true,
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  void _showAnnouncementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
          ), // Add this line
          child: Container(
            // Remove the constraints line completely
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.1),
                          Colors.deepOrange.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.bullhorn,
                      color: Colors.orange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Announcements',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose an action',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Create Announcement Button
                  _buildDialogButton(
                    context: context,
                    label: 'Create Announcement',
                    icon: FontAwesomeIcons.plus,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateAnnouncementPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Manage Announcements Button
                  _buildDialogButton(
                    context: context,
                    label: 'Manage Announcements',
                    icon: FontAwesomeIcons.listCheck,
                    color: Colors.deepOrange,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnnouncementsListPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
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

  Widget _buildDialogButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Changed from max to min
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Flexible(
                  // Wrapped Text with Flexible
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis, // Added overflow handling
                    maxLines: 1, // Limit to 1 line
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recentClassCard(BuildContext context, Map<String, dynamic> cls) {
    final className = cls['className'] ?? 'Untitled Class';
    final classCode = cls['classCode'] ?? 'N/A';
    final studentCount = cls['studentCount'] ?? 0;
    final date = (cls['createdAt'] as Timestamp?)?.toDate();
    final classId = cls['id'] as String?;

    if (classId == null) {
      return const Card(
        child: ListTile(title: Text("Error: Class ID missing")),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
            Colors.indigo.shade50,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 6,
            offset: const Offset(-2, -2),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.blue.shade50.withOpacity(0.8),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.purple.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        FontAwesomeIcons.graduationCap,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            className,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FontAwesomeIcons.users,
                                  size: 10,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "$studentCount Student${studentCount == 1 ? '' : 's'}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FontAwesomeIcons.calendar,
                            size: 10,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Created: ${date?.toLocal().toString().split(' ')[0] ?? 'N/A'}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.cyan.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FontAwesomeIcons.hashtag,
                            size: 10,
                            color: Colors.cyan.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Code: $classCode",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.cyan.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Quick Actions",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernActionButton(
                              icon: FontAwesomeIcons.fileLines,
                              label: "Content",
                              color: Colors.teal,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ManageClassContentPage(
                                          classId: classId,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildModernActionButton(
                              icon: FontAwesomeIcons.usersCog,
                              label: "Students",
                              color: Colors.orange,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/trainer/classes/$classId/students',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: _buildModernActionButton(
                          icon: FontAwesomeIcons.listCheck,
                          label: "Assessments",
                          color: Colors.indigo,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/class/$classId/assessments',
                            arguments: classId,
                          ),
                          isFullWidth: true,
                        ),
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

  Widget _buildModernActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
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

class _AnimatedQuickActionState extends State<AnimatedQuickAction>
    with SingleTickerProviderStateMixin {
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
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _elevationAnim = Tween<double>(
      begin: 10,
      end: 26,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
                borderRadius: BorderRadius.circular(
                  _pressed ? kCardRadius + 8 : kCardRadius,
                ),
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
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
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
                              child: Icon(
                                widget.icon,
                                color: widget.color,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
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
          border: Border.all(color: color.withOpacity(0.18), width: 1.2),
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
