import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import '../homepage.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import '../courses_page.dart';
import '../journal/journal_page.dart';
import 'landingpage.dart';
import 'loginpage.dart';
import 'welcome_page.dart';
import 'signup_page.dart';
import 'splash_screen.dart';
import 'forgotpass.dart';
import 'package:logger/logger.dart';
import 'Teachers/TrainerDashboard.dart';
import 'chooseUserType.dart';
import 'onboarding_screen.dart';
import 'all_notifications_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import '../session/session_aware_widget.dart'; // Add this import

//For Courses Page
import '../lessons/lesson_activity_log_page.dart';

import '../assessment/module_assessment_page.dart';

import '../../modules/module1.dart';
import '../lessons/lesson1_1.dart';
import '../lessons/lesson1_1_activity_page.dart';
import '../lessons/lesson1_2.dart';
import '../lessons/lesson1_2_activity_page.dart';
import '../lessons/lesson1_3.dart';
import '../lessons/lesson1_3_activity_page.dart';

import '../modules/module2.dart';
import '../lessons/lesson2_1.dart';
import '../lessons/lesson2_1_activity_page.dart';
import '../lessons/lesson2_2.dart';
import '../lessons/lesson2_2_activity_page.dart';
import '../lessons/lesson2_3.dart';
import '../lessons/lesson2_3_activity_page.dart';

import '../modules/module3.dart';
import '../lessons/lesson3_1.dart';
import '../lessons/lesson3_1_activity_page.dart';
import '../lessons/lesson3_2.dart';
import '../lessons/lesson3_2_activity_page.dart';

import '../modules/module4.dart';
import '../lessons/lesson4_1.dart';
import '../lessons/lesson4_1_activity_page.dart';
import '../lessons/lesson4_2.dart';
import '../lessons/lesson4_2_activity_page.dart';

import '../modules/module5.dart';
import '../lessons/lesson5_1.dart';
import '../lessons/lesson5_1_activity_page.dart';
import '../lessons/lesson5_2.dart';
import '../lessons/lesson5_2_activity_page.dart';

// Add these imports after your existing lesson imports:
import '../modules/module6.dart';
import '../lessons/lesson6/lesson6_activity_log_page.dart';
import '../lessons/lesson6/lesson6_landing_page.dart';
import '../lessons/lesson6/lesson6_simulation_page.dart';

import '../certificates/certificate_claim_page.dart';
import '../certificates/certificate_view_page.dart';

// Add this import for MyEnrolledClasses
import '../MyEnrolledClasses.dart';

// Assessment Page Imports
import '../Teachers/Assessment/ClassAssessmentsListPage.dart';
import '../Teachers/Assessment/CreateAssessmentPage.dart';
import '../Teachers/Assessment/ViewAssessmentResultsPage.dart';
import '../Teachers/Assessment/ReviewSpeakingSubmission.dart';

// ClassManager Page Imports
import '../Teachers/ClassManager/CreateClassForm.dart';
import '../Teachers/ClassManager/MyClassesPage.dart';
import '../Teachers/ClassManager/EditClassPage.dart';
import '../Teachers/ClassManager/ManageClassStudents.dart';
import '../Teachers/ClassManager/ManageClassContent.dart';
import '../Teachers/Assessment/EditAssessmentPage.dart';

// Reports Page Import
import '../Teachers/Reports/TrainerReports.dart';

// Announcement Page Import
import '../Teachers/Announcement/CreateAnnouncementPage.dart';

// Content Page Imports
import '../Teachers/Contents/QuickUploadMaterialPage.dart';
import '../Teachers/Contents/SelectClassForContentPage.dart';

// Add this import if not already present
import '../progress_page.dart';
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

      '/enrolled-classes': (context) => const MyEnrolledClasses(),
      '/progress': (context) => const ProgressTrackerPage(),
      '/trainer-dashboard': (context) => const TrainerDashboard(),
      '/chooseUserType': (context) => const ChooseUserTypePage(),
      '/notifications': (context) => const AllNotificationsPage(),
      '/trainer/classes': (context) => const MyClassesPage(),
      '/trainer/classes/create': (context) => const CreateClassForm(),
      '/trainer/reports': (context) => const TrainerReportsPage(),
      '/trainer/announcements/create': (context) => const CreateAnnouncementPage(),
      '/trainer/content/upload': (context) => const QuickUploadMaterialPage(),
      '/trainer/content/select-class': (context) => const SelectClassForContentPage(),
    };

    // Define public routes that don't need session management
    final List<String> publicRoutes = [
      '/splash',
      '/',
      '/login',
      '/forgot-password',
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TalkReady',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        final args = settings.arguments;
        final String? routeName = settings.name;

        // Handle static routes with session management
        if (routeName != null && staticRoutes.containsKey(routeName)) {
          final WidgetBuilder? builder = staticRoutes[routeName];
          if (builder != null) {
            // Check if route is public or requires authentication
            if (publicRoutes.contains(routeName)) {
              // Public route - no session management
              return MaterialPageRoute(builder: builder, settings: settings);
            } else {
              // Protected route - wrap with SessionAwareWidget
              return MaterialPageRoute(
                builder: (context) => SessionAwareWidget(child: builder(context)),
                settings: settings,
              );
            }
          }
        }

        if (routeName != null) {
          final uri = Uri.parse(routeName);
          final segments = uri.pathSegments;

          // Class Assessments List: /class/<classId>/assessments
          if (segments.length == 3 &&
              segments[0] == 'class' &&
              segments[2] == 'assessments') {
            final classId = segments[1];
            return MaterialPageRoute(
              builder: (_) => SessionAwareWidget(
                child: ClassAssessmentsListPage(classId: classId),
              ),
              settings: settings,
            );
          }

          // View Assessment Results: /assessment/<assessmentId>/results
          if (segments.length == 3 &&
              segments[0] == 'assessment' &&
              segments[2] == 'results') {
            final assessmentId = segments[1];
            return MaterialPageRoute(
              builder: (_) => SessionAwareWidget(
                child: ViewAssessmentResultsPage(assessmentId: assessmentId),
              ),
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
              builder: (_) => SessionAwareWidget(
                child: EditAssessmentPage(assessmentId: assessmentId),
              ),
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
              builder: (_) => SessionAwareWidget(
                child: EditClassPage(classId: classId),
              ),
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
              builder: (_) => SessionAwareWidget(
                child: ManageClassStudentsPage(classId: classId),
              ),
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
              builder: (_) => SessionAwareWidget(
                child: ManageClassContentPage(classId: classId),
              ),
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
              builder: (_) => SessionAwareWidget(
                child: ReviewSpeakingSubmissionPage(submissionId: submissionId),
              ),
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
              builder: (_) => SessionAwareWidget(
                child: OnboardingScreen(
                  userType: onboardingArgs?['userType'] as String?,
                ),
              ),
              settings: settings,
            );

          //courses
          case '/lesson_activity_log':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: LessonActivityLogPage(
                    lessonId: args['lessonId'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    activityLog:
                        args['activityLog'] as List<Map<String, dynamic>>,
                  ),
                ),
              );
            }
            break;

          case '/lesson1_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson1_1ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                  ),
                ),
              );
            }
            break;
          case '/lesson1_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson1_2ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                  ),
                ),
              );
            }
            break;

          case '/lesson1_3_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson1_3ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                  ),
                ),
              );
            }
            break;

          case '/lesson2_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson2_1ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson2_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson2_2ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson2_3_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson2_3ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson3_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson3_1ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson3_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson3_2ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson4_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson4_1ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson4_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson4_2ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson5_1_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson5_1ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson5_2_activity':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('lessonData')) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: Lesson5_2ActivityPage(
                    lessonId: args['lessonId'] as String,
                    lessonTitle: args['lessonTitle'] as String,
                    lessonData: args['lessonData'] as Map<String, dynamic>,
                    attemptNumber: args['attemptNumber'] as int,
                  ),
                ),
              );
            }
            break;

          case '/lesson6_simulation':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => const SessionAwareWidget(
                child: Lesson6SimulationPage(),
              ),
              settings: settings,
            );

          case '/lesson6_activity_log':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => const SessionAwareWidget(
                child: Lesson6ActivityLogPage(),
              ),
              settings: settings,
            );

          case '/certificate/view':
            final certificateData = args as Map<String, dynamic>?;
            if (certificateData != null) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: CertificateViewPage(certificateData: certificateData),
                ),
                settings: settings,
              );
            }
            break;

          case '/assessment':
            final assessmentId = settings.arguments as String?;
            if (assessmentId != null) {
              return MaterialPageRoute(
                builder: (_) => SessionAwareWidget(
                  child: ModuleAssessmentPage(assessmentId: assessmentId),
                ),
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
              builder: (_) => SessionAwareWidget(
                child: CreateAssessmentPage(initialClassId: classId),
              ),
              settings: settings,
            );
          default:
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
        return null;
      },
    );
  }
}