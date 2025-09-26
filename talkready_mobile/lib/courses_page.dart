// lib/pages/courses_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/unified_progress_service.dart';
import '../custom_animated_bottom_bar.dart';
import '../services/certificate_service.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final TextEditingController _searchController = TextEditingController();

  // This will hold all progress data, including lesson attempts and pre-assessments
  Map<String, dynamic> _userProgress = {};
  bool _isLoading = true;
  bool _showCertificateBanner = false;
  final CertificateService _certificateService = CertificateService();
  int _selectedIndex = 1; // Courses tab is index 1
  String _searchQuery = '';

  // This structure should ideally come from a shared configuration file
  final List<Map<String, dynamic>> _moduleConfigs = [
    {
      'id': 'module1',
      'title': 'Module 1: Basic English Grammar',
      'description': 'Build a solid foundation in English grammar...',
      'color': const Color(0xFFFF6347),
      'icon': Icons.book,
      'level': 'Beginner',
      'route': '/module1',
      'lessons': ['Lesson-1-1', 'Lesson-1-2', 'Lesson-1-3'],
      'assessmentId': 'module_1_final',
    },
    {
      'id': 'module2',
      'title': 'Module 2: Vocabulary & Everyday Conversations',
      'description':
          'Learn essential vocabulary and phrases for common interactions like greetings and asking for information.',
      'color': const Color(0xFFFF9900),
      'icon': Icons.chat_bubble,
      'level': 'Beginner',
      'route': '/module2',
      'lessons': ['Lesson-2-1', 'Lesson-2-2', 'Lesson-2-3'],
      'assessmentId': 'module_2_final',
      'prerequisite': 'module1',
    },
    {
      'id': 'module3',
      'title': 'Module 3: Listening & Speaking Practice',
      'description':
          'Develop crucial listening comprehension by identifying key information in customer calls and improve speaking clarity through practice.',
      'color': const Color(0xFF32CD32),
      'icon': Icons.headphones,
      'level': 'Intermediate',
      'route': '/module3',
      'lessons': ['Lesson-3-1', 'Lesson-3-2'],
      'assessmentId': 'module_3_final',
      'prerequisite': 'module2',
    },
    {
      'id': 'module4',
      'title': 'Module 4: Advanced Customer Service',
      'description':
          'Master complex customer scenarios and professional communication techniques for challenging business situations.',
      'color': const Color(0xFF9C27B0),
      'icon': Icons.business_center,
      'level': 'Intermediate',
      'route': '/module4',
      'lessons': ['Lesson-4-1', 'Lesson-4-2'],
      'assessmentId': 'module_4_final',
      'prerequisite': 'module3',
    },
    {
      'id': 'module5',
      'title': 'Module 5: Professional Communication',
      'description':
          'Perfect your professional communication skills with advanced techniques and real-world business scenarios.',
      'color': const Color(0xFF00BCD4),
      'icon': Icons.stars,
      'level': 'Intermediate',
      'route': '/module5',
      'lessons': ['Lesson-5-1', 'Lesson-5-2'],
      'assessmentId': 'module_5_final',
      'prerequisite': 'module4',
    },
    {
      'id': 'module6',
      'title': 'Module 6: Advanced Call Simulation',
      'description':
          'Master real-world call center skills through live AI conversations and receive comprehensive performance analysis.',
      'color': const Color(0xFF7C3AED), // Purple color for advanced level
      'icon': Icons.headset_mic,
      'level': 'Advanced', // Add this new level
      'route': '/module6',
      'lessons': ['Lesson-6-1'], // Only one lesson in Module 6
      'assessmentId': 'module_6_final',
      'prerequisite': 'module5',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    try {
      final progress = await _progressService.getUserProgress();

      // Check if user can claim certificate
      final userId = _progressService.userId;
      if (userId != null) {
        final canClaim = await _certificateService.hasCompletedAllModules(
          userId,
        );
        _logger.i('Certificate eligibility: $canClaim');

        setState(() {
          _showCertificateBanner = canClaim;
        });
      }

      if (mounted) {
        setState(() {
          _userProgress = progress;
          _isLoading = false;
        });
      }
      _logger.i('Loaded user progress successfully on courses page.');
    } catch (e) {
      _logger.e('Error loading progress on courses page: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _testCertificateBanner() {
    setState(() {
      _showCertificateBanner = true;
    });
  }

  // Add this method to build the certificate banner
  Widget _buildCertificateBanner() {
    if (!_showCertificateBanner) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 32,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Congratulations! 🎉',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You\'ve completed all modules in the TalkReady course!',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/certificate');
              },
              icon: const Icon(Icons.card_membership),
              label: const Text('Claim Your Certificate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to determine if a module is unlocked
    bool _isModuleUnlocked(String moduleId) {
      if (moduleId == 'module1') return true;

      int moduleNum = int.tryParse(moduleId.replaceAll('module', '')) ?? 0;
      if (moduleNum <= 1) return true;

      String prevModuleId = 'module${moduleNum - 1}';
      final prevModuleConfig = _moduleConfigs.firstWhere(
         (m) => m['id'] == prevModuleId,
         orElse: () => {},
      );

      if (prevModuleConfig.isEmpty) return false;

    // FIX HERE: Use safe casting for nested maps
      final lessonAttempts = (_userProgress['lessonAttempts'] as Map?)
        ?.cast<String, dynamic>() ?? {};
    // FIX HERE: Use safe casting for nested maps
      final assessmentAttempts = (_userProgress['moduleAssessmentAttempts'] as Map?)
        ?.cast<String, dynamic>() ?? {};

      final prevLessons = prevModuleConfig['lessons'] as List<String>? ?? [];
      final allPrevLessonsDone = prevLessons.every(
         (lessonId) => (lessonAttempts[lessonId] as List?)?.isNotEmpty ?? false,
      );

      final prevAssessmentId = prevModuleConfig['assessmentId'] as String?;
      final prevAssessmentDone =
            prevAssessmentId == null ||
            (assessmentAttempts[prevAssessmentId] as List?)?.isNotEmpty == true;

      return allPrevLessonsDone && prevAssessmentDone;
   }

  // Filter modules based on search query
  List<Map<String, dynamic>> _getFilteredModules() {
    if (_searchQuery.isEmpty) return _moduleConfigs;

    return _moduleConfigs.where((module) {
      final title = (module['title'] as String).toLowerCase();
      final description = (module['description'] as String).toLowerCase();
      final level = (module['level'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();

      return title.contains(query) ||
          description.contains(query) ||
          level.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProgress,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildSearchSection(),
                        // ADD THIS LINE:
                        _buildCertificateBanner(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _buildLevelSection('Beginner'),
                      _buildLevelSection('Intermediate'),
                      _buildLevelSection('Advanced'),
                      const SizedBox(height: 100), // Bottom padding for nav bar
                    ]),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search courses...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400]),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelSection(String level) {
    final filteredModules = _getFilteredModules();
    final modulesForLevel = filteredModules
        .where((m) => m['level'] == level)
        .toList();

    if (modulesForLevel.isEmpty) return const SizedBox.shrink();

    // Add color for Advanced level
    Color levelColor = const Color(0xFF0077B3); // Default blue
    if (level == 'Advanced') {
      levelColor = const Color(0xFF7C3AED); // Purple for advanced
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.1), // Use dynamic color
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: levelColor.withOpacity(0.3), // Use dynamic color
              ),
            ),
            child: Text(
              level,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: levelColor, // Use dynamic color
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...modulesForLevel.map((config) => _buildModuleCard(config)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> moduleConfig) {
    final moduleId = moduleConfig['id'] as String;
    final lessonIds = moduleConfig['lessons'] as List<String>;
    final lessonAttempts = (_userProgress['lessonAttempts'] as Map?)
    ?.cast<String, dynamic>() ?? {};

    final completedLessons = lessonIds
        .where((id) => (lessonAttempts[id] as List?)?.isNotEmpty ?? false)
        .length;
    final totalLessons = lessonIds.length;
    final isUnlocked = _isModuleUnlocked(moduleId);
    final progressPercentage = totalLessons > 0
        ? completedLessons / totalLessons
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUnlocked
              ? () => Navigator.pushNamed(context, moduleConfig['route'])
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: isUnlocked ? 1.0 : 0.6,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (moduleConfig['color'] as Color).withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          moduleConfig['icon'],
                          color: moduleConfig['color'],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    moduleConfig['title'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: moduleConfig['color'],
                                    ),
                                  ),
                                ),
                                if (!isUnlocked)
                                  Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              moduleConfig['description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '$completedLessons / $totalLessons lessons',
                                  style: TextStyle(
                                    color: moduleConfig['color'],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progressPercentage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: moduleConfig['color'],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (moduleConfig['color'] as Color).withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(progressPercentage * 100).round()}%',
                          style: TextStyle(
                            color: moduleConfig['color'],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Remove the star button from your AppBar and go back to the original:
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF0077B3),
      pinned: true,
      expandedHeight: 120.0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Image.asset(
                    'images/TR Logo.png',
                    height: 32,
                    width: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Courses',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return AnimatedBottomNavBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (_selectedIndex == index) return;
        setState(() => _selectedIndex = index);
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/homepage');
            break;
          case 1:
            break; // Already here
          case 2:
            Navigator.pushReplacementNamed(context, '/enrolled-classes');
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/journal');
            break;
          case 4:
            Navigator.pushReplacementNamed(context, '/progress');
            break;
          case 5:
            Navigator.pushReplacementNamed(context, '/profile');
            break;
        }
      },
      items: [
        CustomBottomNavItem(icon: Icons.home, label: 'Home'),
        CustomBottomNavItem(icon: Icons.book, label: 'Courses'),
        CustomBottomNavItem(icon: Icons.school, label: 'My Classes'),
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
    );
  }
}
