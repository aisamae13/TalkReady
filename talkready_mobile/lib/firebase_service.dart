import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'modules_config.dart'; // Ensure this provides courseConfig

class FirebaseService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveSpecificLessonAttempt({
    required String lessonIdKey, // This will be "Lesson 1.1"
    required int score,
    required int
        attemptNumberToSave, // The actual attempt number (e.g., 1, 2, 3...)
    required int timeSpent,
    // For Lesson 1.1, detailedResponses is null as per web version.
    // If other lessons need it, this parameter can be expanded.
  }) async {
    final uId =
        userId; // Assumes 'userId' getter is available: String? get userId => _auth.currentUser?.uid;
    if (uId == null) {
      _logger.e(
          'User not authenticated to save specific lesson attempt for $lessonIdKey.');
      throw Exception('User not authenticated');
    }

    _logger.i(
        'Saving specific attempt for Lesson: $lessonIdKey, User: $uId, Attempt: $attemptNumberToSave, Score: $score, TimeSpent: $timeSpent s');

    final userProgressDocRef = _firestore.collection('userProgress').doc(uId);

    try {
      // Create the new attempt data map based on the web version's structure
      final newAttemptData = {
        'attemptNumber': attemptNumberToSave,
        'attemptTimestamp':
            Timestamp.now(), // Firestore timestamp for current time
        'detailedResponses': null, // null for Lesson 1.1
        'lessonId': lessonIdKey, // e.g., "Lesson 1.1"
        'score': score,
        'timeSpent': timeSpent,
      };

      // Using a transaction for robust read-modify-write.
      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(userProgressDocRef);

        Map<String, dynamic> dataToWrite = {};
        Map<String, dynamic> lessonAttemptsMap;
        List<dynamic> specificLessonAttemptsArray;

        if (docSnapshot.exists) {
          final existingData = docSnapshot.data() as Map<String, dynamic>;
          dataToWrite = {
            ...existingData
          }; // Start with existing data to preserve other fields

          lessonAttemptsMap = Map<String, dynamic>.from(
              existingData['lessonAttempts'] as Map? ?? {});

          specificLessonAttemptsArray =
              List<dynamic>.from(lessonAttemptsMap[lessonIdKey] as List? ?? []);
        } else {
          // Document doesn't exist, initialize everything
          dataToWrite['createdAt'] = FieldValue.serverTimestamp();
          lessonAttemptsMap = {};
          specificLessonAttemptsArray = [];
        }

        specificLessonAttemptsArray.add(newAttemptData);
        lessonAttemptsMap[lessonIdKey] = specificLessonAttemptsArray;

        dataToWrite['lessonAttempts'] = lessonAttemptsMap;
        dataToWrite['lastActivityTimestamp'] = FieldValue.serverTimestamp();

        if (docSnapshot.exists) {
          transaction.update(userProgressDocRef, dataToWrite);
        } else {
          transaction.set(userProgressDocRef, dataToWrite);
        }
      });

      _logger.i(
          'Successfully saved attempt $attemptNumberToSave for lesson "$lessonIdKey" for user $uId.');
    } catch (e) {
      _logger.e(
          'Error saving specific lesson attempt for "$lessonIdKey", User $uId: $e');
      rethrow;
    }
  }

  String? get userId => _auth.currentUser?.uid;

  Future<void> initializeUserProgress(String userId) async {
    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);
      final userSnapshot = await userDocRef.get();

      Map<String, dynamic> initialProgressData = {};
      if (!userSnapshot.exists) {
        initialProgressData['createdAt'] = FieldValue.serverTimestamp();
      }

      final modulesSnapshot = await _firestore.collection('courses').get();
      bool needsUpdate = false;

      for (var courseDoc in modulesSnapshot.docs) {
        final moduleId = courseDoc.id;
        if (!userSnapshot.exists || (userSnapshot.data())?[moduleId] == null) {
          final courseData = courseDoc.data();

          List<String> lessonKeysToUse = [];
          final config = courseConfig[moduleId];
          if (config != null &&
              config['lessons'] is List &&
              (config['lessons'] as List).every((item) => item is String)) {
            lessonKeysToUse = List<String>.from(config['lessons']);
            _logger.i(
                "InitializeUserProgress for $moduleId: Using lesson keys from courseConfig: $lessonKeysToUse");
          } else {
            _logger.w(
                "InitializeUserProgress for $moduleId: Lesson keys not found or invalid in courseConfig. Falling back to 'courses' doc.");
            var lessonsFromDocRaw = courseData['lessons'];
            if (lessonsFromDocRaw is List &&
                lessonsFromDocRaw.every((item) => item is String)) {
              lessonKeysToUse =
                  List<String>.from(lessonsFromDocRaw.cast<String>());
              _logger.i(
                  "InitializeUserProgress for $moduleId: Using lesson keys from 'courses' doc: $lessonKeysToUse");
            } else {
              _logger.e(
                  "CRITICAL: InitializeUserProgress for $moduleId: Lesson keys are not a List<String> in 'courses' doc either. Defaulting to empty. Module progress may be incorrect.");
              if (moduleId == 'module1') {
                // Last resort for module1
                lessonKeysToUse = ['lesson1', 'lesson2', 'lesson3'];
                _logger.w(
                    "InitializeUserProgress for $moduleId: Using hardcoded default lesson keys: $lessonKeysToUse");
              }
            }
          }

          final lessonsMap = {for (var key in lessonKeysToUse) key: false};
          final attemptsMap = {
            for (var key in lessonKeysToUse) key: 0
          }; // Initialize attempts

          initialProgressData[moduleId] = {
            'isCompleted': false,
            'lessons': lessonsMap,
            'attempts': attemptsMap, // Add attempts map
            'activityLogs': [],
            'isUnlocked': moduleId == 'module1',
            'unlockedAt':
                moduleId == 'module1' ? FieldValue.serverTimestamp() : null,
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          needsUpdate = true;
        }
      }

      if (needsUpdate || !userSnapshot.exists) {
        if (userSnapshot.exists) {
          await userDocRef.update(initialProgressData);
        } else {
          await userDocRef.set(initialProgressData);
        }
        _logger.i(
            'Initialized/Updated progress for user $userId with lesson keys derived prioritizing courseConfig.');
      } else {
        _logger.i('User progress already up-to-date for user $userId');
      }
    } catch (e) {
      _logger.e('Error initializing user progress: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getModuleProgress(String moduleId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('No authenticated user');
      throw Exception('User not authenticated');
    }
    final userId = user.uid;
    _logger.i('Fetching progress for user: $userId, module: $moduleId');
    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);
      final doc = await userDocRef.get();

      if (doc.exists && doc.data() != null) {
        final userData = doc.data() as Map<String, dynamic>;
        if (userData.containsKey(moduleId) && userData[moduleId] is Map) {
          final moduleData =
              Map<String, dynamic>.from(userData[moduleId] as Map);
          moduleData['activityLogs'] =
              List<Map<String, dynamic>>.from(moduleData['activityLogs'] ?? []);
          moduleData['lessons'] =
              Map<String, bool>.from(moduleData['lessons'] as Map? ?? {});
          moduleData['attempts'] =
              Map<String, int>.from(moduleData['attempts'] as Map? ?? {});
          _logger.d('Module $moduleId progress: $moduleData');
          return moduleData;
        }
      }

      _logger.w(
          'No progress data found for module $moduleId and user $userId, creating default');

      List<String> lessonKeysToUse = [];
      final config = courseConfig[moduleId];

      if (config != null &&
          config['lessons'] is List &&
          (config['lessons'] as List).every((item) => item is String)) {
        lessonKeysToUse = List<String>.from(config['lessons']);
        _logger.i(
            "Default progress for $moduleId: using lesson keys from courseConfig: $lessonKeysToUse");
      } else {
        _logger.w(
            "Default progress for $moduleId: lesson keys not found/invalid in courseConfig. Fetching from 'courses' doc.");
        final courseDocSnapshot =
            await _firestore.collection('courses').doc(moduleId).get();
        final courseData = courseDocSnapshot.data();
        var lessonsFromDocRaw = courseData?['lessons'];
        if (lessonsFromDocRaw is List &&
            lessonsFromDocRaw.every((item) => item is String)) {
          lessonKeysToUse = List<String>.from(lessonsFromDocRaw.cast<String>());
          _logger.i(
              "Default progress for $moduleId: using lesson keys from 'courses' doc: $lessonKeysToUse");
        } else {
          _logger.e(
              "CRITICAL: Default progress for $moduleId: lesson keys are not List<String> in 'courses' doc. Module progress may be incorrect.");
          if (moduleId == 'module1') {
            // Last resort for module1
            lessonKeysToUse = ['lesson1', 'lesson2', 'lesson3'];
            _logger.w(
                "Default progress for $moduleId: Using hardcoded default lesson keys: $lessonKeysToUse");
          }
        }
      }

      if (lessonKeysToUse.isEmpty &&
          !(moduleId == 'module1' && config == null)) {
        _logger.e(
            "CRITICAL: No lesson keys could be determined for $moduleId to create default progress. Returning minimal structure.");
        final minimalData = {
          'isCompleted': false,
          'lessons': <String, bool>{},
          'attempts': <String, int>{},
          'activityLogs': [],
          'isUnlocked': moduleId == 'module1'
        };
        await userDocRef.set({moduleId: minimalData}, SetOptions(merge: true));
        return minimalData;
      }

      final lessons = {for (var key in lessonKeysToUse) key: false};
      final attempts = {for (var key in lessonKeysToUse) key: 0};

      final defaultModuleData = {
        'isCompleted': false,
        'lessons': lessons,
        'attempts': attempts,
        'activityLogs': [],
        'isUnlocked': moduleId == 'module1',
        'unlockedAt':
            moduleId == 'module1' ? FieldValue.serverTimestamp() : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await userDocRef
          .set({moduleId: defaultModuleData}, SetOptions(merge: true));

      _logger.d(
          'Created default progress data for module $moduleId and user $userId, prioritizing courseConfig for keys.');
      return defaultModuleData;
    } catch (e) {
      _logger.e('Error fetching module progress for $moduleId: $e');
      rethrow;
    }
  }

  Future<void> updateLessonProgress(
      String moduleId, String lessonId, bool completed,
      {Map<String, int>? attempts}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final userId = user.uid;
    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);

      Map<String, dynamic> dataToUpdate = {
        '$moduleId.lessons.$lessonId': completed,
        '$moduleId.lastUpdated': FieldValue.serverTimestamp(),
      };

      if (attempts != null) {
        dataToUpdate['$moduleId.attempts'] = attempts;
      }

      await userDocRef.update(dataToUpdate);

      final doc = await userDocRef.get();
      if (!doc.exists || doc.data() == null) {
        _logger.e('User document not found for $userId after lesson update.');
        return;
      }
      final userData = doc.data() as Map<String, dynamic>;
      final moduleData = userData[moduleId] as Map<String, dynamic>?;

      if (moduleData == null || moduleData['lessons'] == null) {
        _logger.e(
            'Module data or lessons not found for $moduleId in user $userId for completion check.');
        return;
      }

      final lessonsInProgressMap =
          Map<String, bool>.from(moduleData['lessons'] as Map? ?? {});
      _logger.i(
          'Checking allCompleted for $moduleId. Lessons map from Firestore userProgress: $lessonsInProgressMap');

      List<String> actualLessonKeysForCompletion = [];
      final config = courseConfig[moduleId];
      if (config != null &&
          config['lessons'] is List &&
          (config['lessons'] as List).every((item) => item is String)) {
        actualLessonKeysForCompletion = List<String>.from(config['lessons']);
        _logger.i(
            "UpdateLessonProgress for $moduleId: Using lesson keys from courseConfig for completion check: $actualLessonKeysForCompletion");
      } else {
        _logger.w(
            "UpdateLessonProgress for $moduleId: Lesson keys not found/invalid in local courseConfig. Fetching from 'courses/$moduleId'.");
        final courseDocSnapshot =
            await _firestore.collection('courses').doc(moduleId).get();
        final courseData = courseDocSnapshot.data();
        var lessonsFromDocRaw = courseData?['lessons'];
        if (lessonsFromDocRaw is List &&
            lessonsFromDocRaw.every((item) => item is String)) {
          actualLessonKeysForCompletion =
              List<String>.from(lessonsFromDocRaw.cast<String>());
          _logger.i(
              "UpdateLessonProgress for $moduleId: Using lesson keys from 'courses' doc for completion check: $actualLessonKeysForCompletion");
        } else {
          _logger.e(
              "CRITICAL: UpdateLessonProgress for $moduleId: Lesson keys are not List<String> in 'courses' doc.");
        }
      }

      if (actualLessonKeysForCompletion.isEmpty) {
        final potentialKeys = lessonsInProgressMap.keys
            .where((k) => RegExp(r'^lesson\d+$').hasMatch(k))
            .toList();
        if (potentialKeys.isNotEmpty) {
          _logger.w(
              "CRITICAL: No lesson keys defined for $moduleId in config/courses. Inferring from user progress: $potentialKeys. This may be inaccurate.");
          actualLessonKeysForCompletion = potentialKeys;
        } else if (moduleId == 'module1') {
          _logger.w(
              "CRITICAL: No lesson keys for module1 and user progress is empty/no standard keys. Using hardcoded default lesson keys for module1 completion check: [lesson1, lesson2, lesson3]");
          actualLessonKeysForCompletion = ['lesson1', 'lesson2', 'lesson3'];
        } else {
          _logger.e(
              'CRITICAL: No lesson keys defined for $moduleId in config/courses collection, and no inferable keys in user progress. Cannot accurately determine module completion. Defaulting isCompleted to false.');
          await userDocRef.update({'$moduleId.isCompleted': false});
          return;
        }
      }

      bool allRequiredLessonsCompleted =
          actualLessonKeysForCompletion.isNotEmpty &&
              actualLessonKeysForCompletion
                  .every((key) => lessonsInProgressMap[key] == true);
      _logger.i(
          'For $moduleId, required lesson keys for completion: $actualLessonKeysForCompletion. Status of these keys in user progress: ${actualLessonKeysForCompletion.map((k) => '$k: ${lessonsInProgressMap[k] ?? 'missing'}').join(', ')}. Overall moduleCompleted: $allRequiredLessonsCompleted');

      await userDocRef
          .update({'$moduleId.isCompleted': allRequiredLessonsCompleted});

      _logger.i(
          'Updated lesson $lessonId in module $moduleId: completed=$completed, moduleIsCompleted=$allRequiredLessonsCompleted for user $userId. Attempts map: $attempts');
    } catch (e) {
      _logger.e('Error updating lesson progress for $moduleId/$lessonId: $e');
      rethrow;
    }
  }

  Future<void> logLessonActivity(
    String moduleId,
    String lessonTitleForLog,
    int attemptNumber,
    int score,
    int totalScore,
    int timeSpent,
    List<Map<String, dynamic>>? detailedResponses,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final userId = user.uid;
    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);
      final logEntry = {
        'moduleId': moduleId,
        'lessonId': lessonTitleForLog,
        'attemptNumber': attemptNumber,
        'attemptTimestamp': Timestamp.now(),
        'detailedResponses': detailedResponses ?? [],
        'score': score,
        'totalScore': totalScore,
        'timeSpent': timeSpent,
      };

      await userDocRef.update({
        '$moduleId.activityLogs': FieldValue.arrayUnion([logEntry])
      });
      _logger.i(
          'Logged activity for $lessonTitleForLog in $moduleId, attempt $attemptNumber for user $userId');
    } catch (e) {
      _logger
          .e('Error logging activity for $lessonTitleForLog in $moduleId: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getActivityLogs(
      String moduleId, String lessonTitleForLog) async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('User not authenticated for getActivityLogs');
      throw Exception('User not authenticated');
    }
    final userId = user.uid;
    List<Map<String, dynamic>> logs = [];

    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);
      final docSnapshot = await userDocRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data[moduleId] is Map) {
          final moduleData = data[moduleId] as Map<String, dynamic>;
          if (moduleData['activityLogs'] is List) {
            final allLogsForModule =
                List<Map<String, dynamic>>.from(moduleData['activityLogs']);
            // Filter logs for the specific lessonTitleForLog
            logs = allLogsForModule
                .where((log) => log['lessonId'] == lessonTitleForLog)
                .toList();

            // Sort by attemptTimestamp if it exists, most recent first
            logs.sort((a, b) {
              final timestampA = a['attemptTimestamp'];
              final timestampB = b['attemptTimestamp'];
              if (timestampA is Timestamp && timestampB is Timestamp) {
                return timestampB.compareTo(timestampA); // Descending
              }
              return 0;
            });
          }
        }
      }
      _logger.i(
          'Fetched ${logs.length} activity logs for $moduleId - $lessonTitleForLog');
      return logs;
    } catch (e) {
      _logger.e(
          'Error fetching activity logs for $moduleId - $lessonTitleForLog: $e');
      rethrow;
    }
  }

  Future<void> unlockModule(String moduleId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final userId = user.uid;
    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);

      Map<String, dynamic> moduleUpdateData = {
        '$moduleId.isUnlocked': true,
        '$moduleId.unlockedAt': FieldValue.serverTimestamp(),
        '$moduleId.lastUpdated': FieldValue.serverTimestamp(),
      };

      final doc = await userDocRef.get();
      bool moduleExists = doc.exists &&
          (doc.data() as Map<String, dynamic>).containsKey(moduleId);

      if (!moduleExists) {
        List<String> lessonKeysForNewModule = [];
        final config = courseConfig[moduleId];
        if (config != null &&
            config['lessons'] is List &&
            (config['lessons'] as List).every((item) => item is String)) {
          lessonKeysForNewModule = List<String>.from(config['lessons']);
          _logger.i(
              "UnlockModule (new) for $moduleId: using lesson keys from courseConfig: $lessonKeysForNewModule");
        } else {
          _logger.w(
              "UnlockModule (new) for $moduleId: lesson keys not found/invalid in courseConfig. Fetching from 'courses' doc.");
          final courseDocSnapshot =
              await _firestore.collection('courses').doc(moduleId).get();
          final courseData = courseDocSnapshot.data();
          var lessonsFromDocRaw = courseData?['lessons'];
          if (lessonsFromDocRaw is List &&
              lessonsFromDocRaw.every((item) => item is String)) {
            lessonKeysForNewModule =
                List<String>.from(lessonsFromDocRaw.cast<String>());
            _logger.i(
                "UnlockModule (new) for $moduleId: using lesson keys from 'courses' doc: $lessonKeysForNewModule");
          } else {
            _logger.e(
                "CRITICAL: UnlockModule (new) for $moduleId: lesson keys are not List<String> in 'courses' doc. Module progress may be incorrect.");
            if (moduleId == 'module1') {
              lessonKeysForNewModule = ['lesson1', 'lesson2', 'lesson3'];
              _logger.w(
                  "UnlockModule (new) for $moduleId: Using hardcoded default lesson keys: $lessonKeysForNewModule");
            }
          }
        }

        if (lessonKeysForNewModule.isEmpty &&
            !(moduleId == 'module1' && config == null)) {
          _logger.e(
              "CRITICAL: No lesson keys could be determined for new module $moduleId. It will be created with an empty lessons map.");
        }

        final lessons = {for (var key in lessonKeysForNewModule) key: false};
        final attempts = {for (var key in lessonKeysForNewModule) key: 0};

        await userDocRef.set({
          moduleId: {
            'isUnlocked': true,
            'unlockedAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
            'lessons': lessons,
            'attempts': attempts,
            'activityLogs': [],
            'isCompleted': false,
          }
        }, SetOptions(merge: true));
        _logger.i(
            'Module $moduleId created and unlocked for user $userId with lessons: $lessons and attempts: $attempts');
      } else {
        await userDocRef.update(moduleUpdateData);
        _logger.i('Module $moduleId unlocked for user $userId');
      }
    } catch (e) {
      _logger.e('Error unlocking module $moduleId: $e');
      rethrow;
    }
  }
}