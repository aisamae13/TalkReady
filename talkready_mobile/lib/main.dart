import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:talkready_mobile/homepage.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:talkready_mobile/courses_page.dart';
import 'package:talkready_mobile/journal/journal_page.dart';
import 'landingpage.dart';
import 'loginpage.dart';
import 'welcome_page.dart';
import 'signup_page.dart';
import 'splash_screen.dart';
import 'forgotpass.dart';
import 'package:logger/logger.dart';
import 'package:talkready_mobile/Teachers/TrainerDashboard.dart';
import 'package:talkready_mobile/chooseUserType.dart';
import 'onboarding_screen.dart';
import 'package:talkready_mobile/all_notifications_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart'; // add if missing

//For Courses Page
import 'package:talkready_mobile/lessons/lesson_activity_log_page.dart';

import 'services/unified_progress_service.dart';
import 'custom_animated_bottom_bar.dart';
import 'package:talkready_mobile/assessment/module_assessment_page.dart';

import 'package:talkready_mobile/modules/module1.dart';
import 'package:talkready_mobile/lessons/lesson1_1.dart';
import 'package:talkready_mobile/lessons/lesson1_1_activity_page.dart';
import 'package:talkready_mobile/lessons/lesson1_2.dart';
import 'package:talkready_mobile/lessons/lesson1_2_activity_page.dart';
import 'package:talkready_mobile/lessons/lesson1_3.dart';
import 'package:talkready_mobile/lessons/lesson1_3_activity_page.dart';

import 'package:talkready_mobile/modules/module2.dart';
import 'package:talkready_mobile/lessons/lesson2_1.dart';
import 'package:talkready_mobile/lessons/lesson2_1_activity_page.dart';
import 'package:talkready_mobile/lessons/lesson2_2.dart';
import 'package:talkready_mobile/lessons/lesson2_2_activity_page.dart';
import 'package:talkready_mobile/lessons/lesson2_3.dart';
import 'package:talkready_mobile/lessons/lesson2_3_activity_page.dart';

import 'package:talkready_mobile/modules/module3.dart';
import 'package:talkready_mobile/lessons/lesson3_1.dart';
import 'package:talkready_mobile/lessons/lesson3_1_activity_page.dart';
import 'package:talkready_mobile/lessons/lesson3_2.dart';
import 'package:talkready_mobile/lessons/lesson3_2_activity_page.dart';

import 'package:talkready_mobile/modules/module4.dart';
import 'package:talkready_mobile/lessons/lesson4_1.dart';
import 'package:talkready_mobile/lessons/lesson4_1_activity_page.dart';
import 'package:talkready_mobile/lessons/lesson4_2.dart';
import 'package:talkready_mobile/lessons/lesson4_2_activity_page.dart';

import 'package:talkready_mobile/modules/module5.dart';
import 'package:talkready_mobile/lessons/lesson5_1.dart';
import 'package:talkready_mobile/lessons/lesson5_1_activity_page.dart';
import 'package:talkready_mobile/lessons/lesson5_2.dart';
import 'package:talkready_mobile/lessons/lesson5_2_activity_page.dart';

// Add these imports after your existing lesson imports:
import 'package:talkready_mobile/modules/module6.dart';
import 'package:talkready_mobile/lessons/lesson6/lesson6_activity_log_page.dart';
import 'package:talkready_mobile/lessons/lesson6/lesson6_landing_page.dart';
import 'package:talkready_mobile/lessons/lesson6/lesson6_simulation_page.dart';

import 'package:talkready_mobile/certificates/certificate_claim_page.dart';
import 'package:talkready_mobile/certificates/certificate_view_page.dart';

// Add this import for MyEnrolledClasses
import 'package:talkready_mobile/MyEnrolledClasses.dart';

// Assessment Page Imports
import 'package:talkready_mobile/Teachers/Assessment/ClassAssessmentsListPage.dart';
import 'package:talkready_mobile/Teachers/Assessment/CreateAssessmentPage.dart';
import 'package:talkready_mobile/Teachers/Assessment/ViewAssessmentResultsPage.dart';
import 'package:talkready_mobile/Teachers/Assessment/ReviewSpeakingSubmission.dart';

// ClassManager Page Imports
import 'package:talkready_mobile/Teachers/ClassManager/CreateClassForm.dart';
import 'package:talkready_mobile/Teachers/ClassManager/MyClassesPage.dart';
import 'package:talkready_mobile/Teachers/ClassManager/EditClassPage.dart';
import 'package:talkready_mobile/Teachers/ClassManager/ManageClassStudents.dart';
import 'package:talkready_mobile/Teachers/ClassManager/ManageClassContent.dart';
import 'package:talkready_mobile/Teachers/Assessment/EditAssessmentPage.dart';

// Reports Page Import
import 'package:talkready_mobile/Teachers/Reports/TrainerReports.dart';

// Announcement Page Import
import 'package:talkready_mobile/Teachers/Announcement/CreateAnnouncementPage.dart';

// Content Page Imports
import 'package:talkready_mobile/Teachers/Contents/QuickUploadMaterialPage.dart';
import 'package:talkready_mobile/Teachers/Contents/SelectClassForContentPage.dart';

// Add this import if not already present
import 'package:talkready_mobile/progress_page.dart';
import 'profile.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configure Firestore settings for better performance
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // start auth listener once so FirebaseService manages realtime sync automatically
  FirebaseService().initAuthListener();

  try {} catch (e) {
    logger.e('Failed to load .env file: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, WidgetBuilder> staticRoutes = {
      '/splash': (context) => const SplashScreen(),
      '/': (context) => const LandingPage(),
      '/login': (context) => LoginPage(),
      '/welcome': (context) => const WelcomePage(),
      '/homepage': (context) => const HomePage(),
      '/forgot-password': (context) => const ForgotPasswordPage(),
      '/courses': (context) => CoursesPage(),
      '/journal': (context) => JournalPage(),
      '/profile': (context) => const ProfilePage(),

      //Courses
      '/module1': (context) => const Module1Page(),
      '/lesson1_1': (context) => const Lesson1_1Page(),
      '/lesson1_2': (context) => const Lesson1_2Page(),
      '/lesson1_3': (context) => const Lesson1_3Page(),

      '/module2': (context) => const Module2Page(),
      '/lesson2_1': (context) => const Lesson2_1Page(),
      '/lesson2_2': (context) => const Lesson2_2Page(),
      '/lesson2_3': (context) => const Lesson2_3Page(),

      '/module3': (context) => const Module3Page(),
      '/lesson3_1': (context) => const Lesson3_1Page(),
      '/lesson3_2': (context) => const Lesson3_2Page(),

      '/module4': (context) => const Module4Page(),
      '/lesson4_1': (context) => const Lesson4_1Page(),
      '/lesson4_2': (context) => const Lesson4_2Page(),

      '/module5': (context) => const Module5Page(),
      '/lesson5_1': (context) => const Lesson5_1Page(
        lessonId: 'Lesson-5-1',
        lessonTitle: 'Lesson 5.1: Basic Simulation - Info Request',
        lessonData: {},
        attemptNumber: 1,
      ),
      '/lesson5_2': (context) => const Lesson5_2Page(),

      '/module6': (context) => const Module6Page(),
      '/lesson6_simulation': (context) => const Lesson6SimulationPage(),
      '/lesson6_activity_log': (context) => const Lesson6ActivityLogPage(),

      '/certificate': (context) => const CertificateClaimPage(),

      // Add individual lesson routes
      '/enrolled-classes': (context) =>
          const MyEnrolledClasses(), // Add this line
      '/progress': (context) =>
          const ProgressTrackerPage(), // Add this if not present
      '/trainer-dashboard': (context) => const TrainerDashboard(),
      '/chooseUserType': (context) => const ChooseUserTypePage(),
      '/notifications': (context) => const AllNotificationsPage(),
      // ClassManager static routes
      '/trainer/classes': (context) => const MyClassesPage(),
      '/trainer/classes/create': (context) => const CreateClassForm(),
      // Reports static routes
      '/trainer/reports': (context) => const TrainerReportsPage(),
      // Announcement static routes
      '/trainer/announcements/create': (context) =>
          const CreateAnnouncementPage(),
      // Content static routes
      '/trainer/content/upload': (context) => const QuickUploadMaterialPage(),
      '/trainer/content/select-class': (context) =>
          const SelectClassForContentPage(),
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TalkReady',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/splash',
      routes: staticRoutes,
      onGenerateRoute: (settings) {
        final args = settings.arguments;
        final String? routeName = settings.name;

        if (routeName != null) {
          final uri = Uri.parse(routeName);
          final segments = uri.pathSegments;

          // Class Assessments List: /class/<classId>/assessments
          if (segments.length == 3 &&
              segments[0] == 'class' &&
              segments[2] == 'assessments') {
            final classId = segments[1];
            return MaterialPageRoute(
              builder: (_) => ClassAssessmentsListPage(classId: classId),
              settings: settings,
            );
          }

          // View Assessment Results: /assessment/<assessmentId>/results
          if (segments.length == 3 &&
              segments[0] == 'assessment' &&
              segments[2] == 'results') {
            final assessmentId = segments[1];
            return MaterialPageRoute(
              builder: (_) =>
                  ViewAssessmentResultsPage(assessmentId: assessmentId),
              settings: settings,
            );
          }

          // Edit Assessment Page: /trainer/assessments/<assessmentId>/edit
          if (segments.length == 4 &&
              segments[0] == 'trainer' &&
              segments[1] == 'assessments' &&
              segments[3] == 'edit') {
            final assessmentId = segments[2];
            return MaterialPageRoute(
              builder: (_) => EditAssessmentPage(assessmentId: assessmentId),
              settings: settings,
            );
          }

          // Edit Class Page: /trainer/classes/<classId>/edit
          if (segments.length == 4 &&
              segments[0] == 'trainer' &&
              segments[1] == 'classes' &&
              segments[3] == 'edit') {
            final classId = segments[2];
            return MaterialPageRoute(
              builder: (_) => EditClassPage(classId: classId),
              settings: settings,
            );
          }
          // Manage Class Students Page: /trainer/classes/<classId>/students
          if (segments.length == 4 &&
              segments[0] == 'trainer' &&
              segments[1] == 'classes' &&
              segments[3] == 'students') {
            final classId = segments[2];
            return MaterialPageRoute(
              builder: (_) => ManageClassStudentsPage(classId: classId),
              settings: settings,
            );
          }
          // Manage Class Content Page: /trainer/classes/<classId>/content
          if (segments.length == 4 &&
              segments[0] == 'trainer' &&
              segments[1] == 'classes' &&
              segments[3] == 'content') {
            final classId = segments[2];
            return MaterialPageRoute(
              builder: (_) => ManageClassContentPage(classId: classId),
              settings: settings,
            );
          }
          // Review Speaking Submission: /submissions/speaking/<submissionId>/review
          if (segments.length == 4 &&
              segments[0] == 'submissions' &&
              segments[1] == 'speaking' &&
              segments[3] == 'review') {
            final submissionId = segments[2];
            return MaterialPageRoute(
              builder: (_) =>
                  ReviewSpeakingSubmissionPage(submissionId: submissionId),
              settings: settings,
            );
          }
        }

        switch (routeName) {
          case '/signup':
            final userTypeArgs = args as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) =>
                  SignUpPage(userType: userTypeArgs?['userType'] as String?),
              settings: settings,
            );
          case '/onboarding':
            final onboardingArgs = args as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => OnboardingScreen(
                userType: onboardingArgs?['userType'] as String?,
              ),
              settings: settings,
            );

          //courses
          case '/lesson_activity_log':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (_) => LessonActivityLogPage(
                  lessonId: args['lessonId'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  activityLog:
                      args['activityLog'] as List<Map<String, dynamic>>,
                ),
              );
            }
            break;

          case '/lesson1_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              // Check for the new argument
              return MaterialPageRoute(
                builder: (_) => Lesson1_1ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData:
                      args['lessonData']
                          as Map<String, dynamic>, // Pass the data
                ),
              );
            }
            break;
          case '/lesson1_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson1_2ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                ),
              );
            }
            break;

          case '/lesson1_3_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson1_3ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                ),
              );
            }
            break;

          case '/lesson2_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson2_1ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  // Receive and pass the attemptNumber
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson2_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson2_2ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson2_3_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson2_3ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson3_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson3_1ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson3_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson3_2ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson4_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson4_1ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson4_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson4_2ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson5_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson5_1ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson5_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => Lesson5_2ActivityPage(
                  lessonId: args['lessonId'] as String,
                  lessonTitle: args['lessonTitle'] as String,
                  lessonData: args['lessonData'] as Map<String, dynamic>,
                  attemptNumber: args['attemptNumber'] as int,
                ),
              );
            }
            break;

          case '/lesson6_simulation':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => const Lesson6SimulationPage(),
              settings: settings,
            );

          case '/lesson6_activity_log':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => const Lesson6ActivityLogPage(),
              settings: settings,
            );

          case '/certificate/view':
            final certificateData = args as Map<String, dynamic>?;
            if (certificateData != null) {
              return MaterialPageRoute(
                builder: (_) =>
                    CertificateViewPage(certificateData: certificateData),
                settings: settings,
              );
            }
            break;

          case '/assessment':
            final assessmentId = settings.arguments as String?;
            if (assessmentId != null) {
              return MaterialPageRoute(
                builder: (_) =>
                    ModuleAssessmentPage(assessmentId: assessmentId),
              );
            }
            break;

          case '/create-assessment':
            final classId =
                (args is Map<String, dynamic>
                    ? args['initialClassId'] as String?
                    : null) ??
                (args is String ? args : null);
            return MaterialPageRoute(
              builder: (_) => CreateAssessmentPage(initialClassId: classId),
              settings: settings,
            );
          default:
            if (routeName != null && staticRoutes.containsKey(routeName)) {
              final WidgetBuilder? builder = staticRoutes[routeName];
              if (builder != null) {
                return MaterialPageRoute(builder: builder, settings: settings);
              }
            }
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(
                  child: Text(
                    'No route defined for $routeName or arguments mismatch.',
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}