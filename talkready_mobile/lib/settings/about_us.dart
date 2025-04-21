import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUs extends StatelessWidget {
  const AboutUs({super.key});

  // Configure social media URL here
  static const String socialUrl = 'https://x.com/TalkReadyApp'; // Replace with actual URL

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2973B2),
        title: const Text(
          'About Us',
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
            Image.asset(
              'images/logoTR.png', // Ensure this path is correct in pubspec.yaml
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.error,
                size: 100,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'About TalkReady',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TalkReady is dedicated to empowering everyone to speak English confidently through fun, interactive learning.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            const Text(
              'Our Mission',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'To make language learning accessible and enjoyable for all.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            const Text(
              'Our Vision',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'A world where language barriers don’t hold anyone back.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            const Text(
              'Our Team',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            Text(
              'Built by a passionate team of language lovers and tech innovators.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
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
                      ? 'Version ${snapshot.data!.version}'
                      : 'Version loading...',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                );
              },
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                final Uri url = Uri.parse(socialUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open link')),
                  );
                }
              },
              child: const Text(
                'Follow us on X!',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2973B2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}