// lib/services/certificate_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  // Replace the _generateCertificateId method with this improved version:
  String _generateCertificateId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestampPart = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(7);

    String randomPart = '';
    final random = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 6; i++) {
      randomPart += chars[(random + i) % chars.length];
    }

    return 'TR-$timestampPart-$randomPart';
  }

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

      // ✅ FIXED: Using the correct lesson ID format with hyphens
      final requiredLessons = [
        // Module 1 lessons
        'Lesson-1-1', 'Lesson-1-2', 'Lesson-1-3',
        // Module 2 lessons
        'Lesson-2-1', 'Lesson-2-2', 'Lesson-2-3',
        // Module 3 lessons
        'Lesson-3-1', 'Lesson-3-2',
        // Module 4 lessons
        'Lesson-4-1', 'Lesson-4-2',
        // Module 5 lessons
        'Lesson-5-1', 'Lesson-5-2',
        // Module 6 lesson
        'Lesson-6-1',
      ];

      _logger.i('Required lessons: $requiredLessons');

      // Check if all required lessons have at least one attempt
      for (String lessonId in requiredLessons) {
        final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];
        _logger.i('Lesson $lessonId: ${attempts.length} attempts');

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

  Future<bool> hasCompletedAllModulesAlternative(String userId) async {
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

      _logger.i('Checking lesson attempts: ${lessonAttempts.keys}');

      // Define all required lessons for course completion
      final requiredLessons = [
        // Module 1
        'Lesson 1.1', 'Lesson 1.2', 'Lesson 1.3',
        // Module 2
        'Lesson 2.1', 'Lesson 2.2', 'Lesson 2.3',
        // Module 3
        'Lesson 3.1', 'Lesson 3.2',
        // Module 4
        'Lesson 4.1', 'Lesson 4.2',
        // Module 5
        'Lesson 5.1', 'Lesson 5.2',
        // Module 6
        'Lesson-6-1', // This is the Module 6 format
      ];

      // Check if all required lessons have at least one attempt
      for (String lessonId in requiredLessons) {
        final attempts = lessonAttempts[lessonId] as List<dynamic>? ?? [];
        _logger.i('Lesson $lessonId attempts: ${attempts.length}');

        if (attempts.isEmpty) {
          _logger.w('Lesson $lessonId has no attempts');
          return false;
        }
      }

      _logger.i(
        'All required lessons completed! User is eligible for certificate.',
      );
      return true;
    } catch (e) {
      _logger.e('Error checking lesson completion: $e');
      return false;
    }
  }

  // Add this to CertificateService for debugging:
  Future<void> debugUserProgress(String userId) async {
    try {
      final doc = await _firestore.collection('userProgress').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _logger.i('=== FULL USER PROGRESS DEBUG ===');
        _logger.i('Raw data: ${data.toString()}');

        // Check for module completion flags
        for (int i = 1; i <= 6; i++) {
          final moduleKey = 'module$i';
          final moduleData = data[moduleKey];
          _logger.i('$moduleKey: $moduleData');
        }

        // Check lesson attempts
        final lessonAttempts =
            data['lessonAttempts'] as Map<String, dynamic>? ?? {};
        _logger.i('Lesson attempts keys: ${lessonAttempts.keys.toList()}');

        _logger.i('=== END DEBUG ===');
      }
    } catch (e) {
      _logger.e('Debug error: $e');
    }
  }

  // Check if user already has a certificate
  Future<Map<String, dynamic>?> getExistingCertificate(String userId) async {
    try {
      final certificatesQuery = await _firestore
          .collection('certificates')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (certificatesQuery.docs.isNotEmpty) {
        final doc = certificatesQuery.docs.first;
        return {'id': doc.id, ...doc.data()};
      }
      return null;
    } catch (e) {
      _logger.e('Error checking existing certificate: $e');
      return null;
    }
  }

  // Generate new certificate (matching your web generateCertificate function)
  Future<Map<String, dynamic>> generateCertificate(
    String userId,
    String studentName,
  ) async {
    try {
      final certificateId = _generateCertificateId();
      final now = DateTime.now();

      // Format completion date to match your web format
      final completionDate =
          '${_getMonthName(now.month)} ${now.day}, ${now.year}';

      // Use your existing Cloud Function URL for verification
      final verificationUrl =
          'https://verifycertificate-do3jiu7plq-uc.a.run.app/$certificateId';

      final certificateData = {
        'certificateId': certificateId,
        'studentName': studentName,
        'courseName': 'English Customer Service Excellence',
        'completionDate': completionDate,
        'issuedAt': now.toIso8601String(),
        'verificationUrl': verificationUrl,
        'userId': userId,
      };

      // Save to Firestore using certificateId as document ID (matching web)
      await _firestore
          .collection('certificates')
          .doc(certificateId)
          .set(certificateData);

      _logger.i('Certificate generated successfully: $certificateId');

      return {'id': certificateId, ...certificateData};
    } catch (e) {
      _logger.e('Error generating certificate: $e');
      throw Exception('Failed to generate certificate: $e');
    }
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  // Get certificate by ID
  Future<Map<String, dynamic>?> getCertificateById(String certificateId) async {
    try {
      final doc = await _firestore
          .collection('certificates')
          .doc(certificateId)
          .get();

      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      _logger.e('Error getting certificate: $e');
      return null;
    }
  }
}
