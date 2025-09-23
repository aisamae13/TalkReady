// lib/certificates/certificate_view_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // Add this import

class CertificateViewPage extends StatelessWidget {
  final Map<String, dynamic> certificateData;

  const CertificateViewPage({super.key, required this.certificateData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E40AF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Certificate',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareCertificate(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Certificate Preview
            _buildCertificatePreview(),
            const SizedBox(height: 24),
            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatePreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1E40AF), width: 6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'images/TR Logo.png', // Your TalkReady logo
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Certificate of Completion',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E40AF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Subtitle
            const Text(
              'This certificate is proudly presented to',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Student Name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF64748B), width: 2),
                ),
              ),
              child: Text(
                certificateData['studentName'] ?? 'Student Name',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Course description
            const Text(
              'for successfully completing the TalkReady course:',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Course Name
            Text(
              certificateData['courseName'] ??
                  'English Customer Service Excellence',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E40AF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // QR Code Section (Mobile-optimized)
            _buildMobileQRSection(),

            const SizedBox(height: 20),

            // Date and Signature Row (Mobile-optimized)
            _buildMobileDateSignatureRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileQRSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // QR Code
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: QrImageView(
              data: certificateData['verificationUrl'] ?? '',
              version: QrVersions.auto,
              size: 80,
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(height: 12),

          // Certificate ID
          Text(
            'Certificate ID: ${certificateData['certificateId'] ?? 'UNKNOWN'}',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Verify link
          GestureDetector(
            onTap: _verifyOnline,
            child: const Text(
              'Scan to verify online',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF2563EB),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDateSignatureRow() {
    return Row(
      children: [
        // Date Section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 2, width: 60, color: const Color(0xFF64748B)),
              const SizedBox(height: 8),
              const Text(
                'Date Issued',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                certificateData['completionDate'] ?? '—',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        // Spacer
        const SizedBox(width: 20),

        // Signature Section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(height: 2, width: 60, color: const Color(0xFF64748B)),
              const SizedBox(height: 8),
              const Text(
                'Signature',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Authorized Signature',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _verifyOnline(),
            icon: const Icon(Icons.verified),
            label: const Text('Verify Online'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _shareCertificate(context),
            icon: const Icon(Icons.share),
            label: const Text('Share Certificate'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E40AF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFF1E40AF)),
            ),
          ),
        ),
      ],
    );
  }

  void _verifyOnline() async {
    final url = certificateData['verificationUrl'] as String?;
    if (url != null) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    }
  }

  // Replace the _shareCertificate method:
  void _shareCertificate(BuildContext context) async {
    try {
      final certificateId =
          certificateData['certificateId'] as String? ?? 'UNKNOWN';
      final studentName =
          certificateData['studentName'] as String? ?? 'Student';
      final courseName =
          certificateData['courseName'] as String? ??
          'English Customer Service Excellence';
      final completionDate =
          certificateData['completionDate'] as String? ?? 'Recently';
      final verificationUrl =
          certificateData['verificationUrl'] as String? ?? '';

      // Create share content
      final shareText =
          '''
🎉 I've completed the TalkReady course!

📋 Course: $courseName
👤 Graduate: $studentName
📅 Completed: $completionDate
🏆 Certificate ID: $certificateId

✅ Verify this certificate online:
$verificationUrl

#TalkReady #CustomerService #EnglishLearning #Certificate
''';

      // Show share options
      await _showShareOptions(context, shareText, verificationUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this new method for share options:
  Future<void> _showShareOptions(
    BuildContext context,
    String shareText,
    String verificationUrl,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Share Certificate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),

            // Share options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.share,
                  label: 'Share All',
                  color: const Color(0xFF1E40AF),
                  onTap: () {
                    print('Share All tapped'); // Debug print
                    Navigator.pop(context);
                    print(
                      'About to call Share.share with: $shareText',
                    ); // Debug print
                    Share.share(shareText)
                        .then((_) {
                          print('Share completed successfully');
                        })
                        .catchError((error) {
                          print('Share error: $error');
                        });
                  },
                ),
                _buildShareOption(
                  icon: Icons.link,
                  label: 'Share Link',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    print('Share Link tapped'); // Debug print
                    Navigator.pop(context);
                    final linkText =
                        'Check out my TalkReady certificate: $verificationUrl';
                    print('About to share: $linkText'); // Debug print
                    Share.share(linkText, subject: 'My TalkReady Certificate')
                        .then((_) {
                          print('Link share completed successfully');
                        })
                        .catchError((error) {
                          print('Link share error: $error');
                        });
                  },
                ),
                _buildShareOption(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: const Color(0xFF8B5CF6),
                  onTap: () async {
                    Navigator.pop(context);
                    await _copyToClipboard(context, verificationUrl);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Add this helper method for share options:
  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Add this method for copying to clipboard:
  Future<void> _copyToClipboard(BuildContext context, String text) async {
    try {
      // Use the Clipboard API
      await Clipboard.setData(ClipboardData(text: text));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Certificate link copied to clipboard!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareToWhatsApp(String text) async {
    final encodedText = Uri.encodeComponent(text);
    final whatsappUrl = 'whatsapp://send?text=$encodedText';

    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      // Fallback to regular share
      Share.share(text);
    }
  }

  Future<void> _shareToLinkedIn(String text, String url) async {
    final linkedInUrl =
        'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(url)}';

    if (await canLaunchUrl(Uri.parse(linkedInUrl))) {
      await launchUrl(Uri.parse(linkedInUrl));
    } else {
      Share.share(text);
    }
  }

  Future<void> _shareToFacebook(String url) async {
    final facebookUrl =
        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}';

    if (await canLaunchUrl(Uri.parse(facebookUrl))) {
      await launchUrl(Uri.parse(facebookUrl));
    } else {
      Share.share(url);
    }
  }

  void _trackCertificateShare(String shareType) {
    // You can integrate with Firebase Analytics or your preferred analytics service
    print('Certificate shared via: $shareType');
    // Example: FirebaseAnalytics.instance.logEvent(name: 'certificate_shared', parameters: {'method': shareType});
  }
}
