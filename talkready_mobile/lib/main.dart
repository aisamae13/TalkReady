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
import 'package:talkready_mobile/TrainerDashboard.dart'; // <-- Add this import
import 'package:talkready_mobile/chooseUserType.dart'; 
import 'onboarding_screen.dart';



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

  // Initialize Firebase App Check with the debug provider
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // Load the .env file
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
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LandingPage(),
        '/login': (context) => LoginPage(),
        '/welcome': (context) => const WelcomePage(),
        '/homepage': (context) => const HomePage(),
        '/signup': (context) => const SignUpPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/courses': (context) => CoursesPage(),
        '/journal': (context) => JournalPage(),
        '/trainer-dashboard': (context) => const TrainerDashboard(), // <-- Add this route
        '/chooseUserType': (context) => const ChooseUserTypePage(),
            '/onboarding': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return OnboardingScreen(userType: args?['userType']);
        },
      },
    );
  }
}