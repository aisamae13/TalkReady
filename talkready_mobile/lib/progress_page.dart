// progress_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:talkready_mobile/custom_animated_bottom_bar.dart';
import 'package:fl_chart/fl_chart.dart'; // For charts
import 'package:flutter_html/flutter_html.dart'; // For OpenAI HTML feedback
// Import PDF and printing packages if you were to implement PDF generation
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';

import '../firebase_service.dart'; // Your FirebaseService
import 'homepage.dart';
import 'courses_page.dart';
import 'journal/journal_page.dart';
import 'profile.dart';
import 'package:talkready_mobile/MyEnrolledClasses.dart';

// ... (COURSE_STRUCTURE_MOBILE and lessonPromptsDataMobile remain the same)
const Map<String, Map<String, dynamic>> COURSE_STRUCTURE_MOBILE = {
  "module1": {
    "title": "Module 1: Basic English Grammar",
    "lessons": [
      {
        "firestoreId": "Lesson 1.1",
        "title": "Lesson 1.1: Nouns and Pronouns",
        "type": "MCQ"
      },
      {
        "firestoreId": "Lesson 1.2",
        "title": "Lesson 1.2: Simple Sentences",
        "type": "MCQ"
      },
      {
        "firestoreId": "Lesson 1.3",
        "title": "Lesson 1.3: Verb and Tenses (Present Simple)",
        "type": "MCQ"
      },
    ]
  },
  "module2": {
    "title": "Module 2: Vocabulary & Everyday Conversations",
    "lessons": [
      {
        "firestoreId": "Lesson 2.1",
        "title": "Lesson 2.1: Greetings and Self-Introductions",
        "type": "TEXT_SCENARIO"
      },
      {
        "firestoreId": "Lesson 2.2",
        "title": "Lesson 2.2: Asking for Information",
        "type": "TEXT_SCENARIO"
      },
      {
        "firestoreId": "Lesson 2.3",
        "title": "Lesson 2.3: Numbers and Dates",
        "type": "TEXT_FILL_IN"
      },
    ]
  },
  "module3": {
    "title": "Module 3: Listening & Speaking Practice",
    "lessons": [
      {
        "firestoreId": "Lesson 3.1",
        "title": "Lesson 3.1: Listening Comprehension",
        "type": "LISTENING_COMP"
      },
      {
        "firestoreId": "Lesson 3.2",
        "title": "Lesson 3.2: Speaking Practice - Dialogues",
        "type": "SPEAKING_PRACTICE"
      },
    ]
  },
  "module4": {
    "title": "Module 4: Practical Grammar & Customer Service Scenarios",
    "lessons": [
      {
        "firestoreId": "Lesson 4.1",
        "title": "Lesson 4.1: Asking for Clarification",
        "type": "CLARIFICATION_SCENARIO"
      },
      {
        "firestoreId": "Lesson 4.2",
        "title": "Lesson 4.2: Providing Solutions",
        "type": "PROVIDING_SOLUTIONS"
      },
    ]
  },
  "module5": {
    "title": "Module 5: Basic Call Simulations",
    "lessons": [
      {
        "firestoreId": "Lesson 5.1",
        "title": "Lesson 5.1: Call Simulation - Scenario 1",
        "type": "BASIC_CALL_SIMULATION"
      },
      {
        "firestoreId": "Lesson 5.2",
        "title": "Lesson 5.2: Call Simulation - Scenario 2",
        "type": "BASIC_CALL_SIMULATION"
      },
    ]
  },
};

final Map<String, Map<String, dynamic>> lessonPromptsDataMobile = {
  "Lesson 1.1": {
    "type": "MCQ",
    "prompts": [],
    "detailsArrayKey": "attemptDetails",
    "maxPossibleAIScore": 5.0
  },
  "Lesson 1.2": {
    "type": "MCQ",
    "prompts": [],
    "detailsArrayKey": "attemptDetails",
    "maxPossibleAIScore": 5.0
  },
  "Lesson 1.3": {
    "type": "MCQ",
    "prompts": [],
    "detailsArrayKey": "attemptDetails",
    "maxPossibleAIScore": 5.0
  },
  "Lesson 2.1": {
    "type": "TEXT_SCENARIO",
    "prompts": [
      {
        "name": "scenario1",
        "label": "Scenario 1: Customer Greeting",
        "customerText": "Customer: \"Good morning, is this customer support?\""
      },
      {
        "name": "scenario2",
        "label": "Scenario 2: Customer Needs Help",
        "customerText": "Customer: \"Hello, I need help with my order.\""
      }
    ],
    "answersKey": "scenarioAnswers_L2_1",
    "feedbackKey": "scenarioFeedback_L2_1",
    "maxScorePerPrompt": 5.0,
    "maxPossibleAIScore": 10.0
  },
  "Lesson 2.2": {
    "type": "TEXT_SCENARIO",
    "prompts": [
      {
        "name": "scenario1",
        "label": "Scenario 1: Broken Item",
        "customerText":
            "Customer: \"I need help with my recent purchase. The item I received is broken.\""
      },
      {
        "name": "scenario2",
        "label": "Scenario 2: Slow Internet",
        "customerText":
            "Customer: \"My internet has been very slow for the past few days.\""
      }
    ],
    "answersKey": "scenarioAnswers_L2_2",
    "feedbackKey": "scenarioFeedback_L2_2",
    "maxScorePerPrompt": 5.0,
    "maxPossibleAIScore": 10.0
  },
  "Lesson 2.3": {
    "type": "TEXT_FILL_IN",
    "prompts": [
      {
        "name": "price",
        "promptText": "Prompt 1 – Price Confirmation",
        "customerText": "Customer: “How much is the total for my order?”"
      },
      {
        "name": "delivery",
        "promptText": "Prompt 2 – Delivery Date",
        "customerText": "Customer: “When can I expect my package?”"
      },
      {
        "name": "appointment",
        "promptText": "Prompt 3 – Time Appointment",
        "customerText": "Customer: “What time is my appointment?”"
      },
      {
        "name": "account",
        "promptText": "Prompt 4 – Account Number",
        "customerText": "Customer: “Can you check my account?”"
      },
      {
        "name": "billing",
        "promptText": "Prompt 5 – Billing Issue",
        "customerText": "Customer: “I was charged twice!”"
      },
    ],
    "answersKey": "answers",
    "feedbackKey": "feedbackForEachAnswer",
    "maxScorePerPrompt": 5.0,
    "maxPossibleAIScore": 25.0
  },
  "Lesson 3.1": {
    "type": "LISTENING_COMP",
    "scripts": {
      "1":
          "Customer: Hi, I received the wrong item in my order. Agent: I'm really sorry about that. Can you please provide the order number? Customer: It's 784512. Agent: Thank you. I’ll arrange a replacement right away. Customer: Thanks.",
      "2":
          "Customer: My internet has been disconnected for two days. Agent: I apologize for the inconvenience. Can I have your account ID? Customer: Sure, it's 56102. Agent: I’ve reported the issue and a technician will visit tomorrow. Customer: Great, thanks.",
      "3":
          "Customer: I was charged twice for the same bill. Agent: I see. Can I verify your billing date and amount? Customer: April 3rd, \$39.99. Agent: I’ll process the refund today. Customer: Thank you.",
    },
    "prompts": [
      "What was the customer’s issue?",
      "What information did the agent ask for?",
      "What solution did the agent offer?",
      "Was the customer satisfied with the response? (e.g., Yes/No, and why)"
    ],
    "answersKey": "answers",
    "feedbackKey": "feedbackForAnswers",
    "maxScorePerPrompt": 5.0,
    "maxPossibleAIScore": 60.0
  },
  "Lesson 3.2": {
    "type": "SPEAKING_PRACTICE",
    "prompts": [
      {
        "id": 'd1_agent1',
        "text":
            "Good morning! This is Anna from TechSupport. How can I assist you?",
        "character": "Agent"
      },
      {
        "id": 'd1_agent2',
        "text": "I’m sorry about that. Can I get your account number, please?",
        "character": "Agent"
      },
      {
        "id": 'd2_agent1',
        "text": "Hello! Thank you for calling. What can I help you with today?",
        "character": "Agent"
      },
      {
        "id": 'd2_agent2',
        "text": "Certainly. May I have your tracking number?",
        "character": "Agent"
      },
      {
        "id": 'd3_agent1',
        "text":
            "Thank you for waiting. I’ve confirmed your refund has been processed.",
        "character": "Agent"
      },
      {
        "id": 'd3_agent2',
        "text": "You're welcome! Have a great day.",
        "character": "Agent"
      },
    ],
    "detailsArrayKey": "promptDetails",
    "maxPossibleAIScore": 100.0
  },
  "Lesson 4.1": {
    "type": "CLARIFICATION_SCENARIO",
    "prompts": [
      {
        "name": 'scenario1',
        "scenarioText":
            '“Yes, my order was… [muffled] … and I need to change the delivery.”'
      },
      {
        "name": 'scenario2',
        "scenarioText": '“My email is zlaytsev_b12@yahoo.com.”'
      },
      {"name": 'scenario3', "scenarioText": '“The item number is 47823A.”'},
      {
        "name": 'scenario4',
        "scenarioText":
            '“Yeah I called yesterday and they said it’d be fixed in two days but it’s not.”'
      },
    ],
    "answersKey": "scenarioResponses",
    "feedbackKey": "aiFeedbackForScenarios",
    "maxScorePerPrompt": 2.5,
    "maxPossibleAIScore": 10.0
  },
  "Lesson 4.2": {
    "type": "PROVIDING_SOLUTIONS",
    "prompts": [
      {
        "name": "solution1",
        "label": "Scenario 1: Wrong Item",
        "customerProblem": "Customer: “I received the wrong item.”"
      },
      {
        "name": "solution2",
        "label": "Scenario 2: Order Not Arrived",
        "customerProblem":
            "Customer: “My order hasn’t arrived yet, and it’s past the estimated delivery date.”"
      },
      {
        "name": "solution3",
        "label": "Scenario 3: Payment Issue",
        "customerProblem":
            "Customer: “My payment didn’t go through, but I was still charged.”"
      },
      {
        "name": "solution4",
        "label": "Scenario 4: Subscription Cancellation",
        "customerProblem":
            "Customer: “I want to cancel my subscription, but I can’t find the option online.”"
      }
    ],
    "answersKey": "solutionResponses_L4_2",
    "feedbackKey": "solutionFeedback_L4_2",
    "maxScorePerPrompt": 5.0,
    "maxPossibleAIScore": 20.0
  },
  "Lesson 5.1": {
    "type": "BASIC_CALL_SIMULATION",
    "prompts": [
      {
        "id": 'turn1_customer_complex',
        "text":
            "Hi there, I was hoping to find out your opening hours today...",
        "character": "Customer"
      },
      {
        "id": 'turn2_agent_complex',
        "text": "Good morning! Our standard hours are Monday to Friday...",
        "character": "Agent - Your Turn"
      },
      {
        "id": 'turn3_customer_complex',
        "text": "Oh, closed on Saturdays? That's a bit inconvenient...",
        "character": "Customer"
      },
      {
        "id": 'turn4_agent_complex',
        "text":
            "I understand that can be inconvenient. While our live phone support...",
        "character": "Agent - Your Turn"
      },
      {
        "id": 'turn5_customer_complex',
        "text": "Okay, yes, the email address would be helpful. Thank you.",
        "character": "Customer"
      },
      {
        "id": 'turn6_agent_complex',
        "text": "Certainly, our support email is support@talkready.ai...",
        "character": "Agent - Your Turn"
      },
    ],
    "detailsArrayKey": "promptDetails",
    "maxPossibleAIScore": 100.0
  },
  "Lesson 5.2": {
    "type": "BASIC_CALL_SIMULATION",
    "prompts": [
      {
        "id": 'turn1_customer_s2_complex',
        "text": "Hi, I made a payment online a little while ago...",
        "character": "Customer"
      },
      {
        "id": 'turn2_agent_s2_complex',
        "text": "Hello! I can certainly check on that payment for you...",
        "character": "Agent - Your Turn"
      },
      {
        "id": 'turn3_customer_s2_complex',
        "text":
            "Sure, the email is customer@example.com. And while you're checking...",
        "character": "Customer"
      },
      {
        "id": 'turn4_agent_s2_complex',
        "text":
            "Thank you, I've found your order. Yes, I can confirm your payment...",
        "character": "Agent - Your Turn"
      },
      {
        "id": 'turn5_customer_s2_complex',
        "text": "No, that's all. Thank you for your help!",
        "character": "Customer"
      },
      {
        "id": 'turn6_agent_s2_complex',
        "text": "You're very welcome! Have a wonderful day...",
        "character": "Agent - Your Turn"
      },
    ],
    "detailsArrayKey": "promptDetails",
    "maxPossibleAIScore": 100.0
  },
};

class ProgressTrackerPage extends StatefulWidget {
  const ProgressTrackerPage({super.key});

  @override
  State<ProgressTrackerPage> createState() => _ProgressTrackerPageState();
}

class _ProgressTrackerPageState extends State<ProgressTrackerPage> {
  final Logger _logger = Logger();
  final FirebaseService _firebaseService = FirebaseService();
  User? _currentUser;

  bool _isLoading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _allUserAttempts = {};
  // New state for trainer assessment submissions
  List<Map<String, dynamic>> _assessmentSubmissions = [];
  bool _isLoadingAssessments = true; // Separate loading for assessments

  Map<String, dynamic> _overallStats = {
    'attemptedLessonsCount': 0,
    'totalAttempts': 0,
    'averageScore': "N/A"
  };
  final Map<String, bool> _expandedLesson = {};

  // New state for PDF processing
  bool _isProcessingPdf = false;
  String? _processingSubmissionId; // To show loading on a specific item
  bool _isDownloadingFullHistoryPdf = false;
  String? _pdfMessage;

  int _selectedIndex = 4; // Progress is now index 4

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _fetchAllReportData();
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingAssessments = false;
        _error = "Please log in to view your progress.";
      });
    }
  }

  Map<String, dynamic>? _getLessonConfig(String lessonId) {
    Map<String, dynamic>? structureConfig;
    for (var moduleEntry in COURSE_STRUCTURE_MOBILE.entries) {
      var lessons = moduleEntry.value['lessons'] as List<dynamic>?;
      if (lessons != null) {
        for (var lesson in lessons) {
          if (lesson is Map && lesson['firestoreId'] == lessonId) {
            structureConfig = Map<String, dynamic>.from(lesson);
            break;
          }
        }
      }
      if (structureConfig != null) break;
    }

    final promptsData = lessonPromptsDataMobile[lessonId];

    if (structureConfig == null && promptsData == null) {
      _logger.w("No config found for lessonId: $lessonId in _getLessonConfig.");
      return null;
    }
    final mergedConfig = {...(structureConfig ?? {}), ...(promptsData ?? {})};
    if (mergedConfig.isEmpty) {
      _logger.w("Merged config is empty for lessonId: $lessonId");
      return null;
    }
    return mergedConfig;
  }

  Future<void> _fetchAllReportData() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
      _isLoadingAssessments = true; // Start loading assessments too
      _error = null;
      _pdfMessage = null;
    });
    try {
      final attemptsFuture = _firebaseService.getAllUserLessonAttempts();
      // Fetch assessment submissions
      final assessmentSubmissionsFuture =
          _firebaseService.getStudentSubmissionsWithDetails(_currentUser!.uid);

      final results =
          await Future.wait([attemptsFuture, assessmentSubmissionsFuture]);

      final attempts = results[0] as Map<String, List<Map<String, dynamic>>>;
      final assessmentSubmissions = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _allUserAttempts = attempts;
          _assessmentSubmissions = assessmentSubmissions;
          _calculateOverallStats();
          _isLoading = false;
          _isLoadingAssessments = false;
        });
      }
    } catch (e) {
      _logger.e("Error fetching all report data: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to load progress data.";
          _isLoading = false;
          _isLoadingAssessments = false;
        });
      }
    }
  }

  void _calculateOverallStats() {
    if (_allUserAttempts.isEmpty) {
      _overallStats = {
        'attemptedLessonsCount': 0,
        'totalAttempts': 0,
        'averageScore': "N/A"
      };
      return;
    }
    int totalAttempts = 0;
    double totalScoreSum = 0;
    int scoredAttemptsCount = 0;
    Set<String> attemptedLessonIds = {};

    _allUserAttempts.forEach((lessonId, attempts) {
      if (attempts.isNotEmpty) {
        attemptedLessonIds.add(lessonId);
        totalAttempts += attempts.length;
        for (var attempt in attempts) {
          final score = attempt['score'];
          if (score != null && score is num) {
            totalScoreSum += score;
            scoredAttemptsCount++;
          }
        }
      }
    });

    _overallStats = {
      'attemptedLessonsCount': attemptedLessonIds.length,
      'totalAttempts': totalAttempts,
      'averageScore': scoredAttemptsCount > 0
          ? (totalScoreSum / scoredAttemptsCount).toStringAsFixed(1)
          : "N/A"
    };
  }

  String _getLessonTitle(String lessonIdFirestoreKey) {
    for (var moduleEntry in COURSE_STRUCTURE_MOBILE.entries) {
      var lessons = moduleEntry.value['lessons'] as List<dynamic>?;
      if (lessons != null) {
        for (var lesson in lessons) {
          if (lesson is Map && lesson['firestoreId'] == lessonIdFirestoreKey) {
            return lesson['title'] as String? ?? lessonIdFirestoreKey;
          }
        }
      }
    }
    return lessonIdFirestoreKey;
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
            'Progress Tracker',
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

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const HomePage();
        break;
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
        // Already on ProgressTrackerPage
        return;
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

  Widget _buildOverallStatsCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AI Lesson Progress", // Changed title for clarity
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("Lessons Tried",
                    "${_overallStats['attemptedLessonsCount']}"),
                _buildStatItem(
                    "Total Attempts", "${_overallStats['totalAttempts']}"),
                _buildStatItem("Average Score",
                    "${_overallStats['averageScore']}${_overallStats['averageScore'] == "N/A" ? "" : "%"}"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  // --- Placeholder PDF and Notification methods ---
  Future<void> _handleDownloadAndSendAssessment(
      Map<String, dynamic> submission) async {
    if (_currentUser == null) return;
    setState(() {
      _isProcessingPdf = true;
      _processingSubmissionId = submission['id'] as String?;
      _pdfMessage = null;
    });

    _logger.i(
        "Attempting to 'Download & Send' for submission: ${submission['id']}");

    // Simulate PDF generation and sending
    await Future.delayed(const Duration(seconds: 2));

    // Placeholder: Fetch details (in a real scenario, you'd use these for PDF)
    final Map<String, dynamic>? submissionDetails = await _firebaseService
        .getStudentSubmissionDetails(submission['id'] as String);
    final Map<String, dynamic>? assessmentDetails = await _firebaseService
        .getAssessmentDetails(submission['assessmentId'] as String);
    final Map<String, dynamic>? studentProfile =
        await _firebaseService.getUserProfileById(_currentUser!.uid);

    if (submissionDetails == null ||
        assessmentDetails == null ||
        studentProfile == null) {
      _logger.e("Failed to fetch all details for PDF generation and sending.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Error: Could not fetch all report details."),
            backgroundColor: Colors.red));
        setState(() {
          _isProcessingPdf = false;
          _processingSubmissionId = null;
          _pdfMessage = "Error: Could not fetch report details.";
        });
      }
      return;
    }

    String studentNameToDisplay = studentProfile['displayName'] ??
        '${studentProfile['firstName'] ?? ''} ${studentProfile['lastName'] ?? ''}'
            .trim();
    if (studentNameToDisplay.isEmpty) studentNameToDisplay = "Student";

    // Placeholder for trainer notification
    final String? trainerId = assessmentDetails['trainerId'] as String?;
    if (trainerId != null && trainerId.isNotEmpty) {
      await _firebaseService.sendTrainerNotification(
          trainerId,
          studentNameToDisplay, // student name
          assessmentDetails['title'] as String? ?? 'Untitled Assessment',
          submission['id'] as String,
          submission['assessmentId'] as String,
          submissionDetails['classId'] as String?,
          assessmentDetails['className']
              as String? // Assuming className is on assessmentDetails or fetched separately
          );
      _logger.i("Placeholder: Notification sent to trainer $trainerId.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Report 'sent' to trainer (placeholder). PDF generation TBD."),
            backgroundColor: Colors.green));
      }
    } else {
      _logger.w(
          "No trainerId found for assessment ${submission['assessmentId']}, notification not sent.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Report 'downloaded' (placeholder). Trainer not notified (no ID)."),
            backgroundColor: Colors.orange));
      }
    }

    setState(() {
      _isProcessingPdf = false;
      _processingSubmissionId = null;
      _pdfMessage = "Report 'processed' (PDF TBD).";
    });
  }

  Future<void> _handleDownloadFullHistoryPdf() async {
    setState(() {
      _isDownloadingFullHistoryPdf = true;
      _pdfMessage = null;
    });
    _logger.i("Attempting to 'Download Full History'");
    // Simulate PDF generation
    await Future.delayed(const Duration(seconds: 3));

    // In a real app, loop through _assessmentSubmissions, fetch all details, and generate one large PDF.

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Full history 'downloaded' (placeholder). PDF generation TBD."),
          backgroundColor: Colors.blue));
    }
    setState(() {
      _isDownloadingFullHistoryPdf = false;
      _pdfMessage = "Full history 'downloaded' (PDF TBD).";
    });
  }

  @override
  Widget build(BuildContext context) {
    bool noAiProgress = _allUserAttempts.isEmpty;
    bool noTrainerAssessments =
        _assessmentSubmissions.isEmpty && !_isLoadingAssessments;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      // Remove the appBar property
      body: Column(
        children: [
          _buildAppBarWithLogo(), // Add the custom header
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            ElevatedButton(
                              onPressed: _fetchAllReportData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOverallStatsCard(),
                            const SizedBox(height: 16),
                            _buildTrainerAssessmentsSection(),
                            // Add your other sections here as needed
                            // ...existing content...
                          ],
                        ),
                      ),
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

  // --- New Widget for Trainer Assessments History Section ---
  Widget _buildTrainerAssessmentsSection() {
    if (_isLoadingAssessments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_assessmentSubmissions.isEmpty) {
      return Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("Trainer Assessments History",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Icon(Icons.history_edu, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 8),
              const Text("No trainer assessments submitted yet.",
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Trainer Assessments History",
                    style: Theme.of(context).textTheme.titleLarge),
                if (_assessmentSubmissions.isNotEmpty)
                  ElevatedButton.icon(
                    icon: _isDownloadingFullHistoryPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white)))
                        : const Icon(Icons.download_for_offline, size: 18),
                    label: const Text("Full History"),
                    onPressed: _isDownloadingFullHistoryPdf || _isProcessingPdf
                        ? null
                        : _handleDownloadFullHistoryPdf,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _assessmentSubmissions.length,
              itemBuilder: (context, index) {
                final submission = _assessmentSubmissions[index];
                return _buildAssessmentSubmissionItem(submission);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentSubmissionItem(Map<String, dynamic> submission) {
    final submittedAtDate = submission['submittedAt'] as DateTime?;
    final score = (submission['score'] as num?)?.toDouble() ?? 0;
    final totalPossiblePoints =
        (submission['totalPossiblePoints'] as num?)?.toDouble() ?? 0;
    final bool isCurrentlyProcessingItem =
        _isProcessingPdf && _processingSubmissionId == submission['id'];

    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(submission['assessmentTitle'] as String? ?? 'Assessment',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (submission['className'] != null &&
                (submission['className'] as String).isNotEmpty &&
                submission['className'] != 'Class Name Not Found')
              Text("Class: ${submission['className']}",
                  style: Theme.of(context).textTheme.bodySmall),
            if (submission['trainerName'] != null &&
                (submission['trainerName'] as String).isNotEmpty &&
                submission['trainerName'] != 'Trainer Name Not Found')
              Text("Trainer: ${submission['trainerName']}",
                  style: Theme.of(context).textTheme.bodySmall),
            Text(
                "Submitted: ${submittedAtDate != null ? MaterialLocalizations.of(context).formatMediumDate(submittedAtDate) : 'N/A'}",
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "Score: ${score.toStringAsFixed(0)} / ${totalPossiblePoints.toStringAsFixed(0)}",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scoreColor(score,
                              maxScore: totalPossiblePoints > 0
                                  ? totalPossiblePoints
                                  : 100), // Avoid division by zero
                        )),
                Row(
                  children: [
                    TextButton(
                      onPressed: isCurrentlyProcessingItem ||
                              _isDownloadingFullHistoryPdf
                          ? null
                          : () {
                              _logger.i(
                                  "Review Answers for ${submission['id']} clicked. (Placeholder navigation)");
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      "Review for ${submission['assessmentTitle']} (TBD)")));
                              // Example navigation:
                              // Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceholderReviewPage(submissionId: submission['id'])));
                            },
                      child:
                          const Text("Review", style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      icon: isCurrentlyProcessingItem
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)))
                          : const Icon(Icons.send_to_mobile, size: 14),
                      label: Text(isCurrentlyProcessingItem ? "..." : "Send",
                          style: const TextStyle(fontSize: 12)),
                      onPressed: isCurrentlyProcessingItem ||
                              _isDownloadingFullHistoryPdf ||
                              _isProcessingPdf
                          ? null
                          : () => _handleDownloadAndSendAssessment(submission),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ],
        ),
      )
    );
  }

  // ... (Rest of your _ProgressTrackerPageState class: _buildAttemptDetails, _formatScore, _buildRadarChartData etc.)
  // Ensure _buildAttemptDetails and other helper methods are correctly placed within the class
  Widget _buildAttemptDetails(String lessonId, Map<String, dynamic> attempt) {
    final score = (attempt['score'] as num?)?.toDouble() ?? 0.0;
    final timeSpent = attempt['timeSpent'] as int?;
    final attemptTimestamp = attempt['attemptTimestamp'] as DateTime?;
    final detailedResponses =
        attempt['detailedResponses'] as Map<String, dynamic>? ?? {};

    final lessonConfig = _getLessonConfig(lessonId);

    if (lessonConfig == null) {
      _logger.e(
          "CRITICAL: No lessonConfig found for lessonId: $lessonId in _buildAttemptDetails.");
      return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error: Lesson configuration missing for $lessonId.",
              style: const TextStyle(color: Colors.red)));
    }

    final String lessonType = lessonConfig['type'] as String? ?? "GENERIC";
    final List<dynamic> lessonPrompts =
        lessonConfig['prompts'] as List<dynamic>? ??
            (lessonType == "LISTENING_COMP"
                ? lessonConfig['questionLabels'] as List<dynamic>? ?? []
                : []);

    final String? answersKey = lessonConfig['answersKey'] as String?;
    final String? feedbackKey = lessonConfig['feedbackKey'] as String?;
    final String? detailsArrayKey = lessonConfig['detailsArrayKey'] as String?;
    final double maxScorePerItem =
        (lessonConfig['maxScorePerPrompt'] as num?)?.toDouble() ?? 5.0;
    final double overallMaxScore =
        (lessonConfig['maxPossibleAIScore'] as num?)?.toDouble() ?? 100.0;

    List<Widget> detailsWidgets = [
      ListTile(
        dense: true,
        title: Text("Attempt ${attempt['attemptNumber']}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(
            attemptTimestamp != null
                ? "Taken: ${MaterialLocalizations.of(context).formatMediumDate(attemptTimestamp)} at ${TimeOfDay.fromDateTime(attemptTimestamp).format(context)}"
                : "Timestamp N/A",
            style: const TextStyle(fontSize: 12)),
        trailing: _formatScore(score, context, maxScore: overallMaxScore),
      ),
      if (timeSpent != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
              "Time Spent: ${Duration(seconds: timeSpent).toString().split('.').first.padLeft(8, "0")}",
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
        ),
      const Divider(height: 1),
    ];

    if (lessonType == "MCQ" &&
        detailsArrayKey != null &&
        detailedResponses.containsKey(detailsArrayKey)) {
      final List<dynamic> attemptDetailsList =
          detailedResponses[detailsArrayKey] as List<dynamic>? ?? [];
      if (attemptDetailsList.isNotEmpty) {
        detailsWidgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
          child: Text("Question Details:",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ));
        for (var itemData in attemptDetailsList) {
          final itemMap = Map<String, dynamic>.from(itemData as Map);
          detailsWidgets.add(Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 6.0, bottom: 6.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  "Q: ${itemMap['promptText'] ?? 'Question text not recorded'}",
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13)),
              Text("Your Answer: ${itemMap['userAnswer'] ?? 'N/A'}",
                  style: TextStyle(
                      color: itemMap['isCorrect'] == true
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontSize: 13)),
              if (itemMap['isCorrect'] == false)
                Text("Correct Answer: ${itemMap['correctAnswer'] ?? 'N/A'}",
                    style:
                        TextStyle(color: Colors.green.shade800, fontSize: 13)),
            ]),
          ));
        }
      } else {
        detailsWidgets.add(const Padding(
            padding: EdgeInsets.all(16),
            child: Text("No MCQ details found.",
                style: TextStyle(fontStyle: FontStyle.italic))));
      }
    } else if ((lessonType == "SPEAKING_PRACTICE" ||
            lessonType == "BASIC_CALL_SIMULATION") &&
        detailsArrayKey != null &&
        detailedResponses.containsKey(detailsArrayKey)) {
      final List<dynamic> turnDetailsList =
          detailedResponses[detailsArrayKey] as List<dynamic>? ?? [];

      if (turnDetailsList.isNotEmpty) {
        detailsWidgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
          child: Text(
              lessonType == "SPEAKING_PRACTICE"
                  ? "Prompt Review:"
                  : "Turn-by-Turn Review:",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ));
        for (var turnDataMap in turnDetailsList) {
          final turnData = Map<String, dynamic>.from(turnDataMap);
          final String character = turnData['character'] ?? 'Unknown';
          final String originalText = turnData['text'] ?? 'No script.';
          final String? transcription = turnData['transcription'] as String?;
          final Map<String, dynamic>? azureFeedback =
              turnData['azureAiFeedback'] as Map<String, dynamic>?;
          final String? openAiFeedbackHtml =
              turnData['openAiDetailedFeedback'] as String?;

          detailsWidgets.add(Card(
            elevation: 0.5,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$character: \"$originalText\"",
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          color: character == "Customer"
                              ? Colors.blueGrey[700]
                              : Theme.of(context).colorScheme.primary)),
                  if (character.contains("Agent") ||
                      character.contains("Your Turn")) ...[
                    if (transcription != null &&
                        transcription.isNotEmpty &&
                        transcription != "N/A") ...[
                      const SizedBox(height: 6),
                      Text("Your Transcription:",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      Padding(
                          padding: const EdgeInsets.only(top: 2.0, left: 8.0),
                          child: Text(transcription,
                              style: const TextStyle(fontSize: 12))),
                    ],
                    if (azureFeedback != null)
                      _buildAzureMetricsDisplay(azureFeedback, context),
                    if (openAiFeedbackHtml != null &&
                        openAiFeedbackHtml.isNotEmpty)
                      _buildOpenAICoachFeedbackDisplay(
                          openAiFeedbackHtml, context),
                  ]
                ],
              ),
            ),
          ));
        }
      } else {
        detailsWidgets.add(const Padding(
            padding: EdgeInsets.all(16),
            child: Text("No speaking/turn details found.",
                style: TextStyle(fontStyle: FontStyle.italic))));
      }
    } else if ((lessonType == "TEXT_SCENARIO" ||
            lessonType == "TEXT_FILL_IN" ||
            lessonType == "CLARIFICATION_SCENARIO" ||
            lessonType == "PROVIDING_SOLUTIONS" ||
            lessonType == "LISTENING_COMP") &&
        answersKey != null &&
        detailedResponses.containsKey(answersKey) &&
        detailedResponses[answersKey] is Map) {
      final Map<String, dynamic> userAnswers =
          Map<String, dynamic>.from(detailedResponses[answersKey] as Map);
      final Map<String, dynamic>? aiFeedbacks = (feedbackKey != null &&
              detailedResponses.containsKey(feedbackKey) &&
              detailedResponses[feedbackKey] is Map)
          ? Map<String, dynamic>.from(detailedResponses[feedbackKey] as Map)
          : null;

      detailsWidgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
        child: Text("Details & Feedback:",
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ));

      if (lessonPrompts.isEmpty) {
        detailsWidgets.add(const Padding(
            padding: EdgeInsets.all(8),
            child: Text("Prompt configuration missing.",
                style: TextStyle(fontStyle: FontStyle.italic))));
      }

      for (var promptConfig in lessonPrompts) {
        String promptKey;
        String promptTextDisplay;

        if (lessonType == "LISTENING_COMP" && promptConfig is String) {
          promptTextDisplay = promptConfig;
          int qIndex = lessonPrompts.indexOf(promptConfig);
          promptKey = "question_${qIndex + 1}";
        } else if (promptConfig is Map<String, dynamic>) {
          promptKey = promptConfig['name'] ??
              promptConfig['id'] ??
              "prompt_${lessonPrompts.indexOf(promptConfig)}";
          promptTextDisplay = promptConfig['label'] ??
              promptConfig['customerText'] ??
              promptConfig['promptText'] ??
              promptConfig['scenarioText'] ??
              "Question";
        } else {
          continue;
        }

        final String? userAnswer = userAnswers[promptKey] as String?;
        final Map<String, dynamic>? feedbackDataForPrompt =
            aiFeedbacks?[promptKey] as Map<String, dynamic>?;

        detailsWidgets.add(Card(
          elevation: 0.3,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promptTextDisplay,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87)),
                const SizedBox(height: 5),
                Text("Your Answer: ${userAnswer ?? "N/A"}",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[800],
                        fontSize: 13)),
                if (feedbackDataForPrompt != null) ...[
                  const SizedBox(height: 8),
                  ReusableFeedbackCard(
                      feedbackData: feedbackDataForPrompt,
                      maxScore: maxScorePerItem)
                ] else if (userAnswer != null && userAnswer.isNotEmpty) ...[
                  Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text("No specific AI feedback recorded.",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic))),
                ]
              ],
            ),
          ),
        ));
      }
    } else {
      final logMessage =
          "Details for $lessonId (type: $lessonType) - AnsKey: $answersKey, FbKey: $feedbackKey, DetArrKey: $detailsArrayKey, Prompts: ${lessonPrompts.length}, DR Keys: ${detailedResponses.keys}";
      detailsWidgets.add(Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
              "Config/Data Mismatch. Check logs. $logMessage", // Added logMessage for debugging in UI
              style: const TextStyle(
                  fontStyle: FontStyle.italic, color: Colors.redAccent))));
      _logger.w(logMessage);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
      child: Card(
        elevation: 0.5,
        color: Colors.grey[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: detailsWidgets),
        ),
      ),
    );
  }

  Widget _formatScore(double? score, BuildContext context,
      {double maxScore = 100.0}) {
    if (score == null) {
      return Text("N/A", style: TextStyle(color: Colors.grey[600]));
    }
    final percentage =
        maxScore > 0 ? (score / maxScore) * 100 : 0.0; // Avoid division by zero
    Color scoreColorVal = scoreColor(score,
        maxScore: maxScore); // Use the global scoreColor function

    return Text(
      "${score.toStringAsFixed(1)}%", // Assuming score is already a percentage or needs to be displayed as such
      style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: scoreColorVal),
    );
  }

  List<RadarDataSet> _buildRadarChartData(List<dynamic> turnDetailsList) {
    if (turnDetailsList.isEmpty) return [];

    Map<String, double> totalMetrics = {
      'accuracyScore': 0,
      'fluencyScore': 0,
      'completenessScore': 0,
      'prosodyScore': 0
    };
    int agentTurnCount = 0;

    for (var turnDataMap in turnDetailsList) {
      final turnData = Map<String, dynamic>.from(turnDataMap);
      final String character = turnData['character'] ?? 'Unknown';
      final Map<String, dynamic>? azureFeedback =
          turnData['azureAiFeedback'] as Map<String, dynamic>?;

      if ((character.contains("Agent") || character.contains("Your Turn")) &&
          azureFeedback != null) {
        totalMetrics['accuracyScore'] = totalMetrics['accuracyScore']! +
            ((azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0.0);
        totalMetrics['fluencyScore'] = totalMetrics['fluencyScore']! +
            ((azureFeedback['fluencyScore'] as num?)?.toDouble() ?? 0.0);
        totalMetrics['completenessScore'] = totalMetrics['completenessScore']! +
            ((azureFeedback['completenessScore'] as num?)?.toDouble() ?? 0.0);
        totalMetrics['prosodyScore'] = totalMetrics['prosodyScore']! +
            ((azureFeedback['prosodyScore'] as num?)?.toDouble() ?? 0.0);
        agentTurnCount++;
      }
    }

    if (agentTurnCount == 0) return [];

    return [
      RadarDataSet(
        fillColor: Colors.blue.withOpacity(0.3),
        borderColor: Colors.blue,
        entryRadius: 3,
        dataEntries: [
          RadarEntry(value: totalMetrics['accuracyScore']! / agentTurnCount),
          RadarEntry(value: totalMetrics['fluencyScore']! / agentTurnCount),
          RadarEntry(
              value: totalMetrics['completenessScore']! / agentTurnCount),
          RadarEntry(value: totalMetrics['prosodyScore']! / agentTurnCount),
        ],
        borderWidth: 2,
      ),
    ];
  }
}

// Global helper widgets (outside the _ProgressTrackerPageState class)
Widget _buildAzureMetricsDisplay(
    Map<String, dynamic> azureFeedback, BuildContext context) {
  if (azureFeedback.isEmpty) return const SizedBox.shrink();

  List<Widget> metrics = [];
  final labelStyle = TextStyle(color: Colors.grey[700], fontSize: 12);

  if (azureFeedback['accuracyScore'] != null) {
    metrics.add(Text(
        'Accuracy: ${(azureFeedback['accuracyScore'] as num?)?.toStringAsFixed(1) ?? "N/A"}%',
        style: labelStyle.copyWith(color: scoreColor(// Uses global scoreColor
            (azureFeedback['accuracyScore'] as num?)?.toDouble() ?? 0))));
  }
  if (azureFeedback['fluencyScore'] != null) {
    metrics.add(Text(
        'Fluency: ${(azureFeedback['fluencyScore'] as num?)?.toStringAsFixed(1) ?? "N/A"}',
        style: labelStyle.copyWith(
            color: scoreColor(
                (azureFeedback['fluencyScore'] as num?)?.toDouble() ?? 0))));
  }
  // ... (add completeness and prosody similarly)

  if (metrics.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 4.0, left: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Azure AI Metrics:",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurpleAccent,
                fontSize: 11)),
        ...metrics,
      ],
    ),
  );
}

Widget _buildOpenAICoachFeedbackDisplay(
    String htmlFeedback, BuildContext context) {
  if (htmlFeedback.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 8.0, left: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("AI Coach's Playbook:",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 11)),
        Html(data: htmlFeedback, style: {
          "body": Style(
              fontSize: FontSize(11.0), // Smaller font for mobile
              margin: Margins.all(0),
              padding: HtmlPaddings.all(0))
        }),
      ],
    ),
  );
}

Color scoreColor(double score, {double maxScore = 100.0}) {
  final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;
  if (percentage >= 90) return Colors.green.shade700;
  if (percentage >= 75) return Colors.lime.shade700;
  if (percentage >= 60) return Colors.yellow.shade800;
  if (percentage >= 40) return Colors.orange.shade700;
  return Colors.red.shade700;
}

class ReusableFeedbackCard extends StatelessWidget {
  final Map<String, dynamic> feedbackData;
  final String? titlePrefix;
  final double maxScore;

  const ReusableFeedbackCard({
    super.key,
    required this.feedbackData,
    this.titlePrefix,
    this.maxScore = 5.0,
  });

  List<Widget> _parseAndDisplayFeedbackText(
      String rawText, BuildContext context) {
    final List<Widget> widgets = [];
    final lines =
        rawText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    for (String line in lines) {
      if (line.startsWith("**") && line.contains(":**")) {
        widgets.add(Text(
          line.replaceAll("**", "").replaceAll(":", ":"),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold, fontSize: 12), // Smaller font
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 4.0),
          child: Html(data: line, style: {
            "body": Style(
                margin: Margins.zero,
                fontSize: FontSize(11.0), // Smaller font
                padding: HtmlPaddings.zero)
          }),
        ));
      }
    }
    return widgets.isNotEmpty
        ? widgets
        : [
            Html(data: rawText, style: {
              "body": Style(
                  margin: Margins.zero,
                  fontSize: FontSize(11.0), // Smaller font
                  padding: HtmlPaddings.zero)
            })
          ];
  }

  @override
  Widget build(BuildContext context) {
    final scoreNum = (feedbackData['score'] as num?)?.toDouble();
    final text =
        feedbackData['text'] as String? ?? "No detailed feedback provided.";

    String scoreLabel = "N/A";
    Color currentScoreColor = Colors.grey;

    if (scoreNum != null) {
      scoreLabel =
          "${scoreNum.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}";
      currentScoreColor =
          scoreColor(scoreNum, maxScore: maxScore); // Global scoreColor
    }

    return Container(
      margin: const EdgeInsets.only(top: 6.0),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scoreNum != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("AI Score: $scoreLabel",
                    style: TextStyle(
                        color: currentScoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          if (scoreNum != null) ...[
            const SizedBox(height: 3),
            LinearProgressIndicator(
              value: maxScore > 0 ? scoreNum / maxScore : 0,
              minHeight: 4,
              backgroundColor: currentScoreColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 6),
          ],
          ..._parseAndDisplayFeedbackText(text, context),
        ],
      ),
    );
  }
}
