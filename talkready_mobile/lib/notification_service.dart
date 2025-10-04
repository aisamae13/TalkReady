import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  /// Notify all students enrolled in a class
  static Future<void> createNotificationsForStudents({
    required String classId,
    required String message,
    required String? className,
    required String link,
  }) async {
    try {
      // Get all students enrolled in this class
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('trainerClass')
          .doc(classId)
          .collection('students')
          .get();

      if (studentsSnapshot.docs.isEmpty) {
        debugPrint('No students found in class $classId');
        return;
      }

      // Create notifications in batch
      final batch = FirebaseFirestore.instance.batch();

      for (var studentDoc in studentsSnapshot.docs) {
        final studentId = studentDoc.id;
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'userId': studentId,
          'message': message,
          'className': className,
          'link': link,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ Created ${studentsSnapshot.docs.length} notifications for: $message');
    } catch (e) {
      debugPrint('❌ Error creating notifications: $e');
      // Don't throw - notifications are not critical
    }
  }

  /// Notify a single user (trainer or student)
  static Future<void> notifyUser({
    required String userId,
    required String message,
    required String? className,
    required String link,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'message': message,
        'className': className,
        'link': link,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notification created for user: $userId - $message');
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
      // Don't throw - notifications are not critical
    }
  }

  /// Notify a student when they are removed from a class
  static Future<void> notifyStudentRemoval({
    required String studentId,
    required String className,
    required String trainerName,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': studentId,
        'message': 'You have been removed from "$className" by $trainerName',
        'className': className,
        'link': null, // No link - just show the message
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'removal', // Optional: to distinguish notification types
      });
      debugPrint('✅ Removal notification sent to student: $studentId from class: $className');
    } catch (e) {
      debugPrint('❌ Error creating removal notification: $e');
      // Don't throw - notifications are not critical
    }
  }

  /// Notify a student when they are enrolled in a class
  static Future<void> notifyStudentEnrollment({
    required String studentId,
    required String className,
    required String classId,
    required String trainerName,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': studentId,
        'message': 'You have been enrolled in "$className" by $trainerName',
        'className': className,
        'link': '/student/class/$classId',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'enrollment', // Optional: to distinguish notification types
      });
      debugPrint('✅ Enrollment notification sent to student: $studentId for class: $className');
    } catch (e) {
      debugPrint('❌ Error creating enrollment notification: $e');
      // Don't throw - notifications are not critical
    }
  }
}