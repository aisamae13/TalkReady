import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  /// Notify all students enrolled in a class
  /// Notify all students enrolled in a class
static Future<void> createNotificationsForStudents({
  required String classId,
  required String message,
  required String? className,
  required String link,
  String type = 'announcement',
}) async {
  try {
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .get();

    if (studentsSnapshot.docs.isEmpty) {
      debugPrint('No students found in class $classId');
      return;
    }

    final batch = FirebaseFirestore.instance.batch();

    for (var enrollment in studentsSnapshot.docs) {
      final studentId = enrollment.data()['studentId'];
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
        'type': type,  // ADD THIS
      });
    }

    await batch.commit();
    debugPrint('✅ Created ${studentsSnapshot.docs.length} notifications for: $message');
  } catch (e) {
    debugPrint('❌ Error creating notifications: $e');
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

  static Future<void> scheduleDeadlineReminder({
  required String assessmentId,
  required String classId,
  required String assessmentTitle,
  required DateTime deadline,
  required String? className,
}) async {
  try {
    // Calculate reminder time (e.g., 24 hours before deadline)
    final reminderTime = deadline.subtract(const Duration(hours: 24));

    // Only schedule if reminder time is in the future
    if (reminderTime.isAfter(DateTime.now())) {
      // Store reminder in Firestore for Cloud Function to process
      await FirebaseFirestore.instance.collection('scheduledNotifications').add({
        'type': 'deadline_reminder',
        'assessmentId': assessmentId,
        'classId': classId,
        'assessmentTitle': assessmentTitle,
        'deadline': Timestamp.fromDate(deadline),
        'scheduledFor': Timestamp.fromDate(reminderTime),
        'message': 'Reminder: "$assessmentTitle" is due in 24 hours!',
        'className': className,
        'link': '/student/class/$classId',
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      debugPrint('✅ Deadline reminder scheduled for: $reminderTime');
    }
  } catch (e) {
    debugPrint('❌ Error scheduling deadline reminder: $e');
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
