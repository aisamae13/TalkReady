import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Updated Welcome Text
              const Text(
                'Welcome to TalkReady!',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00568D),
                ),
              ),
              const SizedBox(height: 50),
              // Description Text
              const Text(
                'We have a few questions to learn about you and your goals.',
                textAlign: TextAlign.left,
                softWrap: true,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: Color.fromARGB(255, 212, 168, 102),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'This will help us build the best study plan for you!',
                textAlign: TextAlign.left,
                softWrap: true,
                style: TextStyle(
                  fontSize: 28,
                  color: Color.fromARGB(255, 212, 168, 102),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 60),
              // Full-Width Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00568D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Let\'s begin',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}