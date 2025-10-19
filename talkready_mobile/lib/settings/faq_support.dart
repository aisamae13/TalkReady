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

  Widget _buildFaqCategory({required String category, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
          ),
        ),
        ...items,
      ],
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
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Find answers to common questions about TalkReady',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Account & Settings
            _buildFaqCategory(
              category: '👤 Account & Settings',
              items: [
                _buildFaqItem(
                  question: 'How do I reset my password?',
                  answer:
                      'Go to the sign-in page and tap "Forgot Password" to receive a reset link via email. Follow the instructions in the email to create a new password.',
                ),
                _buildFaqItem(
                  question: 'How do I update my profile information?',
                  answer:
                      'Go to Profile → Edit Profile to update your name, email, and other personal information.',
                ),
                _buildFaqItem(
                  question: 'How do I delete my account?',
                  answer:
                      'Go to Settings → Delete Account and confirm to permanently remove your account. Note: This action cannot be undone and all your data will be deleted.',
                ),
              ],
            ),

            // Learning & Progress
            _buildFaqCategory(
              category: '📚 Learning & Progress',
              items: [
                _buildFaqItem(
                  question: 'How do I track my progress?',
                  answer:
                      'Go to the Progress tab to view your detailed statistics, including lessons completed, speaking time, streak, and skill analysis.',
                ),
                _buildFaqItem(
                  question: 'What are Streak Freezes?',
                  answer:
                      'Streak Freezes protect your learning streak when you miss a day. You earn 1 freeze for every 30-day streak milestone (maximum 5). They are used automatically when needed.',
                ),
                _buildFaqItem(
                  question: 'How do lessons work?',
                  answer:
                      'Lessons are organized into modules by difficulty level. Complete lessons to earn scores, build your streak, and improve your English skills. You can retake lessons to improve your score.',
                ),
                _buildFaqItem(
                  question: 'What is the Practice Center?',
                  answer:
                      'The Practice Center offers targeted exercises for pronunciation, fluency, grammar, vocabulary, and role-play scenarios to help you improve specific skills.',
                ),
              ],
            ),

            // AI Features
            _buildFaqCategory(
              category: '🤖 AI Features',
              items: [
                _buildFaqItem(
                  question: 'How does the AI chatbot work?',
                  answer:
                      'Our TalkReady AI chatbot uses advanced AI to simulate real conversations, helping you practice English anytime. You can chat about various topics and receive instant feedback on your responses.',
                ),
                _buildFaqItem(
                  question: 'How accurate is the AI feedback?',
                  answer:
                      'Our AI uses advanced speech recognition and natural language processing to provide accurate feedback on pronunciation, fluency, grammar, and conversation skills.',
                ),
                _buildFaqItem(
                  question: 'Can I practice speaking with AI?',
                  answer:
                      'Yes! Many lessons include speaking exercises where AI analyzes your pronunciation, fluency, and speech clarity. The Practice Center also offers dedicated speaking practice.',
                ),
              ],
            ),

            // Classes & Assessments
            _buildFaqCategory(
              category: '🎓 Classes & Assessments',
              items: [
                _buildFaqItem(
                  question: 'How do I join a class?',
                  answer:
                      'Your trainer will provide you with a class code. Go to My Classes → Join Class and enter the code to enroll.',
                ),
                _buildFaqItem(
                  question: 'What happens after I submit an assessment?',
                  answer:
                      'Your trainer will review your submission and provide feedback. You can view your results and feedback in the Progress → Trainer Assessments section.',
                ),
                _buildFaqItem(
                  question: 'Can I retake an assessment?',
                  answer:
                      'This depends on your trainer\'s settings. Some assessments allow multiple attempts while others may be one-time only.',
                ),
              ],
            ),

            // Technical Issues
            _buildFaqCategory(
              category: '🔧 Technical Issues',
              items: [
                _buildFaqItem(
                  question: 'The app is not loading properly',
                  answer:
                      'Try closing and reopening the app. Make sure you have a stable internet connection. If the problem persists, try clearing the app cache or reinstalling the app.',
                ),
                _buildFaqItem(
                  question: 'I\'m having trouble with voice recognition',
                  answer:
                      'Make sure you\'ve granted microphone permissions to TalkReady. Speak clearly and ensure you\'re in a quiet environment. Check your device\'s microphone settings.',
                ),
                _buildFaqItem(
                  question: 'My progress is not syncing',
                  answer:
                      'Ensure you have a stable internet connection. Your progress automatically syncs when connected. Pull down on the Progress page to manually refresh.',
                ),
              ],
            ),

            // Pricing & Features
            _buildFaqCategory(
              category: '💰 Pricing & Features',
              items: [
                _buildFaqItem(
                  question: 'Is TalkReady free?',
                  answer:
                      'TalkReady offers free core features including AI lessons, chatbot practice, and progress tracking. Premium features and advanced courses may be available in the future.',
                ),
                _buildFaqItem(
                  question: 'What features are available?',
                  answer:
                      'TalkReady includes: AI-powered lessons, speaking practice, grammar and vocabulary exercises, live chatbot conversations, progress tracking, trainer-led classes, and personalized learning tips.',
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Contact Support Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00568D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00568D).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, color: Color(0xFF00568D), size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Still Need Help?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00568D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Can\'t find what you\'re looking for? Our support team is here to help!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
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
                                content: Text('Could not open email client'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.email),
                      label: const Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00568D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}