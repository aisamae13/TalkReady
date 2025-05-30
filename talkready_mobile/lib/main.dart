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

// Assessment Page Imports
import 'package:talkready_mobile/Teachers/Assessment/ClassAssessmentsListPage.dart';
import 'package:talkready_mobile/Teachers/Assessment/CreateAssessmentPage.dart';
import 'package:talkready_mobile/Teachers/Assessment/ViewAssessmentResultsPage.dart';

// ClassManager Page Imports
import 'package:talkready_mobile/Teachers/ClassManager/CreateClassForm.dart';
import 'package:talkready_mobile/Teachers/ClassManager/MyClassesPage.dart';
import 'package:talkready_mobile/Teachers/ClassManager/EditClassPage.dart';
import 'package:talkready_mobile/Teachers/ClassManager/ManageClassStudents.dart';
import 'package:talkready_mobile/Teachers/ClassManager/ManageClassContent.dart';
import 'package:talkready_mobile/Teachers/ClassManager/EditAssessmentPage.dart'; // Assuming this is the correct location

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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug, // Add this for iOS debug
  );

  try {
    await dotenv.load(fileName: ".env");
    logger.i('Successfully loaded .env file');
    if (dotenv.env['OPENAI_API_KEY'] == null || dotenv.env['OPENAI_API_KEY']!.isEmpty) {
      logger.e('OPENAI_API_KEY is missing or empty in .env file');
    } else {
      logger.i('OPENAI_API_KEY loaded successfully');
    }
  } catch (e) {
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
      '/trainer-dashboard': (context) => const TrainerDashboard(),
      '/chooseUserType': (context) => const ChooseUserTypePage(),
      '/notifications': (context) => const AllNotificationsPage(),
      // ClassManager static routes
      '/trainer/classes': (context) => const MyClassesPage(),
      '/trainer/classes/create': (context) => const CreateClassForm(),
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
          if (segments.length == 3 && segments[0] == 'class' && segments[2] == 'assessments') {
            final classId = segments[1];
            return MaterialPageRoute(
              builder: (_) => ClassAssessmentsListPage(classId: classId),
              settings: settings,
            );
          }

          // View Assessment Results: /assessment/<assessmentId>/results
          if (segments.length == 3 && segments[0] == 'assessment' && segments[2] == 'results') {
            final assessmentId = segments[1];
            return MaterialPageRoute(
              builder: (_) => ViewAssessmentResultsPage(assessmentId: assessmentId),
              settings: settings,
            );
          }

          // Edit Assessment Page: /trainer/assessments/<assessmentId>/edit
          if (segments.length == 4 && segments[0] == 'trainer' && segments[1] == 'assessments' && segments[3] == 'edit') {
            final assessmentId = segments[2];
            return MaterialPageRoute(
              builder: (_) => EditAssessmentPage(assessmentId: assessmentId),
              settings: settings,
            );
          }

          // Edit Class Page: /trainer/classes/<classId>/edit
          if (segments.length == 4 && segments[0] == 'trainer' && segments[1] == 'classes' && segments[3] == 'edit') {
            final classId = segments[2];
            return MaterialPageRoute(
              builder: (_) => EditClassPage(classId: classId),
              settings: settings,
            );
          }
          // Manage Class Students Page: /trainer/classes/<classId>/students
          if (segments.length == 4 && segments[0] == 'trainer' && segments[1] == 'classes' && segments[3] == 'students') {
            final classId = segments[2];
            return MaterialPageRoute(
              builder: (_) => ManageClassStudentsPage(classId: classId),
              settings: settings,
            );
          }
          // Manage Class Content Page: /trainer/classes/<classId>/content
          if (segments.length == 4 && segments[0] == 'trainer' && segments[1] == 'classes' && segments[3] == 'content') {
            final classId = segments[2];
            return MaterialPageRoute(
              builder: (_) => ManageClassContentPage(classId: classId),
              settings: settings,
            );
          }
        }

        switch (routeName) {
          case '/signup':
            final userTypeArgs = args as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => SignUpPage(userType: userTypeArgs?['userType'] as String?),
              settings: settings,
            );
          case '/onboarding':
            final onboardingArgs = args as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => OnboardingScreen(userType: onboardingArgs?['userType'] as String?),
              settings: settings,
            );
          case '/create-assessment':
            // Ensure classId is passed as a String?
            final classId = (args is Map<String, dynamic> ? args['initialClassId'] as String? : null) ?? (args is String ? args : null);
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
                  child: Text('No route defined for $routeName or arguments mismatch.'),
                ),
              ),
            );
        }
      },
    );
  }
}