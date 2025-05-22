import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_page.dart';
import 'package:talkready_mobile/next_screen.dart'; // Added for student flow

class ChooseUserTypePage extends StatelessWidget {
  const ChooseUserTypePage({super.key});

  Future<void> _saveUserTypeAndNavigate(BuildContext context, String userType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'userType': userType}, SetOptions(merge: true));
    }
    // Navigate to WelcomePage first
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
    );
    // Then navigate to onboarding
    Navigator.pushNamed(
      context,
      '/onboarding',
      arguments: {'userType': userType},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose User Type'),
        backgroundColor: const Color(0xFF00568D),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _saveUserTypeAndNavigate(context, 'trainer'),
              child: const Text('I am a Trainer'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _saveUserTypeAndNavigate(context, 'student'),
              child: const Text('I am a Student'),
            ),
          ],
        ),
      ),
    );
  }
}