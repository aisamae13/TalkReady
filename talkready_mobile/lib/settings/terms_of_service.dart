import 'package:flutter/material.dart';

class TermsOfService extends StatelessWidget {
  const TermsOfService({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2973B2),
        title: const Text(
          'Terms of Service',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TalkReady Terms of Service',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to TalkReady! These Terms of Service govern your use of our app. By creating an account or using TalkReady, you agree to these terms.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 20),
            const Text(
              '1. Eligibility',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'You must be at least 13 years old to use TalkReady. Accounts are personal and cannot be shared or transferred.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 15),
            const Text(
              '2. Content Ownership',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'Your data, such as profile pictures and learning progress, belongs to you. You grant TalkReady a license to use this data to provide and improve our services.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 15),
            const Text(
              '3. Prohibited Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'You may not misuse TalkReady, including hacking, spamming, or sharing harmful or illegal content.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 15),
            const Text(
              '4. Account Termination',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'We reserve the right to suspend or terminate accounts for violations of these terms.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 15),
            const Text(
              '5. Changes to Terms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'We may update these terms from time to time. You will be notified of significant changes via the app or email.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 15),
            const Text(
              '6. Contact Us',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'Have questions? Reach out to us at support@talkready.com.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    );
  }
}