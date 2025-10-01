//home

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../services/daily_content_service.dart';
import 'firebase_service.dart'; // Add this import

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
        position: Tween<Offset>(
          begin: offset,
          end: Offset.zero,
        ).animate(animation),
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
  int _selectedIndex = 0;
  String? selectedSkill;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // Enhanced user stats
  Duration _totalSpeakingTime = Duration.zero;
  int _currentStreak = 0;
  int _lessonsCompleted = 0;
  double _averageScore = 0.0;

  // Enhanced skill tracking with detailed analysis
  final Map<String, Map<String, dynamic>> skillAnalysis = {
    'Foundation Grammar': {
      'score': 0.0,
      'trend': 0.0,
      'level': 'Beginner',
      'attempts': 0,
      'lastScore': 0.0,
    },
    'Conversational Skills': {
      'score': 0.0,
      'trend': 0.0,
      'level': 'Beginner',
      'attempts': 0,
      'lastScore': 0.0,
    },
    'Listening Comprehension': {
      'score': 0.0,
      'trend': 0.0,
      'level': 'Beginner',
      'attempts': 0,
      'lastScore': 0.0,
    },
    'Speaking Fluency': {
      'score': 0.0,
      'trend': 0.0,
      'level': 'Beginner',
      'attempts': 0,
      'lastScore': 0.0,
    },
    'Professional Communication': {
      'score': 0.0,
      'trend': 0.0,
      'level': 'Beginner',
      'attempts': 0,
      'lastScore': 0.0,
    },
    'Call Center Readiness': {
      'score': 0.0,
      'trend': 0.0,
      'level': 'Beginner',
      'attempts': 0,
      'lastScore': 0.0,
    },
  };

  // Progress analytics view state
  String _activeView = 'overview'; // 'overview', 'modules', 'trends'

  // Module progress data
  Map<String, Map<String, dynamic>> moduleProgress = {};

  // Learning tips and motivation
  Map<String, dynamic>? dailyTip;
  Map<String, dynamic>? dailyMotivation;
  bool tipLoading = false;

  // Featured courses
  final List<Map<String, dynamic>> _featuredCourses = [];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<String, String> skillDescriptions = {
    'Foundation Grammar':
        'Your Foundation Grammar score reflects your understanding of basic English structure and rules. This includes performance in grammar-focused lessons and written exercises.',
    'Conversational Skills':
        'Your Conversational Skills score measures your ability to engage in meaningful dialogue and respond appropriately in various social and professional contexts.',
    'Listening Comprehension':
        'Your Listening Comprehension score evaluates how well you understand spoken English in different scenarios and contexts.',
    'Speaking Fluency':
        'Your Speaking Fluency score is calculated from speaking exercises, analyzing smoothness, naturalness, and flow of your speech using AI assessment.',
    'Professional Communication':
        'Your Professional Communication score reflects your ability to communicate effectively in workplace scenarios and formal business contexts.',
    'Call Center Readiness':
        'Your Call Center Readiness score measures your preparedness for customer service roles through call simulation exercises and performance assessments.',
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
        _fetchEnhancedProgress(),
        _calculateEnhancedUserStats(),
        _loadFeaturedCourses(),
        _fetchDailyContent(),
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

  Future<void> _fetchEnhancedProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e('No user logged in');
      return;
    }

    try {
      logger.i('Fetching enhanced progress for user: ${user.uid}');
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final userData = doc.data() as Map<String, dynamic>;
        final lessonAttempts =
            userData['lessonAttempts'] as Map<String, dynamic>? ?? {};

        // Calculate enhanced skill analysis
        _calculateEnhancedSkillAnalysis(lessonAttempts);
        _calculateModuleProgress(userData);

        logger.i('Enhanced skill analysis calculated: $skillAnalysis');
      } else {
        logger.i(
          'No progress data found for user: ${user.uid}, using defaults',
        );
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching enhanced progress: $e, stackTrace: $stackTrace');
      rethrow;
    }
  }

  void _calculateEnhancedSkillAnalysis(Map<String, dynamic> lessonAttempts) {
    final skillCategories = {
      'Foundation Grammar': {
        'lessons': ['Lesson-1-1', 'Lesson-1-2', 'Lesson-1-3'],
        'weight': 1.0,
      },
      'Conversational Skills': {
        'lessons': ['Lesson-2-1', 'Lesson-2-2', 'Lesson-2-3'],
        'weight': 1.2,
      },
      'Listening Comprehension': {
        'lessons': ['Lesson-3-1'],
        'weight': 1.3,
      },
      'Speaking Fluency': {
        'lessons': ['Lesson-3-2', 'Lesson-5-1', 'Lesson-5-2'],
        'weight': 1.4,
      },
      'Professional Communication': {
        'lessons': ['Lesson-4-1', 'Lesson-4-2'],
        'weight': 1.3,
      },
      'Call Center Readiness': {
        'lessons': ['Lesson-5-1', 'Lesson-5-2', 'Lesson-6-1'],
        'weight': 1.5,
      },
    };

    skillCategories.forEach((skillName, config) {
      final lessons = config['lessons'] as List<String>;
      List<Map<String, dynamic>> allScores = [];
      int totalAttempts = 0;

      for (String lessonId in lessons) {
        final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];
        totalAttempts += attempts.length;

        for (var attempt in attempts) {
          if (attempt is Map<String, dynamic>) {
            double score = _extractScoreForSkill(attempt, skillName);
            if (score > 0) {
              allScores.add({
                'score': math.min(100.0, score),
                'timestamp': attempt['attemptTimestamp'],
              });
            }
          }
        }
      }

      // Sort by timestamp for trend analysis
      allScores.sort((a, b) {
        DateTime aTime = _parseTimestamp(a['timestamp']);
        DateTime bTime = _parseTimestamp(b['timestamp']);
        return aTime.compareTo(bTime);
      });

      double averageScore = 0.0;
      double trend = 0.0;
      String level = 'Beginner';
      double lastScore = 0.0;

      if (allScores.isNotEmpty) {
        averageScore =
            allScores
                .map((item) => item['score'] as double)
                .reduce((a, b) => a + b) /
            allScores.length;
        lastScore = allScores.last['score'] as double;

        // Calculate trend
        if (allScores.length >= 2) {
          int halfLength = (allScores.length / 2).ceil();
          final firstHalf = allScores.take(halfLength).toList();
          final secondHalf = allScores
              .skip(allScores.length - halfLength)
              .toList();

          double firstAvg =
              firstHalf
                  .map((item) => item['score'] as double)
                  .reduce((a, b) => a + b) /
              firstHalf.length;
          double secondAvg =
              secondHalf
                  .map((item) => item['score'] as double)
                  .reduce((a, b) => a + b) /
              secondHalf.length;
          trend = secondAvg - firstAvg;
        }

        // Determine level
        if (averageScore >= 80) {
          level = 'Advanced';
        } else if (averageScore >= 60) {
          level = 'Intermediate';
        } else {
          level = 'Beginner';
        }
      }

      skillAnalysis[skillName] = {
        'score': averageScore.round().toDouble(),
        'trend': trend.round().toDouble(),
        'level': level,
        'attempts': totalAttempts,
        'lastScore': lastScore.round().toDouble(),
        'weight': config['weight'],
      };
    });
  }

  double _extractScoreForSkill(Map<String, dynamic> attempt, String skillName) {
    if (skillName == 'Speaking Fluency') {
      // Extract Azure fluency scores for speaking lessons
      final detailedResponses =
          attempt['detailedResponses'] as Map<String, dynamic>?;
      if (detailedResponses != null) {
        final details =
            detailedResponses['turnDetails'] ??
            detailedResponses['promptDetails'] ??
            [];
        List<double> fluencyScores = [];

        for (var detail in details) {
          if (detail is Map<String, dynamic>) {
            final character = detail['character'] as String? ?? '';
            if (character.contains('Agent') &&
                detail['azureAiFeedback'] != null) {
              final feedback =
                  detail['azureAiFeedback'] as Map<String, dynamic>;
              if (feedback['fluencyScore'] != null) {
                fluencyScores.add(
                  (feedback['fluencyScore'] as num).toDouble() / 5 * 100,
                );
              }
            }
          }
        }

        if (fluencyScores.isNotEmpty) {
          return fluencyScores.reduce((a, b) => a + b) / fluencyScores.length;
        }
      }
    } else if (skillName == 'Call Center Readiness') {
      // For call simulation lessons, extract overall performance
      final detailedResponses =
          attempt['detailedResponses'] as Map<String, dynamic>?;
      if (detailedResponses != null &&
          detailedResponses['feedbackReport'] != null) {
        final feedbackReport =
            detailedResponses['feedbackReport'] as Map<String, dynamic>;
        return (feedbackReport['overallScore'] as num?)?.toDouble() ??
            (attempt['score'] as num?)?.toDouble() ??
            0.0;
      }
    }

    // Default score extraction
    return (attempt['score'] as num?)?.toDouble() ?? 0.0;
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    return DateTime.now();
  }

  void _calculateModuleProgress(Map<String, dynamic> userData) {
    // Updated module structure to match actual Firebase data
    final moduleMapping = {
      'module1': {
        'title': 'Module 1: Basic English Grammar',
        'lessons': ['Lesson-1-1', 'Lesson-1-2', 'Lesson-1-3'],
        'color': const Color(0xFF0077B3),
      },
      'module2': {
        'title': 'Module 2: Vocabulary & Everyday Conversations',
        'lessons': ['Lesson-2-1', 'Lesson-2-2', 'Lesson-2-3'],
        'color': const Color(0xFFFF9800),
      },
      'module3': {
        'title': 'Module 3: Listening & Speaking Practice',
        'lessons': ['Lesson-3-1', 'Lesson-3-2'],
        'color': const Color(0xFF4CAF50),
      },
      'module4': {
        'title': 'Module 4: Practical Grammar & Customer Service Scenarios',
        'lessons': ['Lesson-4-1', 'Lesson-4-2'],
        'color': const Color(0xFF9C27B0),
      },
      'module5': {
        'title': 'Module 5: Basic Call Simulation Practice',
        'lessons': ['Lesson-5-1', 'Lesson-5-2'],
        'color': const Color(0xFFE91E63),
      },
      'module6': {
        'title': 'Module 6: Advanced Call Simulation',
        'lessons': ['Lesson-6-1'],
        'color': const Color(0xFF00A6CB),
      },
    };

    // Clear existing data
    moduleProgress.clear();

    // Get lesson attempts from userData
    final lessonAttempts =
        userData['lessonAttempts'] as Map<String, dynamic>? ?? {};

    for (String moduleId in moduleMapping.keys) {
      final moduleConfig = moduleMapping[moduleId]!;
      final lessons = moduleConfig['lessons'] as List<String>;

      int completedLessons = 0;
      List<double> allScores = [];

      // Check each lesson for completion and scores
      for (String lessonId in lessons) {
        final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];
        if (attempts.isNotEmpty) {
          completedLessons++;
          // Get the best score for this lesson
          double bestScore = 0;
          for (var attempt in attempts) {
            if (attempt is Map<String, dynamic> && attempt['score'] != null) {
              bestScore = math.max(
                bestScore,
                (attempt['score'] as num).toDouble(),
              );
            }
          }
          if (bestScore > 0) {
            allScores.add(bestScore);
          }
        }
      }

      final totalLessons = lessons.length;
      final completionRate = totalLessons > 0
          ? (completedLessons / totalLessons * 100).round()
          : 0;
      final averageScore = allScores.isNotEmpty
          ? (allScores.reduce((a, b) => a + b) / allScores.length).round()
          : 0;

      // Determine level based on completion and performance
      String level = 'Beginner';
      if (completionRate == 100 && averageScore >= 80) {
        level = 'Advanced';
      } else if (completionRate >= 50 && averageScore >= 60) {
        level = 'Intermediate';
      }

      moduleProgress[moduleId] = {
        'title': moduleConfig['title'],
        'completionRate': completionRate,
        'averageScore': averageScore,
        'lessonsCompleted': completedLessons,
        'totalLessons': totalLessons,
        'level': level,
        'color': moduleConfig['color'],
      };
    }
  }

  Color _getModuleColor(String moduleId) {
    final colors = {
      'module1': const Color(0xFF0077B3),
      'module2': const Color(0xFF00A6CB),
      'module3': const Color(0xFF4CAF50),
      'module4': const Color(0xFFFF9800),
      'module5': const Color(0xFF9C27B0),
      'module6': const Color(0xFFE91E63),
    };
    return colors[moduleId] ?? const Color(0xFF0077B3);
  }

  Future<void> _calculateEnhancedUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final userData = doc.data() as Map<String, dynamic>;
        final lessonAttempts =
            userData['lessonAttempts'] as Map<String, dynamic>? ?? {};

        // Calculate speaking time from lesson attempts
        _calculateSpeakingTimeFromAttempts(lessonAttempts);

        // Calculate streak
        _calculateStreakFromAttempts(lessonAttempts);

        // Calculate lessons completed
        _lessonsCompleted = lessonAttempts.keys.length;

        // Calculate average score
        _calculateAverageScore(lessonAttempts);
      }
    } catch (e) {
      logger.e('Error calculating enhanced user stats: $e');
    }
  }

  void _calculateSpeakingTimeFromAttempts(Map<String, dynamic> lessonAttempts) {
    int totalSpeakingSeconds = 0;

    for (String lessonId in lessonAttempts.keys) {
      final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];
      for (var attempt in attempts) {
        if (attempt is Map<String, dynamic>) {
          // Extract speaking time from different lesson types
          final detailedResponses =
              attempt['detailedResponses'] as Map<String, dynamic>?;
          if (detailedResponses != null) {
            // For speaking lessons with turn details
            final turnDetails =
                detailedResponses['turnDetails'] as List<dynamic>? ?? [];
            for (var turn in turnDetails) {
              if (turn is Map<String, dynamic>) {
                final character = turn['character'] as String? ?? '';
                if (character.contains('Agent') &&
                    turn['speechDuration'] != null) {
                  totalSpeakingSeconds += (turn['speechDuration'] as num)
                      .toInt();
                }
              }
            }

            // For lessons with prompt details
            final promptDetails =
                detailedResponses['promptDetails'] as List<dynamic>? ?? [];
            for (var prompt in promptDetails) {
              if (prompt is Map<String, dynamic> &&
                  prompt['userResponse'] != null) {
                final userResponse =
                    prompt['userResponse'] as Map<String, dynamic>;
                if (userResponse['speechDuration'] != null) {
                  totalSpeakingSeconds +=
                      (userResponse['speechDuration'] as num).toInt();
                }
              }
            }

            // For call simulation lessons
            final callSimulation =
                detailedResponses['callSimulation'] as Map<String, dynamic>?;
            if (callSimulation != null &&
                callSimulation['totalSpeakingTime'] != null) {
              totalSpeakingSeconds +=
                  (callSimulation['totalSpeakingTime'] as num).toInt();
            }
          }

          // Fallback: if lesson has a duration field
          if (attempt['duration'] != null) {
            totalSpeakingSeconds += (attempt['duration'] as num).toInt();
          }
        }
      }
    }

    _totalSpeakingTime = Duration(seconds: totalSpeakingSeconds);
  }

  void _calculateStreakFromAttempts(Map<String, dynamic> lessonAttempts) {
    final Set<String> activityDates = {};

    for (var attempts in lessonAttempts.values) {
      if (attempts is List) {
        for (var attempt in attempts) {
          if (attempt is Map<String, dynamic> &&
              attempt['attemptTimestamp'] != null) {
            DateTime dateObj = _parseTimestamp(attempt['attemptTimestamp']);
            String dateString =
                '${dateObj.year}-${dateObj.month.toString().padLeft(2, '0')}-${dateObj.day.toString().padLeft(2, '0')}';
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

    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final lastActivityStr = sortedDates.last;

    if (lastActivityStr == todayStr || lastActivityStr == yesterdayStr) {
      _currentStreak = 1;
      DateTime currentDate = DateTime.parse(lastActivityStr);

      for (int i = sortedDates.length - 2; i >= 0; i--) {
        final expectedPrevious = currentDate.subtract(const Duration(days: 1));
        final expectedStr =
            '${expectedPrevious.year}-${expectedPrevious.month.toString().padLeft(2, '0')}-${expectedPrevious.day.toString().padLeft(2, '0')}';

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

  void _calculateAverageScore(Map<String, dynamic> lessonAttempts) {
    List<double> allScores = [];

    for (var attempts in lessonAttempts.values) {
      if (attempts is List) {
        for (var attempt in attempts) {
          if (attempt is Map<String, dynamic> && attempt['score'] != null) {
            allScores.add((attempt['score'] as num).toDouble());
          }
        }
      }
    }

    if (allScores.isNotEmpty) {
      _averageScore = allScores.reduce((a, b) => a + b) / allScores.length;
    } else {
      _averageScore = 0.0;
    }
  }

  Future<void> _fetchDailyContent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      tipLoading = true;
    });

    try {
      // Prepare user progress summary for the server
      Map<String, dynamic>? progressSummary;

      // Fix: Get the lesson attempts data properly
      final allLessonAttempts = await FirebaseService()
          .getAllUserLessonAttempts();

      if (allLessonAttempts.isNotEmpty) {
        final skillScores = skillAnalysis.values
            .map((skill) => skill['score'] as double)
            .toList();
        final averageScore = skillScores.isNotEmpty
            ? skillScores.reduce((a, b) => a + b) / skillScores.length
            : 50.0;

        progressSummary = {
          'totalLessons':
              allLessonAttempts.keys.length, // Use allLessonAttempts
          'averageScore': averageScore,
          'weakestSkills': skillAnalysis.entries
              .where((entry) => (entry.value['score'] as double) < 60)
              .map(
                (entry) => {
                  'name': entry.key.split(' ').first,
                  'score': entry.value['score'],
                },
              )
              .take(3)
              .toList(),
          'strongestSkills': skillAnalysis.entries
              .where((entry) => (entry.value['score'] as double) >= 70)
              .map(
                (entry) => {
                  'name': entry.key.split(' ').first,
                  'score': entry.value['score'],
                },
              )
              .take(2)
              .toList(),
          'recentActivity': allLessonAttempts.keys
              .take(5)
              .toList(), // Last 5 lesson IDs
        };
      }

      // Rest of your method remains the same...
      // Calculate average score for motivation
      final skillScores = skillAnalysis.values
          .map((skill) => skill['score'] as double)
          .toList();
      final averageScore = skillScores.isNotEmpty
          ? skillScores.reduce((a, b) => a + b) / skillScores.length
          : 50.0;

      // Fetch both tip and motivation concurrently
      final results = await Future.wait([
        DailyContentService.fetchLearningTip(
          userProgress: progressSummary,
          currentStreak: _currentStreak,
          averageScore: averageScore,
        ),
        DailyContentService.fetchDailyMotivation(
          currentStreak: _currentStreak,
          averageScore: averageScore,
        ),
      ]);

      setState(() {
        dailyTip = results[0] ?? DailyContentService.getFallbackTip();
        dailyMotivation =
            results[1] ?? DailyContentService.getFallbackMotivation();
      });

      logger.i('Daily content fetched successfully from server');
    } catch (error) {
      logger.e('Error fetching daily content: $error');

      setState(() {
        dailyTip = DailyContentService.getFallbackTip();
        dailyMotivation = DailyContentService.getFallbackMotivation();
      });
    } finally {
      setState(() {
        tipLoading = false;
      });
    }
  }

  Future<void> _loadFeaturedCourses() async {
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
    if (skillAnalysis.isEmpty) return 0.0;
    double totalScore = 0.0;
    int count = 0;

    skillAnalysis.forEach((skill, data) {
      totalScore += data['score'] as double;
      count++;
    });

    return count > 0 ? totalScore / count : 0.0;
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
    logger.d(
      'Tapped navigation item. Index: $index, currentIndex: $_selectedIndex',
    );
    if (_selectedIndex == index) return;

    final int oldNavIndex = _selectedIndex;

    setState(() {
      _selectedIndex = index;
    });

    Widget nextPage;
    switch (index) {
      case 0:
        return;
      case 1:
        nextPage = const CoursesPage();
        break;
      case 2:
        nextPage = const MyEnrolledClasses();
        break;
      case 3:
        nextPage = const JournalPage();
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

  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  void _setupRealTimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userDataSubscription = FirebaseFirestore.instance
        .collection('userProgress')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && mounted) {
              final userData = snapshot.data() as Map<String, dynamic>?;
              if (userData != null) {
                final lessonAttempts =
                    userData['lessonAttempts'] as Map<String, dynamic>? ?? {};
                _calculateEnhancedSkillAnalysis(lessonAttempts);
                _calculateEnhancedUserStats();
                setState(() {});
              }
            }
          },
          onError: (error) {
            logger.e('Error listening to user data: $error');
          },
        );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _userDataSubscription?.cancel();
    super.dispose();
  }

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
          Image.asset('images/TR Logo.png', height: 40, width: 40),
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
                MaterialPageRoute(
                  builder: (context) => const AllNotificationsPage(),
                ),
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
      body: Column(
        children: [
          _buildAppBarWithLogo(),
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
          padding: const EdgeInsets.all(16.0),
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

              const SizedBox(height: 20),

              // Enhanced Skill Progress Tracker
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildEnhancedSkillProgressSection(),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Enhanced User Stats Section
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildEnhancedUserStatsSection(),
                  );
                },
              ),

              const SizedBox(height: 16),

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

              const SizedBox(height: 16),

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00568D).withOpacity(0.1),
            const Color(0xFF00A6CB).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Welcome $firstName to TalkReady',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your AI-powered platform for mastering English communication in real-world customer service scenarios.',
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSkillProgressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
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
        children: [
          // Header with View Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enhanced Progress Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF0077B3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Comprehensive tracking of your English communication skills',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewToggleButton(
                      'overview',
                      'Overview',
                      Icons.bar_chart,
                    ),
                    _buildViewToggleButton('modules', 'Modules', Icons.book),
                    _buildViewToggleButton(
                      'trends',
                      'Trends',
                      Icons.trending_up,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Content based on active view
          _buildActiveViewContent(),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton(String key, String label, IconData icon) {
    final isActive = _activeView == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeView = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0077B3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveViewContent() {
    switch (_activeView) {
      case 'overview':
        return _buildOverviewContent();
      case 'modules':
        return _buildModulesContent();
      case 'trends':
        return _buildTrendsContent();
      default:
        return _buildOverviewContent();
    }
  }

  Widget _buildOverviewContent() {
    return Column(
      children: [
        // Skill Assessment with Pentagon Graph
        Row(
          children: [
            // Pentagon Graph
            Expanded(
              flex: 1,
              child: Container(
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PentagonGraph(
                      size: 140,
                      progress: overallPercentage / 100,
                      selectedSkill: selectedSkill,
                    ),
                    Text(
                      '${((selectedSkill != null ? (skillAnalysis[selectedSkill]?['score'] ?? 0) : overallPercentage)).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Performance Insights
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance Insights',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Strengths
                    _buildInsightSection(
                      'Strengths',
                      Icons.check_circle,
                      Colors.green,
                      _getStrengths(),
                    ),

                    const SizedBox(height: 8),

                    // Focus Areas
                    _buildInsightSection(
                      'Focus Areas',
                      Icons.gps_fixed,
                      Colors.orange,
                      _getImprovements(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Skill Buttons
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: skillAnalysis.keys.map((skill) {
            final skillData = skillAnalysis[skill]!;
            final skillColors = {
              "Foundation Grammar": const Color(0xFFD8F6F7),
              "Conversational Skills": const Color(0xFFDEE3FF),
              "Listening Comprehension": const Color(0xFFFFD6D6),
              "Speaking Fluency": const Color(0xFFFFF0C3),
              "Professional Communication": const Color(0xFFE0FFD6),
              "Call Center Readiness": const Color(0xFFFFE0E6),
            };

            bool isSelected = selectedSkill == skill;
            return InkWell(
              onTap: () => _handleSkillSelected(skill),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? skillColors[skill]?.withOpacity(0.7)
                      : skillColors[skill] ?? Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF00568D), width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      skill.split(' ').first,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF00568D)
                            : Colors.black,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${skillData['score'].toInt()}%',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF00568D)
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        if (skillData['trend'] > 0) ...[
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.trending_up,
                            color: Colors.green,
                            size: 10,
                          ),
                        ] else if (skillData['trend'] < 0) ...[
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.trending_down,
                            color: Colors.red,
                            size: 10,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Skill Description
        if (selectedSkill != null) ...[
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(selectedSkill),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedSkill!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${skillAnalysis[selectedSkill]!['score'].toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0077B3),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getLevelColor(
                                skillAnalysis[selectedSkill]!['level'],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              skillAnalysis[selectedSkill]!['level'],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    skillDescriptions[selectedSkill] ??
                        'No description available.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on ${skillAnalysis[selectedSkill]!['attempts']} attempt(s) across relevant lessons.',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInsightSection(
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items
            .take(2)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $item',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ),
            ),
      ],
    );
  }

  List<String> _getStrengths() {
    return skillAnalysis.entries
        .where((entry) => entry.value['score'] >= 70)
        .map((entry) => entry.key.split(' ').first)
        .take(3)
        .toList();
  }

  List<String> _getImprovements() {
    return skillAnalysis.entries
        .where((entry) => entry.value['score'] < 60)
        .map((entry) => entry.key.split(' ').first)
        .take(3)
        .toList();
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Advanced':
        return Colors.green;
      case 'Intermediate':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Widget _buildModulesContent() {
    if (moduleProgress.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.book, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No Module Progress Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Start your first lesson to see module progress here',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Text(
          'Module Progress Overview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ...moduleProgress.entries.map((entry) {
          final moduleId = entry.key;
          final module = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16), // Increased padding
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                12,
              ), // Increased border radius
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: module['color'],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        module['title'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis, // <--- add this!
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: module['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${module['completionRate']}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: module['color'],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lessons: ${module['lessonsCompleted']}/${module['totalLessons']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'Avg Score: ${module['averageScore']}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: module['completionRate'] / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(module['color']),
                  minHeight: 6, // Thicker progress bar
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      module['completionRate'] == 100
                          ? '✓ Module Complete!'
                          : module['completionRate'] > 0
                          ? '📚 In Progress'
                          : '🔒 Not Started',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: module['completionRate'] == 100
                            ? Colors.green
                            : module['completionRate'] > 0
                            ? Colors.blue
                            : Colors.grey,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getLevelColor(module['level']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        module['level'],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getLevelColor(module['level']),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Updated Trends Content with better layout
  Widget _buildTrendsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Progress Chart - Improved mobile layout
          Container(
            height: 240, // Increased height for better mobile display
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                const Text(
                  'Progress Over Time',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _lessonsCompleted > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ), // Added padding
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (index) {
                              final height =
                                  math.Random().nextDouble() * 80 + 40;
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ), // Reduced margin
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        height: height,
                                        width: double
                                            .infinity, // Use full width available
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              const Color(0xFF0077B3),
                                              const Color(
                                                0xFF0077B3,
                                              ).withOpacity(0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'D${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 11, // Slightly smaller font
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Trend Data Available',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Complete more lessons to see your progress trends',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Understanding Your Trends - Improved mobile layout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Understanding Your Trends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // What This Shows
                _buildTrendInfoCard(
                  '📈 What This Shows',
                  'This chart tracks your daily average scores across all completed lessons over the last 30 days.',
                  Colors.blue[50]!,
                  Colors.blue[800]!,
                ),

                const SizedBox(height: 12),

                // How to Read It - Improved mobile formatting
                _buildTrendInfoCard(
                  '🎯 How to Read It',
                  '• Y-axis: Your performance score (0-100%)\n• X-axis: Days over the past month\n• Blue bars: Your daily average performance\n• Gaps: Days with no lesson activity',
                  Colors.green[50]!,
                  Colors.green[800]!,
                ),

                const SizedBox(height: 12),

                // Insights
                _buildTrendInfoCard(
                  '💡 Insights',
                  _averageScore > 75
                      ? '🚀 Great progress! Your scores are trending upward.'
                      : _averageScore < 50
                      ? '📉 Consider reviewing previous lessons to strengthen your foundation.'
                      : '📊 Your performance is stable. Keep practicing consistently!',
                  Colors.yellow[50]!,
                  Colors.yellow[800]!,
                ),

                const SizedBox(height: 12),

                // Study Tips
                _buildTrendInfoCard(
                  '📚 Study Tips',
                  '• Aim for consistent daily practice\n• Review lessons with lower scores\n• Use the AI Chatbot for extra practice\n• Focus on your improvement areas',
                  Colors.purple[50]!,
                  Colors.purple[800]!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendInfoCard(
    String title,
    String content,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedUserStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.access_time,
                  title: 'Speaking Time',
                  value: _formatSpeakingTime(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_fire_department,
                  title: 'Current Streak',
                  value:
                      '$_currentStreak ${_currentStreak == 1 ? "day" : "days"}',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.school,
                  title: 'Lessons Done',
                  value: '$_lessonsCompleted',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.bar_chart,
                  title: 'Avg Score',
                  value: '${_averageScore.round()}%',
                  color: Colors.purple,
                ),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContentGrid() {
    return Column(
      children: [
        // TalkReady AI Chatbot Section (full width)
        Container(
          width: double.infinity,
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
                'Learning Tips & Motivation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0077B3),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              if (tipLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                const Text(
                  'Loading your personalized tips...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Daily Motivation
                if (dailyMotivation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[50]!, Colors.indigo[50]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(color: Colors.blue[500]!, width: 4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dailyMotivation!['emoji'] ?? '🌟',
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daily Motivation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dailyMotivation!['message'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Learning Tip
                if (dailyTip != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[50]!, Colors.green[100]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(color: Colors.green[500]!, width: 4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.school, size: 24, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with badges - Fixed for mobile
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Today\'s Learning Tip',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Wrap badges in a responsive way
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          dailyTip!['category'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          dailyTip!['estimatedTime'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                dailyTip!['tip'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '💡 ${dailyTip!['motivation'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons - Responsive layout
                Column(
                  children: [
                    // First row of buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[500],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '🎯 Practice Now',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
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
                              backgroundColor: Colors.grey[500],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '📚 View Courses',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Second row - New tip button (full width on mobile)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _fetchDailyContent();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[500],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: tipLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                '🔄 Get New Tip',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                // Progress Context
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Text(
                    '🎯 Current streak: $_currentStreak days${_currentStreak > 0 ? ' • Keep it up! 🔥' : ''}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCoursesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _featuredCourses.length,
              itemBuilder: (context, index) {
                final course = _featuredCourses[index];
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 60,
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
                            size: 28,
                            color: course['color'] as Color,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course['reason'] as String,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                course['title'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
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
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                height: 24,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CoursesPage(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00568D),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text(
                                    'Go to Course',
                                    style: TextStyle(fontSize: 9),
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
      {
        'icon': Icons.class_,
        'label': 'My Classes',
        'route': const MyEnrolledClasses(),
      },
      {'icon': Icons.book, 'label': 'Journal', 'route': const JournalPage()},
      {
        'icon': Icons.bar_chart,
        'label': 'My Reports',
        'route': const ProgressTrackerPage(),
      },
      {
        'icon': Icons.mic,
        'label': 'Practice Test',
        'route': AIBotScreen(onBackPressed: () => Navigator.pop(context)),
      },
      {'icon': Icons.person, 'label': 'Profile', 'route': const ProfilePage()},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
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
            'Quick Navigation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0077B3),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Easily access different features of TalkReady',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
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
                        size: 24,
                        color: const Color(0xFF0077B3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['label'] as String,
                        style: const TextStyle(
                          fontSize: 10,
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
    "Foundation Grammar": Color(0xFFD8F6F7),
    "Conversational Skills": Color(0xFFDEE3FF),
    "Listening Comprehension": Color(0xFFFFD6D6),
    "Speaking Fluency": Color(0xFFFFF0C3),
    "Professional Communication": Color(0xFFE0FFD6),
    "Call Center Readiness": Color(0xFFFFE0E6),
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
  static const greyColor = Color(0xFF6B7280);

  PentagonPainter({
    required this.progress,
    this.selectedSkill,
    this.skillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

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
        colors: [skillColor!.withOpacity(0.4), skillColor!],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      progressPaint.shader = LinearGradient(
        colors: [greyColor.withOpacity(0.4), greyColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    final progressPath = Path();
    _createPentagonPath(progressPath, center, radius * progress);
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
