import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

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
                    fontSize: 22, // Slightly smaller for better hierarchy
                    fontWeight: FontWeight.w600, // Lighter weight for readability
                    color: Color.fromARGB(255, 177,127,89),
                  ),
                ),
                const SizedBox(height: 16), // Adjusted spacing
                // Description Text 2
                const Text(
                  'This will help us build the best study plan for you!',
                  textAlign: TextAlign.left,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 22, // Consistent with first description
                    fontWeight: FontWeight.w600,
                    color: Color.fromARGB(255, 177,127,89),
                  ),
                ),
                const SizedBox(height: 80), // Increased spacing before button
                // Full-Width Button with Animation
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00568D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14), // Slightly taller button
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // More rounded corners
                      ),
                      elevation: 5, // Add shadow for depth
                      shadowColor: Colors.black.withOpacity(0.2), // Subtle shadow
                    ),
                    child: const Text(
                      'Let\'s begin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600, // Slightly bolder text
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
    );
  }
}