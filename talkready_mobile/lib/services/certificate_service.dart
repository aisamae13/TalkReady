// lib/services/certificate_service.dart

import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  // ✅ Check if user completed all required lessons
  Future<bool> hasCompletedAllModules(String userId) async {
    try {
      final userProgressDoc = await _firestore
          .collection('userProgress')
          .doc(userId)
          .get();

      if (!userProgressDoc.exists) {
        _logger.w('No userProgress document found for user $userId');
        return false;
      }

      final data = userProgressDoc.data()!;
      final lessonAttempts =
          data['lessonAttempts'] as Map<String, dynamic>? ?? {};

      _logger.i('Checking lesson attempts for certificate eligibility...');
      _logger.i('Available lesson keys: ${lessonAttempts.keys.toList()}');

      // Required lessons (same as web)
      final requiredLessons = [
        'Lesson-1-1', 'Lesson-1-2', 'Lesson-1-3', // Module 1
        'Lesson-2-1', 'Lesson-2-2', 'Lesson-2-3', // Module 2
        'Lesson-3-1', 'Lesson-3-2', // Module 3
        'Lesson-4-1', 'Lesson-4-2', // Module 4
        'Lesson-5-1', 'Lesson-5-2', // Module 5
        'Lesson-6-1', // Module 6
      ];

      // Check if all required lessons have at least one attempt
      for (String lessonId in requiredLessons) {
        final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];

        if (attempts.isEmpty) {
          _logger.w('Missing lesson: $lessonId - Certificate not available');
          return false;
        }
      }

      _logger.i('🎉 All required lessons completed! Certificate available!');
      return true;
    } catch (e) {
      _logger.e('Error checking lesson completion: $e');
      return false;
    }
  }

  // ✅ Open web browser to claim certificate
  Future<void> claimCertificateOnWeb() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // ✅ IMPORTANT: Update this URL to match your deployed web app
      final url = Uri.parse(
        'https://talkreadyweb.onrender.com/mobile-certificate',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Opens in browser
        );
        _logger.i('✅ Opened mobile certificate page in browser');
      } else {
        throw Exception('Could not launch browser');
      }
    } catch (e) {
      _logger.e('❌ Error opening certificate page: $e');
      rethrow;
    }
  }

  // ✅ Check if certificate already exists
  Future<Map<String, dynamic>?> getExistingCertificate(String userId) async {
    try {
      final certificatesQuery = await _firestore
          .collection('certificates')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (certificatesQuery.docs.isNotEmpty) {
        final doc = certificatesQuery.docs.first;
        _logger.i('✅ Found existing certificate for user $userId');
        return {'id': doc.id, ...doc.data()};
      }

      _logger.i('ℹ️ No certificate found for user $userId');
      return null;
    } catch (e) {
      _logger.e('❌ Error checking existing certificate: $e');
      return null;
    }
  }

  // ✅ Open existing certificate in browser
  Future<void> viewCertificateOnWeb(String certificateId) async {
    try {
      final url = Uri.parse(
        'https://talkreadyweb.onrender.com/certificate/$certificateId',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        _logger.i('✅ Opened certificate $certificateId in browser');
      } else {
        throw Exception('Could not launch browser');
      }
    } catch (e) {
      _logger.e('❌ Error opening certificate: $e');
      rethrow;
    }
  }
}
