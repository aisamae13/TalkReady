import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class WelcomePage extends StatelessWidget {
  final String? userType; // Add this parameter

  const WelcomePage({super.key, this.userType}); // Accept userType

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF00568D).withOpacity(0.1),
                Colors.grey[50]!,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to TalkReady!',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'We have a few questions to learn about you and your goals.',
                    textAlign: TextAlign.left,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color.fromARGB(255, 177, 127, 89),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This will help us build the best study plan for you!',
                    textAlign: TextAlign.left,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color.fromARGB(255, 177, 127, 89),
                    ),
                  ),
                  const SizedBox(height: 80),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Pass userType to OnboardingScreen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OnboardingScreen(
                              userType: userType, // Pass it here!
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00568D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 5,
                        shadowColor: Colors.black.withOpacity(0.2),
                      ),
                      child: const Text(
                        'Let\'s begin',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}