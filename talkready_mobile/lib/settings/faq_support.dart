import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FaqAndSupport extends StatelessWidget {
  const FaqAndSupport({super.key});

  Widget _buildFaqItem({required String question, required String answer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00568D),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              answer,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
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
          'FAQ & Support',
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
              'FAQ & Support',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 20),
            _buildFaqItem(
              question: 'How do I reset my password?',
              answer:
                  'Go to the sign-in page and tap "Forgot Password" to receive a reset link via email.',
            ),
            _buildFaqItem(
              question: 'Can I change my English level?',
              answer:
                  'Yes! Go to Profile → Active Level to update your English proficiency.',
            ),
            _buildFaqItem(
              question: 'Is TalkReady free?',
              answer:
                  'Basic features are free. Premium features are planned for the future.',
            ),
            _buildFaqItem(
              question: 'How does the AI chatbot work?',
              answer:
                  'Our chatbot uses advanced AI to simulate real conversations, helping you practice English anytime.',
            ),
            _buildFaqItem(
              question: 'How do I delete my account?',
              answer:
                  'Go to Settings → Delete Account and confirm to permanently remove your account.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Need More Help?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: 'support@talkready.com',
                  query: 'subject=TalkReady Support Request',
                );
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Could not open email client')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF00568D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF00568D)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              child: const Text(
                'Contact Support',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00568D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}