import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUs extends StatelessWidget {
  const AboutUs({super.key});

  // Configure social media URLs here
  static const String twitterUrl = 'https://x.com/TalkReadyApp';
  static const String websiteUrl = 'https://talkreadyweb.onrender.com'; // Add your website
  static const String emailUrl = 'mailto:support@talkready.com';

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00568D).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF00568D), size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00568D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00568D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00568D), size: 20),
          ),
          const SizedBox(width: 12),
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

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required String url,
    required BuildContext context,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () async {
          final Uri uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open link')),
            );
          }
        },
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00568D),
          side: const BorderSide(color: Color(0xFF00568D)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2973B2),
        title: const Text(
          'About TalkReady',
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                'images/logoTR.png',
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.school,
                  size: 80,
                  color: Color(0xFF00568D),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Main Title and Description
            const Text(
              'Welcome to TalkReady',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your AI-Powered English Learning Companion',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'TalkReady is dedicated to empowering everyone to speak English confidently through innovative AI technology, interactive learning experiences, and personalized feedback.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.6),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Mission, Vision, Values
            _buildInfoSection(
              icon: Icons.rocket_launch,
              title: 'Our Mission',
              content:
                  'To make English learning accessible, engaging, and effective for everyone through cutting-edge AI technology and proven teaching methodologies.',
            ),

            _buildInfoSection(
              icon: Icons.visibility,
              title: 'Our Vision',
              content:
                  'A world where language barriers don\'t hold anyone back from achieving their dreams and connecting with people globally.',
            ),

            _buildInfoSection(
              icon: Icons.favorite,
              title: 'Our Values',
              content:
                  'Innovation, Accessibility, Excellence, and Empowerment. We believe in creating technology that truly makes a difference in people\'s lives.',
            ),

            const SizedBox(height: 20),

            // What Makes TalkReady Special
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00568D).withOpacity(0.1),
                    const Color(0xFF2973B2).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00568D).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'What Makes Us Special',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureItem(
                    icon: Icons.psychology,
                    text: 'AI-Powered personalized learning paths',
                  ),
                  _buildFeatureItem(
                    icon: Icons.mic,
                    text: 'Real-time speech recognition and feedback',
                  ),
                  _buildFeatureItem(
                    icon: Icons.chat_bubble,
                    text: 'Interactive AI chatbot conversations',
                  ),
                  _buildFeatureItem(
                    icon: Icons.analytics,
                    text: 'Comprehensive progress tracking',
                  ),
                  _buildFeatureItem(
                    icon: Icons.school,
                    text: 'Trainer-led classes and assessments',
                  ),
                  _buildFeatureItem(
                  icon: Icons.local_fire_department,
                  text: 'Streak milestones with freeze rewards every 30 days',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Team Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.people,
                    size: 48,
                    color: Color(0xFF00568D),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Our Team',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Built by a passionate team of language educators, AI engineers, and tech innovators who believe in the power of technology to transform education.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Version Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'Version unavailable',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        );
                      }
                      return Text(
                        snapshot.hasData
                            ? 'TalkReady v${snapshot.data!.version} (Build ${snapshot.data!.buildNumber})'
                            : 'Loading version...',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Connect With Us
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00568D).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Connect With Us',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildSocialButton(
                        icon: Icons.language,
                        label: 'Website',
                        url: websiteUrl,
                        context: context,
                      ),
                      const SizedBox(width: 12),
                      _buildSocialButton(
                        icon: Icons.close, // X (Twitter) icon
                        label: 'Follow Us',
                        url: twitterUrl,
                        context: context,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final Uri uri = Uri.parse(emailUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open email client'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.email, size: 20),
                      label: const Text('Contact Support'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00568D),
                        side: const BorderSide(color: Color(0xFF00568D)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Footer
            Text(
              '© ${DateTime.now().year} TalkReady. All rights reserved.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Made with ❤️ for language learners worldwide',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
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