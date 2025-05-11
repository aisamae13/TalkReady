import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class FirebaseService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  Future<void> initializeUserProgress(String userId) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final snapshot = await userDoc.get();
      if (!snapshot.exists) {
        await userDoc.set({'createdAt': FieldValue.serverTimestamp()});
        await userDoc.collection('progress').doc('module1').set({
          'isCompleted': false,
          'lessons': {
            'lesson1': false,
            'lesson2': false,
            'lesson3': false,
          },
        });
        _logger.i('Initialized progress for user $userId');
      }
    } catch (e) {
      _logger.e('Error initializing user progress: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getModuleProgress(String moduleId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger.e('No authenticated user');
      throw Exception('User not authenticated');
    }
    _logger.i('Fetching progress for user: ${user.uid}, module: $moduleId');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc(moduleId)
          .get();
      return doc.data() ?? {};
    } catch (e) {
      _logger.e('Error fetching module progress for $moduleId: $e');
      rethrow;
    }
  }

  Future<void> updateLessonProgress(String moduleId, String lessonId, bool completed) async {
    try {
      if (userId == null) throw Exception('User not authenticated');
      final moduleRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc(moduleId);
      await moduleRef.set({
        'lessons': {lessonId: completed},
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Check if all lessons are completed
      final doc = await moduleRef.get();
      final lessons = doc.data()?['lessons'] as Map<String, dynamic>? ?? {};
      final allCompleted = lessons.values.every((v) => v == true);
      await moduleRef.update({'isCompleted': allCompleted});
      _logger.i('Updated lesson $lessonId in module $moduleId: completed=$completed, moduleCompleted=$allCompleted');
    } catch (e) {
      _logger.e('Error updating lesson progress for $moduleId/$lessonId: $e');
      rethrow;
    }
  }
}