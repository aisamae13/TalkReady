import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:talkready_mobile/ProgramsPage.dart';
import 'package:talkready_mobile/homepage.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:talkready_mobile/courses_page.dart';
import 'package:talkready_mobile/ProgramsPage.dart';
import 'package:talkready_mobile/journal_page.dart';
import 'landingpage.dart';
import 'loginpage.dart';
import 'welcome_page.dart';
import 'signup_page.dart';
import 'forgotpass.dart';


void main() async {
  // Ensure widgets are initialized for async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check with the debug provider
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // Load the .env file silently (no UI error if missing)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Optionally, handle the error (e.g., throw or log), but proceed without .env for now
    // This allows the app to run, but API calls will fail if keys are missing
  }

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TalkReady',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/login': (context) => LoginPage(),
        '/welcome': (context) => const WelcomePage(),
        '/homepage': (context) => const HomePage(),
        '/signup': (context) => const SignUpPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/courses': (context) => const CoursesPage(),
        '/journal': (context) => const ProgressTrackerPage(),
        '/programs': (context) => ProgramsPage()

      },
    );
  }
}
