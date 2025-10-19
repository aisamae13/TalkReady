import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsOfService extends StatelessWidget {
  const TermsOfService({super.key});

  Widget _buildSection({
    required String title,
    required String content,
    List<String>? bulletPoints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
          ),
          if (bulletPoints != null) ...[
            const SizedBox(height: 10),
            ...bulletPoints.map((point) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 15)),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
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
            const SizedBox(height: 10),
            Text(
              'Last Updated: ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00568D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00568D).withOpacity(0.3)),
              ),
              child: Text(
                'Welcome to TalkReady! These Terms of Service ("Terms") govern your access to and use of the TalkReady mobile application and services. By creating an account or using TalkReady, you agree to be bound by these Terms. Please read them carefully.',
                style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
              ),
            ),
            const SizedBox(height: 30),

            _buildSection(
              title: '1. Acceptance of Terms',
              content:
                  'By accessing or using TalkReady, you confirm that you have read, understood, and agree to be bound by these Terms and our Privacy Policy. If you do not agree, please do not use our services.',
            ),

            _buildSection(
              title: '2. Eligibility',
              content:
                  'To use TalkReady, you must meet the following requirements:',
              bulletPoints: [
                'Be at least 13 years old',
                'Have the legal capacity to enter into a binding agreement',
                'Not be prohibited from using our services under applicable laws',
                'Provide accurate and complete registration information',
              ],
            ),

            _buildSection(
              title: '3. User Accounts',
              content:
                  'When you create an account with TalkReady:',
              bulletPoints: [
                'You are responsible for maintaining the confidentiality of your account credentials',
                'You are responsible for all activities that occur under your account',
                'You must notify us immediately of any unauthorized access or security breach',
                'Accounts are personal and may not be shared, sold, or transferred to others',
                'You must provide accurate, current, and complete information during registration',
              ],
            ),

            _buildSection(
              title: '4. User Content and Data',
              content:
                  'TalkReady collects and processes various types of user data:',
              bulletPoints: [
                'Profile Information: Your name, email, profile picture, and preferences',
                'Learning Data: Lesson progress, scores, speaking recordings, and practice history',
                'Usage Data: App interaction patterns and feature usage statistics',
                'You retain ownership of all content you create or upload',
                'You grant TalkReady a license to use your data to provide and improve our services',
                'We will handle your data in accordance with our Privacy Policy',
              ],
            ),

            _buildSection(
              title: '5. AI-Powered Services',
              content:
                  'TalkReady uses artificial intelligence to provide personalized learning experiences:',
              bulletPoints: [
                'AI feedback is provided for educational purposes and may not be 100% accurate',
                'Voice recordings may be processed by AI for speech analysis and improvement',
                'AI-generated content is for learning purposes only',
                'We continuously work to improve AI accuracy but cannot guarantee perfection',
              ],
            ),

            _buildSection(
              title: '6. Prohibited Conduct',
              content:
                  'You agree NOT to:',
              bulletPoints: [
                'Use TalkReady for any illegal or unauthorized purpose',
                'Attempt to hack, compromise, or disrupt the app\'s security or functionality',
                'Upload malicious code, viruses, or harmful content',
                'Share inappropriate, offensive, or harmful content',
                'Impersonate others or provide false information',
                'Use automated systems (bots) to access the service',
                'Reverse engineer, decompile, or attempt to extract source code',
                'Violate intellectual property rights of TalkReady or third parties',
              ],
            ),

            _buildSection(
              title: '7. Subscription and Payment',
              content:
                  'Currently, TalkReady offers free core features. If we introduce premium features:',
              bulletPoints: [
                'Pricing and billing terms will be clearly communicated',
                'Subscriptions will auto-renew unless cancelled',
                'Refunds will be handled according to our refund policy',
                'You are responsible for any applicable taxes',
              ],
            ),

            _buildSection(
              title: '8. Classes and Assessments',
              content:
                  'When participating in trainer-led classes:',
              bulletPoints: [
                'You must follow class guidelines and respect trainers and other students',
                'Assessment submissions are subject to review by authorized trainers',
                'You may not share assessment content or answers with others',
                'Academic integrity is expected at all times',
              ],
            ),

            _buildSection(
              title: '9. Intellectual Property',
              content:
                  'All content, features, and functionality of TalkReady are owned by TalkReady and are protected by intellectual property laws:',
              bulletPoints: [
                'Lesson content, AI models, designs, and trademarks belong to TalkReady',
                'You may not copy, modify, distribute, or create derivative works',
                'Any user-generated content remains your property, but you grant us a license to use it',
              ],
            ),

            _buildSection(
              title: '10. Third-Party Services',
              content:
                  'TalkReady may integrate with third-party services (e.g., Firebase, cloud storage):',
              bulletPoints: [
                'These services have their own terms and privacy policies',
                'We are not responsible for third-party service interruptions or data practices',
                'Your use of third-party services is at your own risk',
              ],
            ),

            _buildSection(
              title: '11. Disclaimers and Limitations',
              content:
                  'TalkReady is provided "as is" without warranties of any kind:',
              bulletPoints: [
                'We do not guarantee uninterrupted, error-free, or secure service',
                'We are not liable for any indirect, incidental, or consequential damages',
                'AI feedback and learning outcomes are not guaranteed',
                'We are not responsible for user-generated content',
              ],
            ),

            _buildSection(
              title: '12. Account Suspension and Termination',
              content:
                  'We reserve the right to:',
              bulletPoints: [
                'Suspend or terminate accounts that violate these Terms',
                'Remove content that violates our policies',
                'Modify or discontinue services at any time with notice',
                'Users may delete their accounts at any time through Settings',
              ],
            ),

            _buildSection(
              title: '13. Privacy and Data Protection',
              content:
                  'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your personal information. By using TalkReady, you consent to our data practices as described in the Privacy Policy.',
            ),

            _buildSection(
              title: '14. Changes to Terms',
              content:
                  'We may update these Terms from time to time to reflect changes in our services or legal requirements:',
              bulletPoints: [
                'Significant changes will be communicated via email or in-app notification',
                'Continued use of TalkReady after changes constitutes acceptance',
                'You should review these Terms periodically',
              ],
            ),

            _buildSection(
              title: '15. Governing Law',
              content:
                  'These Terms are governed by and construed in accordance with the laws of the Philippines. Any disputes will be resolved in the courts of the Philippines.',
            ),

            _buildSection(
              title: '16. Contact Information',
              content:
                  'If you have questions, concerns, or feedback about these Terms, please contact us:',
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.email, color: Color(0xFF00568D), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Email:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final Uri emailUri = Uri(
                            scheme: 'mailto',
                            path: 'support@talkready.com',
                            query: 'subject=Terms of Service Inquiry',
                          );
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(emailUri);
                          }
                        },
                        child: const Text(
                          'support@talkready.com',
                          style: TextStyle(
                            color: Color(0xFF00568D),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00568D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '© 2025 TalkReady. All rights reserved. By using TalkReady, you acknowledge that you have read and understood these Terms of Service.',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}