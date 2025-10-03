import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Show splash for at least 1 second
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Check if user is already logged in
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // No user logged in, go to landing page
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    // User is logged in, check their profile completion status
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final userData = docSnapshot.data();

      // If no document or no userType, needs to choose user type
      if (!docSnapshot.exists || userData == null || userData['userType'] == null) {
        Navigator.pushReplacementNamed(context, '/chooseUserType');
        return;
      }

      final role = userData['userType'];
      final onboardingCompleted = userData['onboardingCompleted'] ?? false;

      // Has userType but needs onboarding
      if (!onboardingCompleted) {
        Navigator.pushReplacementNamed(context, '/welcome');
        return;
      }

      // Fully onboarded - navigate to appropriate dashboard
      if (role == 'trainer' || role == 'teacher') {
        Navigator.pushReplacementNamed(context, '/trainer-dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/homepage');
      }
    } catch (e) {
      // On error, go to landing page
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: Image.asset(
          'images/TR Logo.png',
          width: 200,
          height: 200,
        ),
      ),
    );
  }
}