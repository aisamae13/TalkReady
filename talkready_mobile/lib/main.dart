import 'package:flutter/material.dart';
import 'landingpage.dart';
import 'loginpage.dart';
import 'welcome_page.dart';
import 'signup_page.dart';
import 'forgotpass.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// Ensure you generate this file using Firebase CLI


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkReady',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
          '/': (context) => const LandingPage(),
          '/login': (context) => LoginPage(),
           '/welcome': (context) => const WelcomePage(),
          '/signup': (context) => const SignUpPage(),
          '/forgot-password': (context) => const ForgotPasswordPage(),
      },
    );
  }
}