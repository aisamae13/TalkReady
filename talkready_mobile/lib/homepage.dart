import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'ai_bot.dart';
import 'profile.dart';
import 'package:logger/logger.dart';
import 'courses_page.dart';
import 'journal/journal_page.dart';
import 'package:talkready_mobile/all_notifications_page.dart';
import 'progress_page.dart';
import 'package:talkready_mobile/custom_animated_bottom_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:talkready_mobile/MyEnrolledClasses.dart';

// Helper function for creating a slide page route
Route _createSlidingPageRoute({
  required Widget page,
  required int newIndex,
  required int oldIndex,
  required Duration duration,
}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = oldIndex < newIndex ? Offset(1.0, 0.0) : Offset(-1.0, 0.0);
      return SlideTransition(
        position: Tween<Offset>(begin: offset, end: Offset.zero).animate(animation),
        child: child,
      );
    },
    transitionDuration: duration,
    reverseTransitionDuration: duration,
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0; // Home is index 0
  String? selectedSkill;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  
  // User stats
  Duration _totalSpeakingTime = Duration.zero;
  int _currentStreak = 0;
  
  // Skill tracking
  final Map<String, double> skillPercentages = {
    'Fluency': 0.0,
    'Grammar': 0.0,
    'Pronunciation': 0.0,
    'Vocabulary': 0.0,
    'Interaction': 0.0,
  };
  
  // Featured courses
  final List<Map<String, dynamic>> _featuredCourses = [];
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<String, String> skillDescriptions = {
    'Grammar': 'Your Grammar score is derived from your performance in lessons focusing on written accuracy and structure. This includes your scores from text-based scenario exercises (e.g., in Modules 2, 3, and 4, such as L2.1, L2.2, L2.3, L3.1, L4.1, L4.2) where AI evaluates your responses. It reflects your ability to form correct sentences and use appropriate language.',
    'Fluency': 'Your Fluency score is calculated from your performance in dedicated speaking practice lessons (e.g., Lessons L3.2, L5.1, L5.2). Our AI analyzes aspects like the smoothness, naturalness, and flow of your speech, including how well you connect words without undue hesitation.',
    'Interaction': 'Your Interaction score is based on your performance in speaking lessons that involve dialogues or call simulations (e.g., Lessons L3.2, L5.1, L5.2). It primarily reflects how effectively you complete conversational turns and cover the required information, based on the AI\'s analysis of speech completeness.',
    'Pronunciation': 'Your Pronunciation score is assessed during speaking exercises (e.g., Lessons L3.2, L5.1, L5.2). The AI evaluates the clarity of your speech, accuracy of sounds, rhythm, and intonation (prosody) to determine how well you are likely to be understood.',
    'Vocabulary': 'Your Vocabulary score reflects your understanding and use of a range of words appropriate for different contexts. It\'s based on your performance in text-based AI-evaluated exercises (e.g., in Modules 2, 3, and 4, such as L2.1, L2.2, L2.3, L3.1, L4.1, L4.2) where AI assesses how effectively you use vocabulary in context.'
  };

  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeData();
    _setupRealTimeListener();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.bounceOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _fetchProgress(),
        _calculateUserStats(),
        _loadFeaturedCourses(),
      ]);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e, stackTrace) {
      logger.e('Error initializing homepage data: $e, stackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load data. Please try again.';
        });
      }
    }
  }

  Future<void> _fetchProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e('No user logged in');
      return;
    }
    
    try {
      logger.i('Fetching progress for user: ${user.uid}');
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;
      if (userData != null && userData.containsKey('progress')) {
        Map<String, dynamic> progress = userData['progress'];
        
        // Calculate skill scores using similar logic to React component
        final skillScores = _calculateSkillScores(userData);
        
        if (mounted) {
          setState(() {
            skillPercentages['Fluency'] = skillScores[1];
            skillPercentages['Grammar'] = skillScores[0];
            skillPercentages['Pronunciation'] = skillScores[3];
            skillPercentages['Vocabulary'] = skillScores[4];
            skillPercentages['Interaction'] = skillScores[2];
          });
        }
        
        logger.i('Fetched progress: $skillPercentages');
      } else {
        logger.i('No progress data found for user: ${user.uid}, using defaults');
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching progress: $e, stackTrace: $stackTrace');
      rethrow;
    }
  }

  List<double> _calculateSkillScores(Map<String, dynamic> userData) {
    final lessonAttempts = userData['lessonAttempts'] as Map<String, dynamic>? ?? {};
    
    if (lessonAttempts.isEmpty) {
      return [20, 20, 20, 20, 20]; // Default for new users
    }

    List<double> grammarScores = [], fluencyScores = [], interactionScores = [], 
                 pronunciationScores = [], vocabularyScores = [];

    final speakingLessonIds = ["Lesson-3-2", "Lesson-5-1", "Lesson-5-2"];
    final textAiLessonIds = ["Lesson-2-1", "Lesson-2-2", "Lesson-2-3", "Lesson-3-1", "Lesson-4-1", "Lesson-4-2"];

    for (final lessonId in lessonAttempts.keys) {
      final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];
      if (attempts.isEmpty) continue;
      
      final latestAttempt = attempts.last as Map<String, dynamic>?;
      if (latestAttempt == null || latestAttempt['detailedResponses'] == null) continue;

      final detailedResponses = latestAttempt['detailedResponses'] as Map<String, dynamic>;

      // Speaking Skills (from Azure Metrics)
      if (speakingLessonIds.contains(lessonId)) {
        final details = detailedResponses['turnDetails'] ?? detailedResponses['promptDetails'] ?? [];
        for (final detail in details) {
          if (detail is Map<String, dynamic>) {
            final character = detail['character'] as String? ?? '';
            final isAgentTurn = character.contains('Agent') || character.contains('Your Turn');
            
            if (isAgentTurn && detail['azureAiFeedback'] != null) {
              final fb = detail['azureAiFeedback'] as Map<String, dynamic>;
              if (fb['fluencyScore'] != null) fluencyScores.add(fb['fluencyScore'].toDouble());
              if (fb['completenessScore'] != null) interactionScores.add(fb['completenessScore'].toDouble());
              if (fb['prosodyScore'] != null) pronunciationScores.add(fb['prosodyScore'].toDouble());
            }
          }
        }
      }

      // Grammar & Vocabulary (from Text-based AI Scores)
      if (textAiLessonIds.contains(lessonId)) {
        final feedbackKey = detailedResponses.keys
            .where((k) => k.toLowerCase().contains('feedback'))
            .firstOrNull;
        
        if (feedbackKey != null) {
          final allPromptFeedback = detailedResponses[feedbackKey] as Map<String, dynamic>? ?? {};
          for (final feedbackDetail in allPromptFeedback.values) {
            if (feedbackDetail is Map<String, dynamic> && feedbackDetail['score'] is num) {
              // Normalize score from 1-5 to 0-100
              final normalizedScore = ((feedbackDetail['score'] as num) / 5) * 100;
              grammarScores.add(normalizedScore.toDouble());
              vocabularyScores.add(normalizedScore.toDouble());
            }
          }
        }
      }
    }

    double calculateAverage(List<double> scores) => 
        scores.isEmpty ? 20 : scores.reduce((a, b) => a + b) / scores.length;

    return [
      calculateAverage(grammarScores),
      calculateAverage(fluencyScores),
      calculateAverage(interactionScores),
      calculateAverage(pronunciationScores),
      calculateAverage(vocabularyScores),
    ];
  }

  Future<void> _calculateUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;
      if (userData == null) return;

      // Calculate speaking time and streak
      _calculateSpeakingTime(userData);
      _calculateStreak(userData);
      
    } catch (e) {
      logger.e('Error calculating user stats: $e');
    }
  }

  void _calculateSpeakingTime(Map<String, dynamic> userData) {
    // Implementation similar to React component
    int totalSeconds = 0;
    
    final lessonAttempts = userData['lessonAttempts'] as Map<String, dynamic>? ?? {};
    for (final attempts in lessonAttempts.values) {
      if (attempts is List) {
        for (final attempt in attempts) {
          if (attempt is Map<String, dynamic> && attempt['timeSpent'] is num) {
            totalSeconds += (attempt['timeSpent'] as num).toInt();
          }
        }
      }
    }
    
    _totalSpeakingTime = Duration(seconds: totalSeconds);
  }

  void _calculateStreak(Map<String, dynamic> userData) {
    final Set<String> activityDates = {};
    final lessonAttempts = userData['lessonAttempts'] as Map<String, dynamic>? ?? {};
    
    for (final attempts in lessonAttempts.values) {
      if (attempts is List) {
        for (final attempt in attempts) {
          if (attempt is Map<String, dynamic> && attempt['attemptTimestamp'] != null) {
            DateTime dateObj;
            final timestamp = attempt['attemptTimestamp'];
            
            if (timestamp is Timestamp) {
              dateObj = timestamp.toDate();
            } else {
              dateObj = DateTime.parse(timestamp.toString());
            }
            
            final dateString = '${dateObj.year}-${dateObj.month.toString().padLeft(2, '0')}-${dateObj.day.toString().padLeft(2, '0')}';
            activityDates.add(dateString);
          }
        }
      }
    }

    if (activityDates.isEmpty) {
      _currentStreak = 0;
      return;
    }

    final sortedDates = activityDates.toList()..sort();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final lastActivityStr = sortedDates.last;

    if (lastActivityStr == todayStr || lastActivityStr == yesterdayStr) {
      _currentStreak = 1;
      DateTime currentDate = DateTime.parse(lastActivityStr);
      
      for (int i = sortedDates.length - 2; i >= 0; i--) {
        final expectedPrevious = currentDate.subtract(const Duration(days: 1));
        final expectedStr = '${expectedPrevious.year}-${expectedPrevious.month.toString().padLeft(2, '0')}-${expectedPrevious.day.toString().padLeft(2, '0')}';
        
        if (sortedDates[i] == expectedStr) {
          _currentStreak++;
          currentDate = expectedPrevious;
        } else {
          break;
        }
      }
    } else {
      _currentStreak = 0;
    }
  }

  Future<void> _loadFeaturedCourses() async {
    // Implementation for featured courses logic
    final staticCourses = [
      {
        'id': 'cultural_fit',
        'title': 'Cultural Fit for Working in the U.S.',
        'description': 'Powered by English for IT.',
        'icon': Icons.business,
        'color': const Color(0xFF00568D),
        'route': '/courses',
        'reason': 'Popular Course',
      },
      {
        'id': 'tv_shows',
        'title': 'Speak Like a Native with TV Shows',
        'description': 'Master conversational English.',
        'icon': Icons.tv,
        'color': Colors.purple,
        'route': '/courses',
        'reason': 'Engaging Content',
      },
      {
        'id': 'interview_sim',
        'title': 'Job Interview Simulator',
        'description': 'Prepare for job interviews.',
        'icon': Icons.work,
        'color': Colors.green,
        'route': '/courses',
        'reason': 'Career Focused',
      },
      {
        'id': 'small_talk',
        'title': 'How to Make Great Small Talk',
        'description': 'Improve your social English.',
        'icon': Icons.chat,
        'color': Colors.orange,
        'route': '/courses',
        'reason': 'Practical Skills',
      },
    ];
    
    _featuredCourses.clear();
    _featuredCourses.addAll(staticCourses);
  }

  double get overallPercentage {
    if (skillPercentages.isEmpty) return 0.0;
    return skillPercentages.values.reduce((a, b) => a + b) / skillPercentages.length;
  }

  void _handleSkillSelected(String skill) {
    HapticFeedback.lightImpact();
    setState(() {
      selectedSkill = selectedSkill == skill ? null : skill;
    });
  }

  String _formatSpeakingTime() {
    if (_totalSpeakingTime.inSeconds == 0) return "0 min";
    
    final hours = _totalSpeakingTime.inHours;
    final minutes = _totalSpeakingTime.inMinutes % 60;
    
    String result = "";
    if (hours > 0) result += "${hours}h ";
    if (minutes > 0 || hours == 0) result += "${minutes}m";
    
    return result.trim().isEmpty ? "0 min" : result.trim();
  }

  void _onItemTapped(int index) {
    logger.d('Tapped navigation item. Index: $index, currentIndex: $_selectedIndex');
    if (_selectedIndex == index) return;

    final int oldNavIndex = _selectedIndex;

    setState(() {
      _selectedIndex = index;
    });

    Widget nextPage;
    switch (index) {
      case 0:
        return; // Already on HomePage
      case 1:
        nextPage = const CoursesPage();
        break;
      case 2:
        nextPage = const MyEnrolledClasses();
        break;
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

    Navigator.push(
      context,
      _createSlidingPageRoute(
        page: nextPage,
        newIndex: index,
        oldIndex: oldNavIndex,
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Add stream subscription
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  // Add real-time listener
  void _setupRealTimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final userData = snapshot.data() as Map<String, dynamic>?;
        if (userData != null) {
          _updateSkillProgressFromData(userData);
          _calculateUserStats(); // Update stats too
        }
      }
    }, onError: (error) {
      logger.e('Error listening to user data: $error');
    });
  }

  // Update skills immediately when data changes
  void _updateSkillProgressFromData(Map<String, dynamic> userData) {
    final skillScores = _calculateSkillScores(userData);
    
    setState(() {
      skillPercentages['Fluency'] = skillScores[1];
      skillPercentages['Grammar'] = skillScores[0];
      skillPercentages['Pronunciation'] = skillScores[3];
      skillPercentages['Vocabulary'] = skillScores[4];
      skillPercentages['Interaction'] = skillScores[2];
    });
    
    logger.i('Real-time skill update: $skillPercentages');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _userDataSubscription?.cancel();
    super.dispose();
  }

  // Add this method to build the app bar with logo
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
            'TalkReady',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AllNotificationsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'User';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      // Remove the appBar property
      body: Column(
        children: [
          _buildAppBarWithLogo(), // Add the custom header
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                    ? _buildErrorState()
                    : _buildMainContent(firstName),
          ),
        ],
      ),
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 16),
          const Text('Loading your learning progress...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Something went wrong'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              _initializeData();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(String firstName) {
    return RefreshIndicator(
      onRefresh: () async {
        await _initializeData();
      },
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(overscroll: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Welcome Section
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildWelcomeSection(firstName),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Skill Progress Section
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildSkillProgressSection(),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // User Stats Section
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildUserStatsSection(),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Main Content Grid
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildMainContentGrid(),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Quick Navigation
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildQuickNavigation(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(String firstName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00568D).withOpacity(0.1),
            const Color(0xFF00A6CB).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Welcome $firstName to TalkReady',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your AI-powered platform for mastering English communication in real-world customer service scenarios.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSkillProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Skill Progress Tracker',
            style: TextStyle(
              fontSize: 24,
              color: Color(0xFF00568D),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // Pentagon Graph
          Stack(
            alignment: Alignment.center,
            children: [
              PentagonGraph(
                size: 200,
                progress: overallPercentage / 100,
                selectedSkill: selectedSkill,
              ),
              Text(
                '${((selectedSkill != null ? skillPercentages[selectedSkill]! : overallPercentage)).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Skill Buttons
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: skillPercentages.keys.map((skill) {
              final Map<String, Color> skillColors = {
                "Grammar": const Color(0xFFD8F6F7),
                "Fluency": const Color(0xFFDEE3FF),
                "Interaction": const Color(0xFFFFD6D6),
                "Pronunciation": const Color(0xFFFFF0C3),
                "Vocabulary": const Color(0xFFE0FFD6),
              };
              bool isSelected = selectedSkill == skill;
              return InkWell(
                onTap: () => _handleSkillSelected(skill),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? skillColors[skill]?.withOpacity(0.7)
                        : skillColors[skill] ?? Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected 
                        ? Border.all(color: const Color(0xFF00568D), width: 2)
                        : null,
                  ),
                  child: Text(
                    skill,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00568D) : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Skill Description
          if (selectedSkill != null) ...[
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(selectedSkill),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  skillDescriptions[selectedSkill] ?? 'No description available.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          
          if (selectedSkill == null && skillPercentages.values.every((value) => value == 0.0)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                'Complete speaking exercises in the courses to see your skill progress here!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(
            icon: Icons.access_time,
            title: 'Speaking Time',
            value: _formatSpeakingTime(),
            color: Colors.blue,
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.grey[300],
          ),
          _buildStatCard(
            icon: Icons.local_fire_department,
            title: 'Current Streak',
            value: '$_currentStreak ${_currentStreak == 1 ? "day" : "days"}',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContentGrid() {
    return Column(
      children: [
        // AI Chatbot Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00568D), Color(0xFF0077B3)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00568D).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TalkReady AI Chatbot',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Practice and refine your English through AI-powered conversations.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Engage with our TalkReady Bot in interactive dialogues and role-play scenarios. Receive instant, personalized feedback on your pronunciation, fluency, grammar, and vocabulary.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AIBotScreen(
                        onBackPressed: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.mic, size: 20),
                label: const Text('Start Practice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF00568D),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Featured Courses Section
        _buildFeaturedCoursesSection(),
      ],
    );
  }

  Widget _buildFeaturedCoursesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Featured For You',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _featuredCourses.length,
              itemBuilder: (context, index) {
                final course = _featuredCourses[index];
                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: (course['color'] as Color).withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            course['icon'] as IconData,
                            size: 36,
                            color: course['color'] as Color,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course['reason'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                course['title'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004C70),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  course['description'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const CoursesPage(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00568D),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Go to Course',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavigation() {
    final quickNavItems = [
      {'icon': Icons.school, 'label': 'Courses', 'route': const CoursesPage()},
      {'icon': Icons.class_, 'label': 'My Classes', 'route': const MyEnrolledClasses()},
      {'icon': Icons.book, 'label': 'Journal', 'route': JournalPage()}, // Move Journal here
      {'icon': Icons.bar_chart, 'label': 'My Reports', 'route': const ProgressTrackerPage()},
      {'icon': Icons.mic, 'label': 'Practice Test', 'route': AIBotScreen(onBackPressed: () => Navigator.pop(context))},
      {'icon': Icons.person, 'label': 'Profile', 'route': const ProfilePage()},
      {'icon': Icons.help, 'label': 'Help & FAQ', 'route': const CoursesPage()},
      {'icon': Icons.contact_support, 'label': 'Contact Us', 'route': const CoursesPage()},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'Quick Navigation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0077B3),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: quickNavItems.length,
            itemBuilder: (context, index) {
              final item = quickNavItems[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => item['route'] as Widget,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 28,
                        color: const Color(0xFF0077B3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0077B3),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Keep your existing PentagonGraph and PentagonPainter classes unchanged
class PentagonGraph extends StatelessWidget {
  final double size;
  final double progress;
  final String? selectedSkill;

  static const Map<String, Color> skillColors = {
    "Grammar": Color(0xFFD8F6F7),
    "Fluency": Color(0xFFDEE3FF),
    "Interaction": Color(0xFFFFD6D6),
    "Pronunciation": Color(0xFFFFF0C3),
    "Vocabulary": Color(0xFFE0FFD6),
  };

  const PentagonGraph({
    super.key,
    this.size = 200,
    required this.progress,
    this.selectedSkill,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: PentagonPainter(
        progress: progress,
        selectedSkill: selectedSkill,
        skillColor: selectedSkill != null ? skillColors[selectedSkill] : null,
      ),
    );
  }
}

class PentagonPainter extends CustomPainter {
  final double progress;
  final String? selectedSkill;
  final Color? skillColor;
  final Animation<double>? progressAnimation; // Add this
  static const greyColor = Color(0xFF6B7280);

  PentagonPainter({
    required this.progress,
    this.selectedSkill,
    this.skillColor,
    this.progressAnimation, // Add this
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Use animated progress if available
    final animatedProgress = progressAnimation?.value ?? progress;

    final basePaint = Paint()
      ..color = greyColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 5; i > 0; i--) {
      _drawPentagon(canvas, center, radius * (i / 5), basePaint);
    }

    final progressPaint = Paint()..style = PaintingStyle.fill;

    if (skillColor != null) {
      progressPaint.shader = LinearGradient(
        colors: [
          skillColor!.withOpacity(0.4),
          skillColor!,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      progressPaint.shader = LinearGradient(
        colors: [
          greyColor.withOpacity(0.4),
          greyColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    final progressPath = Path();
    _createPentagonPath(progressPath, center, radius * animatedProgress);
    canvas.drawPath(progressPath, progressPaint);

    final outlinePaint = Paint()
      ..color = skillColor ?? greyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    _drawPentagon(canvas, center, radius, outlinePaint);
  }

  void _drawPentagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    _createPentagonPath(path, center, radius);
    canvas.drawPath(path, paint);
  }

  void _createPentagonPath(Path path, Offset center, double radius) {
    for (int i = 0; i < 5; i++) {
      final angle = 2 * math.pi / 5 * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }

  @override
  bool shouldRepaint(covariant PentagonPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.selectedSkill != selectedSkill ||
      oldDelegate.skillColor != skillColor;
}