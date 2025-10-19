import 'package:flutter/material.dart';

class CommunityGuidelines extends StatelessWidget {
  const CommunityGuidelines({super.key});

  Widget _buildGuidelineSection({
    required String title,
    required IconData icon,
    required List<String> points,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00568D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF00568D), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00568D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map((point) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
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
      ),
    );
  }

  Widget _buildProhibitedItem({required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedItem({required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: Colors.grey[800]),
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
                border: Border.all(
                  color: const Color(0xFF00568D).withOpacity(0.3),
                ),
              ),
              child: Text(
                'Welcome to TalkReady! We\'re building a supportive, inclusive, and positive learning community. These guidelines help ensure everyone has a safe and enriching experience while learning English together.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Core Values
            _buildGuidelineSection(
              title: 'Our Core Values',
              icon: Icons.favorite,
              points: [
                'Respect: Treat all members with kindness and consideration',
                'Inclusivity: Welcome learners of all backgrounds and skill levels',
                'Encouragement: Support others in their learning journey',
                'Growth Mindset: Embrace mistakes as learning opportunities',
                'Integrity: Be honest and authentic in all interactions',
              ],
            ),

            // Respectful Behavior
            _buildGuidelineSection(
              title: 'Be Respectful & Kind',
              icon: Icons.people,
              points: [
                'Use polite and constructive language at all times',
                'Respect different learning paces and proficiency levels',
                'Avoid criticizing or making fun of others\' mistakes',
                'Be patient with fellow learners who are still improving',
                'Celebrate others\' achievements and progress',
                'Listen actively and respond thoughtfully',
              ],
            ),

            // Learning Environment
            _buildGuidelineSection(
              title: 'Create a Positive Learning Environment',
              icon: Icons.school,
              points: [
                'Share helpful tips and resources with the community',
                'Offer constructive feedback when appropriate',
                'Ask questions respectfully and thoughtfully',
                'Help others when they\'re struggling with lessons',
                'Participate actively in class discussions',
                'Use TalkReady features for their intended educational purpose',
              ],
            ),

            // Communication Guidelines
            _buildGuidelineSection(
              title: 'Communication Best Practices',
              icon: Icons.chat_bubble,
              points: [
                'Keep conversations relevant to English learning',
                'Use appropriate language in all communications',
                'Respect others\' privacy and personal boundaries',
                'Avoid spamming or excessive messaging',
                'Stay on topic during trainer-led classes',
                'Give credit when sharing others\' ideas or content',
              ],
            ),

            // Safety & Privacy
            _buildGuidelineSection(
              title: 'Safety & Privacy',
              icon: Icons.shield,
              points: [
                'Never share personal information (address, phone number, etc.)',
                'Don\'t request personal information from others',
                'Protect your account credentials',
                'Report suspicious behavior immediately',
                'Block and report users who make you uncomfortable',
                'Use TalkReady\'s built-in communication tools only',
              ],
            ),

            const SizedBox(height: 20),

            // Prohibited Behavior Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Prohibited Behavior',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The following behaviors are strictly prohibited and may result in account suspension or termination:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildProhibitedItem(
                    text: 'Harassment, bullying, or intimidation of any kind',
                  ),
                  _buildProhibitedItem(
                    text: 'Hate speech, discrimination, or offensive content',
                  ),
                  _buildProhibitedItem(
                    text: 'Sharing inappropriate, explicit, or illegal content',
                  ),
                  _buildProhibitedItem(
                    text: 'Cheating on assessments or helping others cheat',
                  ),
                  _buildProhibitedItem(
                    text: 'Impersonating others or creating fake accounts',
                  ),
                  _buildProhibitedItem(
                    text: 'Spamming, advertising, or promoting external services',
                  ),
                  _buildProhibitedItem(
                    text: 'Threats, violence, or encouragement of self-harm',
                  ),
                  _buildProhibitedItem(
                    text: 'Disrupting classes or interfering with others\' learning',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Expected Behavior Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.thumb_up, color: Colors.green.shade700, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'What We Encourage',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildExpectedItem(text: 'Asking questions and seeking help'),
                  _buildExpectedItem(
                    text: 'Sharing learning strategies and study tips',
                  ),
                  _buildExpectedItem(
                    text: 'Encouraging and motivating fellow learners',
                  ),
                  _buildExpectedItem(
                    text: 'Providing constructive and helpful feedback',
                  ),
                  _buildExpectedItem(
                    text: 'Reporting issues or bugs to improve the app',
                  ),
                  _buildExpectedItem(text: 'Celebrating progress and milestones'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Reporting Section
            _buildGuidelineSection(
              title: 'Reporting Violations',
              icon: Icons.flag,
              points: [
                'If you witness or experience behavior that violates these guidelines, please report it immediately',
                'Contact support@talkready.com with details of the incident',
                'Include screenshots or evidence if available',
                'All reports are taken seriously and reviewed promptly',
                'Your identity will be kept confidential',
              ],
            ),

            // Consequences Section
            _buildGuidelineSection(
              title: 'Consequences of Violations',
              icon: Icons.gavel,
              points: [
                'First violation: Warning and educational guidance',
                'Second violation: Temporary account suspension',
                'Repeated or severe violations: Permanent account termination',
                'Illegal activities will be reported to authorities',
                'Decisions are made at TalkReady\'s sole discretion',
              ],
            ),

            const SizedBox(height: 20),

            // Closing Message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00568D).withOpacity(0.1),
                    const Color(0xFF2973B2).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.groups,
                    color: Color(0xFF00568D),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Together, We Learn Better',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Thank you for being part of the TalkReady community! By following these guidelines, you help create a positive, supportive environment where everyone can achieve their English learning goals.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Let\'s make TalkReady a great place to learn!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2973B2),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Footer
            Text(
              '© ${DateTime.now().year} TalkReady. We reserve the right to update these guidelines at any time.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}