import 'package:flutter/material.dart';

class CommunityGuidelines extends StatelessWidget {
  const CommunityGuidelines({super.key});

  Widget _buildGuidelineItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2973B2), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2973B2),
        title: const Text(
          'Community Guidelines',
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
              'TalkReady Community Guidelines',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'We’re building a supportive community to help you learn English. Follow these guidelines to keep TalkReady a positive place for everyone!',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 20),
            _buildGuidelineItem(
              icon: Icons.favorite,
              text:
                  'Be Respectful: Treat others with kindness. No harassment, bullying, or hate speech.',
            ),
            _buildGuidelineItem(
              icon: Icons.school,
              text:
                  'Learn Responsibly: Use TalkReady for education, not for sharing inappropriate content.',
            ),
            _buildGuidelineItem(
              icon: Icons.star,
              text:
                  'Share Feedback: Offer constructive suggestions to help us improve.',
            ),
            _buildGuidelineItem(
              icon: Icons.shield,
              text:
                  'Stay Safe: Report any issues through FAQ & Support to keep our community secure.',
            ),
            const SizedBox(height: 20),
            Text(
              'Let’s make TalkReady a great place to learn!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2973B2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}