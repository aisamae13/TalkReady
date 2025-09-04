import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'modules_config.dart'; // Ensure this provides courseConfig
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveSpecificLessonAttempt({
    required String lessonIdKey, // e.g., "Lesson 4.1", "Lesson 4.2"
    required int score, // Overall score for this attempt
    required int attemptNumberToSave, // The actual attempt number (1, 2, 3...)
    required int timeSpent, // Can be -1 or null for reflection-only updates
    Map<String, dynamic>? detailedResponsesPayload,
    bool isUpdate = false, // New parameter
  }) async {
    final uId = userId;
    if (uId == null) {
      _logger
          .e('User not authenticated for saving lesson attempt: $lessonIdKey.');
      throw Exception('User not authenticated');
    }

    _logger.i(
        'Saving attempt for Lesson: $lessonIdKey, User: $uId, Attempt: $attemptNumberToSave, Score: $score, IsUpdate: $isUpdate');
    if (detailedResponsesPayload != null) {
      // _logger.d('Detailed Payload: ${jsonEncode(detailedResponsesPayload)}'); // Can be verbose
    }

    final userProgressDocRef = _firestore.collection('userProgress').doc(uId);

    try {
      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(userProgressDocRef);

        Map<String, dynamic> dataToWrite =
            {}; // Data for the entire userProgress doc
        Map<String, dynamic>
            lessonAttemptsMap; // Holds all attempts for all lessons
        List<dynamic>
            specificLessonAttemptsArray; // Array of attempts for the current lessonIdKey

        if (docSnapshot.exists) {
          final existingData = docSnapshot.data() as Map<String, dynamic>;
          dataToWrite = {...existingData}; // Preserve other module data
          lessonAttemptsMap = Map<String, dynamic>.from(
              existingData['lessonAttempts'] as Map? ?? {});
          specificLessonAttemptsArray =
              List<dynamic>.from(lessonAttemptsMap[lessonIdKey] as List? ?? []);
        } else {
          dataToWrite['createdAt'] = FieldValue.serverTimestamp();
          lessonAttemptsMap = {};
          specificLessonAttemptsArray = [];
        }

        if (isUpdate) {
          // Find and update the existing attempt
          int attemptIndex = specificLessonAttemptsArray.indexWhere((att) =>
              att is Map && att['attemptNumber'] == attemptNumberToSave);

          if (attemptIndex != -1) {
            Map<String, dynamic> existingAttempt = Map<String, dynamic>.from(
                specificLessonAttemptsArray[attemptIndex]);

            // Merge new detailedResponses. If reflections are the only thing changing,
            // the payload should reflect that.
            existingAttempt['detailedResponses'] = {
              ...(existingAttempt['detailedResponses'] as Map? ??
                  {}), // Keep old details
              ...(detailedResponsesPayload ??
                  {}), // Overwrite/add new details (e.g., new reflections)
            };
            // Optionally update a 'lastUpdatedTimestamp' within the attempt itself
            existingAttempt['lastUpdatedTimestampInAttempt'] =
                FieldValue.serverTimestamp();

            specificLessonAttemptsArray[attemptIndex] = existingAttempt;
            _logger.i(
                'Updated attempt $attemptNumberToSave for lesson "$lessonIdKey"');
          } else {
            _logger.w(
                'Attempt $attemptNumberToSave for lesson "$lessonIdKey" not found for update. No changes made to this attempt.');
            // Decide if you want to throw an error or just log
            // throw Exception('Attempt to update non-existent attempt $attemptNumberToSave for $lessonIdKey');
            return; // Exit transaction if specific attempt to update is not found
          }
        } else {
          // New attempt
          final newAttemptData = {
            'attemptNumber': attemptNumberToSave,
            'attemptTimestamp': Timestamp.now(),
            'detailedResponses':
                detailedResponsesPayload, // Contains scenario/solution responses, AI feedback, reflections
            'lessonId': lessonIdKey,
            'score': score, // Overall score for this attempt
            'timeSpent': timeSpent,
          };
          specificLessonAttemptsArray.add(newAttemptData);
          _logger.i(
              'Added new attempt $attemptNumberToSave for lesson "$lessonIdKey"');
        }

        lessonAttemptsMap[lessonIdKey] = specificLessonAttemptsArray;
        dataToWrite['lessonAttempts'] = lessonAttemptsMap;
        dataToWrite['lastActivityTimestamp'] =
            FieldValue.serverTimestamp(); // General activity update

        if (docSnapshot.exists) {
          transaction.update(userProgressDocRef, dataToWrite);
        } else {
          transaction.set(userProgressDocRef, dataToWrite);
        }
      });

      _logger.i(
          'Successfully ${isUpdate ? "updated" : "saved new"} attempt $attemptNumberToSave for lesson "$lessonIdKey" for user $uId.');
    } catch (e) {
      _logger.e(
          'Error ${isUpdate ? "updating" : "saving new"} lesson attempt for "$lessonIdKey", User $uId: $e');
      rethrow;
    }
  }

  String? get userId => _auth.currentUser?.uid;

  get getLessonDocument => null;

  // NEW METHOD: Upload user audio for a lesson prompt
  Future<String?> uploadLessonAudio(
      String localFilePath, String lessonIdKey, String promptId) async {
    final uId = userId;
    if (uId == null) {
      _logger.e('User not authenticated for audio upload.');
      throw Exception('User not authenticated');
    }
    if (localFilePath.isEmpty) {
      _logger.e("Local file path is empty for lesson audio upload.");
      return null;
    }

    File audioFile = File(localFilePath);
    if (!await audioFile.exists()) {
      _logger.e(
          "Local audio file does not exist at path: $localFilePath for lesson audio upload.");
      return null;
    }

    // Define a storage path, e.g., userLessonAudio/{userId}/{lessonIdKey}/{promptId}/{timestamp_filename}
    String fileName = localFilePath.split('/').last;
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String storagePath =
        'userLessonAudio/$uId/$lessonIdKey/$promptId/${timestamp}_$fileName';

    _logger.i(
        "Attempting to upload lesson audio to Firebase Storage: $storagePath");

    try {
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask = storageRef.putFile(audioFile);

      // You can listen to task events for progress if needed:
      // uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      //   _logger.d('Upload is ${snapshot.bytesTransferred / snapshot.totalBytes * 100}% complete.');
      // }, onError: (e) {
      //   _logger.e('Upload task error: $e');
      // });

      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      _logger
          .i("Firebase Storage Upload Successful! Download URL: $downloadUrl");
      return downloadUrl;
    } on FirebaseException catch (e) {
      _logger.e(
          "Firebase Storage Upload FirebaseException: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      _logger.e("Firebase Storage Upload General Exception: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLessonContent(
      String lessonDocumentId) async {
    if (lessonDocumentId.isEmpty) {
      _logger.w('Lesson document ID is empty. Cannot fetch content.');
      return null;
    }
    try {
      _logger.i(
          'Fetching content for lesson document: $lessonDocumentId from "lessons" collection.');
      final lessonDocRef = _firestore
          .collection('lessons')
          .doc(lessonDocumentId); // Ensure 'lessons' is your collection name
      final docSnapshot = await lessonDocRef.get();

      if (docSnapshot.exists) {
        _logger.d(
            'Lesson content found for $lessonDocumentId: ${docSnapshot.data()}');
        return docSnapshot.data();
      } else {
        _logger.w(
            'Lesson document "$lessonDocumentId" not found in "lessons" collection.');
        return null;
      }
    } catch (e) {
      _logger.e('Error fetching lesson content for "$lessonDocumentId": $e');
      // Depending on how you want to handle errors, you might rethrow or return null
      // For now, returning null so the UI can handle it (e.g., show "failed to load").
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfileById(String userId) async {
    if (userId.isEmpty) {
      _logger.w("User ID is missing for getUserProfileById");
      return null;
    }
    try {
      final userDocRef = _firestore.collection("users").doc(userId);
      final docSnap = await userDocRef.get();
      if (docSnap.exists) {
        return {'uid': docSnap.id, ...(docSnap.data() as Map<String, dynamic>)};
      } else {
        _logger.w("User profile not found for ID: $userId");
        return null;
      }
    } catch (e) {
      _logger.e("Error getting user profile for $userId: $e");
      return null; // Rethrow or return null based on how you want to handle
    }
  }

  Future<Map<String, dynamic>?> getClassDetails(String classId) async {
    if (classId.isEmpty) {
      _logger.w("Class ID is missing for getClassDetails");
      return null;
    }
    _logger.i("Fetching class details for classId: $classId");
    try {
      final classRef = _firestore.collection("trainerClass").doc(classId);
      final docSnap = await classRef.get();
      if (docSnap.exists) {
        return {'id': docSnap.id, ...(docSnap.data() as Map<String, dynamic>)};
      } else {
        _logger.w("Class with ID $classId not found.");
        return null; // Or throw Exception("Class not found");
      }
    } catch (e) {
      _logger.e("Error fetching class details for $classId: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAssessmentDetails(
      String assessmentId) async {
    if (assessmentId.isEmpty) {
      _logger.w("Assessment ID is missing for getAssessmentDetails");
      return null;
    }
    _logger.i("Fetching assessment details for assessmentId: $assessmentId");
    try {
      final assessmentRef =
          _firestore.collection("trainerAssessments").doc(assessmentId);
      final docSnap = await assessmentRef.get();
      if (docSnap.exists) {
        return {'id': docSnap.id, ...(docSnap.data() as Map<String, dynamic>)};
      } else {
        _logger.w("Assessment with ID $assessmentId not found.");
        return null; // Or throw Exception("Assessment not found");
      }
    } catch (e) {
      _logger.e("Error fetching assessment details for $assessmentId: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStudentSubmissionDetails(
      String submissionId) async {
    if (submissionId.isEmpty) {
      _logger.w("Submission ID is missing for getStudentSubmissionDetails");
      return null;
    }
    _logger.i("Fetching submission details for submissionId: $submissionId");
    try {
      final submissionRef =
          _firestore.collection("studentSubmissions").doc(submissionId);
      final docSnap = await submissionRef.get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        // Convert Timestamp to DateTime if present
        if (data['submittedAt'] is Timestamp) {
          data['submittedAt'] = (data['submittedAt'] as Timestamp).toDate();
        }
        return {'id': docSnap.id, ...data};
      } else {
        _logger.w("Submission with ID $submissionId not found.");
        return null;
      }
    } catch (e) {
      _logger.e("Error fetching submission details for $submissionId: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentSubmissionsWithDetails(
      String studentId) async {
    if (studentId.isEmpty) {
      _logger.w("Student ID is missing for getStudentSubmissionsWithDetails.");
      return [];
    }
    _logger.i("Fetching submissions with details for studentId: $studentId");
    final submissionsRef = _firestore.collection("studentSubmissions");
    final submissionsQuery = submissionsRef
        .where("studentId", isEqualTo: studentId)
        .orderBy("submittedAt", descending: true);

    try {
      final querySnapshot = await submissionsQuery.get();
      if (querySnapshot.docs.isEmpty) {
        _logger.i("No submissions found for student $studentId.");
        return [];
      }

      List<Map<String, dynamic>> submissionsWithDetails = [];

      for (var submissionDoc in querySnapshot.docs) {
        Map<String, dynamic> submissionData = {
          'id': submissionDoc.id,
          ...(submissionDoc.data())
        };
        if (submissionData['submittedAt'] is Timestamp) {
          submissionData['submittedAt'] =
              (submissionData['submittedAt'] as Timestamp).toDate();
        }

        String assessmentTitle = "Assessment Title Not Found";
        String className = "Class Name Not Found";
        String trainerName = "Trainer Name Not Found";
        String? originalAssessmentTrainerId;

        if (submissionData['assessmentId'] != null) {
          try {
            final assessmentDetails =
                await getAssessmentDetails(submissionData['assessmentId']);
            if (assessmentDetails != null) {
              assessmentTitle =
                  assessmentDetails['title'] ?? "Untitled Assessment";
              originalAssessmentTrainerId = assessmentDetails['trainerId'];

              if (assessmentDetails['classId'] != null) {
                final classDetails =
                    await getClassDetails(assessmentDetails['classId']);
                if (classDetails != null) {
                  className = classDetails['className'] ?? "Unnamed Class";
                  if (classDetails['trainerId'] != null) {
                    final trainerProfile =
                        await getUserProfileById(classDetails['trainerId']);
                    if (trainerProfile != null) {
                      trainerName = trainerProfile['displayName'] ??
                          "${trainerProfile['firstName'] ?? ''} ${trainerProfile['lastName'] ?? ''}"
                              .trim();
                      if (trainerName.isEmpty) trainerName = "Unknown Trainer";
                    }
                  }
                }
              }
            }
          } catch (e) {
            _logger.w(
                "Could not fetch full details for assessmentId ${submissionData['assessmentId']}: $e");
          }
        }
        submissionsWithDetails.add({
          ...submissionData,
          'assessmentTitle': assessmentTitle,
          'className': className,
          'trainerName': trainerName,
        });
      }
      _logger.i(
          "Fetched ${submissionsWithDetails.length} submissions with details for student $studentId.");
      return submissionsWithDetails;
    } catch (e) {
      _logger.e("Error fetching student submissions with details: $e");
      if (e is FirebaseException &&
          e.code == 'failed-precondition' &&
          e.message!.contains("index")) {
        _logger.e(
            "Firestore query requires an index on 'studentSubmissions' for 'studentId' and 'submittedAt'. Please create it. The error message might contain a direct link.");
        // Depending on your app's error handling, you might want to throw a more user-friendly error here.
      }
      return []; // Return empty on error
    }
  }

  Future<void> sendTrainerNotification(
      String trainerId,
      String studentName,
      String assessmentTitle,
      String submissionId,
      String assessmentId,
      String? classId,
      String? className) async {
    if (trainerId.isEmpty) {
      _logger.w("Trainer ID missing, cannot send notification.");
      return;
    }
    try {
      final notificationData = {
        'userId': trainerId, // The trainer to notify
        'message':
            "$studentName has shared their results for the assessment: \"$assessmentTitle\".",
        'link':
            "/student/submission/$submissionId/review?assessmentId=$assessmentId", // Adjust if your trainer link is different
        'type': "assessment_result_shared",
        'classId': classId ??
            FieldValue
                .delete(), // Use FieldValue.delete() if classId is null to remove the field
        'className': className ?? FieldValue.delete(),
        'relatedDocId': submissionId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection("notifications").add(notificationData);
      _logger.i(
          "Notification sent to trainer $trainerId for submission $submissionId.");
    } catch (e) {
      _logger.e("Error sending notification to trainer $trainerId: $e");
    }
  }

  Future<void> initializeUserProgress(String userId) async {
    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);
      final userSnapshot = await userDocRef.get();

      Map<String, dynamic> dataToInitialize = {}; // Changed name for clarity
      bool needsUpdate = false;

      if (!userSnapshot.exists) {
        dataToInitialize['createdAt'] = FieldValue.serverTimestamp();
        needsUpdate = true; // Will definitely need to set the document
      }

      for (var entry in courseConfig.entries) {
        // Iterate over courseConfig
        final moduleId = entry.key;
        final moduleSpecificConfig = entry.value;

        // Check if this module's structure needs to be initialized or is missing
        if (!userSnapshot.exists || (userSnapshot.data())?[moduleId] == null) {
          needsUpdate = true;
          List<String> lessonKeysToUse =
              List<String>.from(moduleSpecificConfig['lessons'] as List? ?? []);

          if (lessonKeysToUse.isEmpty) {
            _logger.e(
                "CRITICAL: InitializeUserProgress for $moduleId: No lesson keys found in courseConfig. Module progress might be incorrect.");
            // Define a hardcoded fallback if absolutely necessary, e.g.
            if (moduleId == 'module5') {
              lessonKeysToUse = ['lesson1', 'lesson2'];
            } else if (moduleId == 'module1')
              lessonKeysToUse = ['lesson1', 'lesson2', 'lesson3'];
            // Add other fallbacks based on your modules_config.dart
          }

          final lessonsMap = {for (var key in lessonKeysToUse) key: false};
          final attemptsMapForActivityLog = {
            for (var key in lessonKeysToUse) key: 0
          };

          dataToInitialize[moduleId] = {
            'isCompleted': false,
            'lessons': lessonsMap,
            'activityLogs': {
              // CORRECTED: Nested structure for attempts
              'attempts': attemptsMapForActivityLog
            },
            // 'detailedLogEntries': [], // If you want a separate array for detailed logs from logLessonActivity
            'isUnlocked': moduleId ==
                'module1', // Example: module1 is unlocked by default
            'unlockedAt':
                moduleId == 'module1' ? FieldValue.serverTimestamp() : null,
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          _logger.i(
              "Prepared initial data for $moduleId: ${dataToInitialize[moduleId]}");
        }
      }

      if (needsUpdate) {
        if (userSnapshot.exists) {
          await userDocRef
              .update(dataToInitialize); // Update existing doc with new modules
          _logger.i(
              'Updated progress for user $userId with new module structures.');
        } else {
          await userDocRef
              .set(dataToInitialize); // Set new doc if it didn't exist
          _logger.i('Initialized new progress document for user $userId.');
        }
      } else {
        _logger.i(
            'User progress already up-to-date for user $userId, no initialization needed.');
      }
    } catch (e, s) {
      _logger.e('Error initializing user progress: $e\n$s');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getModuleProgress(String moduleId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('No authenticated user for getModuleProgress');
      throw Exception('User not authenticated');
    }
    final userId = user.uid;
    _logger.i('Fetching progress for user: $userId, module: $moduleId');

    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);
      final docSnap = await userDocRef.get();

      if (docSnap.exists && docSnap.data() != null) {
        final userData = docSnap.data() as Map<String, dynamic>;
        if (userData.containsKey(moduleId) && userData[moduleId] is Map) {
          final moduleDataFromServer =
              Map<String, dynamic>.from(userData[moduleId] as Map);

          Map<String, dynamic> processedModuleData = {
            'isCompleted': moduleDataFromServer['isCompleted'] ?? false,
            'isUnlocked': moduleDataFromServer['isUnlocked'] ?? false,
            'lastUpdated': moduleDataFromServer['lastUpdated'],
            'unlockedAt': moduleDataFromServer['unlockedAt'],
          };

          processedModuleData['lessons'] = Map<String, bool>.from(
              moduleDataFromServer['lessons'] as Map? ?? {});

          // CORRECTED: Read attempts from the nested 'activityLogs.attempts' path
          final activityLogsMap =
              moduleDataFromServer['activityLogs'] as Map<String, dynamic>?;
          if (activityLogsMap != null && activityLogsMap['attempts'] is Map) {
            processedModuleData['attempts'] = Map<String, int>.from(
                activityLogsMap['attempts'] as Map? ?? {});
          } else {
            _logger.w(
                "Attempts data not found or not a map at $moduleId.activityLogs.attempts. Initializing empty for return.");
            processedModuleData['attempts'] =
                <String, int>{}; // Fallback to empty map
          }

          // If you have a separate field for detailed log entries (array)
          // For example, if logLessonActivity writes to 'detailedLogEntries':
          // processedModuleData['detailedLogEntries'] = List<Map<String, dynamic>>.from(moduleDataFromServer['detailedLogEntries'] ?? []);

          _logger.d(
              'Processed Module $moduleId progress from Firestore: $processedModuleData');
          return processedModuleData;
        }
      }

      _logger.w(
          'No progress data found for module $moduleId for user $userId. Creating and returning default structure.');
      // Default data creation if module data doesn't exist for the user
      List<String> lessonKeysToUse = [];
      final config = courseConfig[moduleId];
      if (config != null &&
          config['lessons'] is List &&
          (config['lessons'] as List).every((item) => item is String)) {
        lessonKeysToUse = List<String>.from(config['lessons']);
      } else {
        _logger.w(
            "Default progress for $moduleId: lesson keys not found in courseConfig. Using fallback/hardcoded for $moduleId.");
        if (moduleId == 'module5') {
          lessonKeysToUse = ['lesson1', 'lesson2'];
        } else if (moduleId == 'module1')
          lessonKeysToUse = ['lesson1', 'lesson2', 'lesson3'];
        // Add other module fallbacks as defined in your modules_config.dart
      }

      final defaultLessons = {for (var key in lessonKeysToUse) key: false};
      final defaultAttemptsNested = {for (var key in lessonKeysToUse) key: 0};

      final defaultModuleDataToSet = {
        // This is the structure to SET in Firestore
        'isCompleted': false,
        'lessons': defaultLessons,
        'activityLogs': {
          // Nested structure for attempts
          'attempts': defaultAttemptsNested
        },
        // 'detailedLogEntries': [], // If you have a separate list for log entries
        'isUnlocked': moduleId == 'module1',
        'unlockedAt':
            moduleId == 'module1' ? FieldValue.serverTimestamp() : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Before returning, construct the map as the application expects it (with 'attempts' at top level)
      final defaultModuleDataToReturn = {
        'isCompleted': defaultModuleDataToSet['isCompleted'] as bool,
        'isUnlocked': defaultModuleDataToSet['isUnlocked'] as bool,
        'lessons':
            Map<String, bool>.from(defaultModuleDataToSet['lessons'] as Map),
        'attempts': Map<String, int>.from(
            (defaultModuleDataToSet['activityLogs'] as Map)['attempts']
                as Map), // Extract for return
        // 'detailedLogEntries': [],
        'lastUpdated': null,
        'unlockedAt': null,
      };

      // Set the default structure in Firestore for next time
      // Use SetOptions(merge: true) if userProgressDocRef might already exist with other module data
      await userDocRef.set({moduleId: defaultModuleDataToSet},
          SetOptions(mergeFields: [moduleId]));

      _logger.d(
          'Created and returned default progress data for module $moduleId for user $userId: $defaultModuleDataToReturn');
      return defaultModuleDataToReturn;
    } catch (e, s) {
      _logger.e('Error fetching module progress for $moduleId: $e\n$s');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDetailedLessonAttempts(
      String lessonIdKey) async {
    final uId =
        userId; // Uses the existing 'userId' getter in your FirebaseService
    if (uId == null) {
      _logger.e(
          'User not authenticated for getDetailedLessonAttempts for $lessonIdKey.');
      return []; // Return empty list if not authenticated
    }

    _logger
        .i('Fetching detailed attempts for Lesson: $lessonIdKey, User: $uId');

    try {
      final userProgressDocRef = _firestore.collection('userProgress').doc(uId);
      final docSnapshot = await userProgressDocRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        // Check if 'lessonAttempts' map and the specific 'lessonIdKey' exist
        if (data != null && data.containsKey('lessonAttempts')) {
          final lessonAttemptsMap =
              data['lessonAttempts'] as Map<String, dynamic>?;
          if (lessonAttemptsMap != null &&
              lessonAttemptsMap.containsKey(lessonIdKey)) {
            final attemptsList =
                lessonAttemptsMap[lessonIdKey] as List<dynamic>?;
            if (attemptsList != null) {
              // Convert List<dynamic> to List<Map<String, dynamic>>
              return attemptsList.map((attempt) {
                if (attempt is Map) {
                  return Map<String, dynamic>.from(attempt);
                }
                _logger.w(
                    'Found non-map item in attemptsList for $lessonIdKey: $attempt');
                return <String, dynamic>{}; // Or handle error more gracefully
              }).toList();
            }
          }
        }
      }
      _logger.i(
          'No detailed attempts found for $lessonIdKey for user $uId, or path does not exist.');
      return []; // Return empty list if no data, path doesn't exist, or data is malformed
    } catch (e, s) {
      _logger.e(
          'Error fetching detailed lesson attempts for $lessonIdKey, User $uId: $e\n$s');
      return []; // Return empty list on error to prevent crashes
    }
  }

  // Add this method to your FirebaseService class in firebase_service.dart

  Future<Map<String, List<Map<String, dynamic>>>>
      getAllUserLessonAttempts() async {
    final uId = userId;
    if (uId == null) {
      _logger.w('User not authenticated for getAllUserLessonAttempts.');
      return {};
    }

    _logger.i('[SERVICE] Fetching all lesson attempts for User: $uId');
    try {
      final userProgressDocRef = _firestore.collection('userProgress').doc(uId);
      final docSnapshot = await userProgressDocRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        _logger.d(
            '[SERVICE] Raw userProgress data: $data'); // LOG THE ENTIRE DOCUMENT DATA

        if (data != null && data.containsKey('lessonAttempts')) {
          final lessonAttemptsMapFromFirestore = // Raw map from Firestore
              data['lessonAttempts'] as Map<String, dynamic>?;

          // LOG THE RAW lessonAttemptsMapFromFirestore
          _logger.d(
              '[SERVICE] Raw lessonAttemptsMapFromFirestore: $lessonAttemptsMapFromFirestore');
          _logger.i(
              '[SERVICE] Keys in raw lessonAttemptsMapFromFirestore: ${lessonAttemptsMapFromFirestore?.keys.toList()}');

          if (lessonAttemptsMapFromFirestore != null) {
            final Map<String, List<Map<String, dynamic>>> typedAttemptsMap = {};
            lessonAttemptsMapFromFirestore
                .forEach((lessonId, attemptsListFromFirestore) {
              _logger.d(
                  '[SERVICE] Processing lessonId: $lessonId'); // Log each lessonId being processed
              if (attemptsListFromFirestore is List) {
                try {
                  // Add try-catch around the mapping for each lesson's attempts
                  typedAttemptsMap[lessonId] = attemptsListFromFirestore
                      .map((attemptDoc) {
                        if (attemptDoc == null) {
                          // Check for null attempts in the list
                          _logger.w(
                              '[SERVICE] Null attempt found in list for lessonId: $lessonId. Skipping.');
                          return <String, dynamic>{
                            'error': 'Null attempt data'
                          }; // Or filter it out
                        }
                        if (attemptDoc is! Map) {
                          // Ensure each attempt is a map
                          _logger.w(
                              '[SERVICE] Non-map attempt found for lessonId: $lessonId. Data: $attemptDoc. Skipping.');
                          return <String, dynamic>{
                            'error': 'Non-map attempt data',
                            'originalData': attemptDoc.toString()
                          };
                        }

                        final attemptData =
                            Map<String, dynamic>.from(attemptDoc);

                        if (attemptData['attemptTimestamp'] is Timestamp) {
                          attemptData['attemptTimestamp'] =
                              (attemptData['attemptTimestamp'] as Timestamp)
                                  .toDate();
                        }
                        // Add similar checks for other potential Timestamp fields if they exist
                        // e.g., lastUpdatedTimestampInAttempt, or any timestamps inside detailedResponses

                        return attemptData;
                      })
                      .where((attempt) =>
                          attempt.isNotEmpty && attempt['error'] == null)
                      .toList(); // Filter out problematic attempts

                  if (typedAttemptsMap[lessonId]!.isEmpty &&
                      attemptsListFromFirestore.isNotEmpty) {
                    _logger.w(
                        '[SERVICE] All attempts for lessonId $lessonId were problematic and filtered out.');
                  }
                } catch (e, s) {
                  _logger.e(
                      '[SERVICE] Error processing attempts for lessonId: $lessonId. Error: $e\nStackTrace: $s');
                  // Decide if you want to skip this lesson or return partial data.
                  // For now, it will be skipped if an error occurs here.
                }
              } else {
                _logger.w(
                    '[SERVICE] Attempts data for lessonId "$lessonId" is not a List. Found: ${attemptsListFromFirestore.runtimeType}');
              }
            });
            _logger.i(
                "[SERVICE] Processed typedAttemptsMap. ${typedAttemptsMap.length} lessons found. Keys: ${typedAttemptsMap.keys.toList()}");
            return typedAttemptsMap;
          } else {
            _logger.w('[SERVICE] lessonAttemptsMapFromFirestore was null.');
          }
        } else {
          _logger.w(
              "[SERVICE] Document exists, but 'lessonAttempts' field is missing or null.");
        }
      } else {
        _logger.w(
            "[SERVICE] User progress document does not exist for user $uId.");
      }
    } catch (e, s) {
      _logger.e('[SERVICE] Error fetching all user lesson attempts: $e\n$s');
    }
    _logger.w(
        '[SERVICE] No lessonAttempts data found or a critical error occurred for user $uId. Returning empty map.');
    return {};
  }

  Future<Map<String, dynamic>?> getFullLessonContent(
      String lessonDocumentId) async {
    if (lessonDocumentId.isEmpty) {
      _logger
          .w('Lesson document ID is empty. Cannot fetch full lesson content.');
      return null;
    }
    try {
      _logger.i(
          'Fetching full content for lesson document: $lessonDocumentId from "lessons" collection.');
      final lessonDocRef =
          _firestore.collection('lessons').doc(lessonDocumentId);
      final docSnapshot = await lessonDocRef.get();

      if (docSnapshot.exists) {
        _logger.d(
            'Full lesson content found for $lessonDocumentId: ${docSnapshot.data()}');
        return docSnapshot.data();
      } else {
        _logger.w(
            'Lesson document "$lessonDocumentId" not found in "lessons" collection.');
        return null;
      }
    } catch (e) {
      _logger
          .e('Error fetching full lesson content for "$lessonDocumentId": $e');
      return null;
    }
  }

  Future<void> updateLessonProgress(
      String moduleId, // e.g., "module5"
      String
          lessonKeyInModule, // e.g., "lesson1", "lesson2" (this is the 'lessonId' from your previous version)
      bool completed,
      {Map<String, int>? attempts}) async {
    // This map is like {'lesson1': count1, 'lesson2': count2}
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('User not authenticated for updating lesson progress.');
      throw Exception('User not authenticated');
    }
    final userId = user.uid;
    _logger.i(
        'Updating progress for User: $userId, Module: $moduleId, LessonKey: $lessonKeyInModule, Completed: $completed');
    if (attempts != null) {
      _logger.i('Attempt counts to update for $moduleId: $attempts');
    }

    try {
      final userDocRef = _firestore.collection('userProgress').doc(userId);

      // Prepare the data for update using dot notation for nested fields
      Map<String, dynamic> dataToUpdate = {
        '$moduleId.lessons.$lessonKeyInModule':
            completed, // Path: module5.lessons.lesson1
        '$moduleId.lastUpdated': FieldValue.serverTimestamp(),
        // If the entire module is being marked as completed based on this lesson,
        // you might also update '$moduleId.isCompleted' here or after checking all lessons.
      };

      // **THIS IS THE CRITICAL FIX FOR ATTEMPT COUNTS:**
      // Iterate through the attempts map (which contains counts for all lessons in the module)
      // and set the specific path for each lesson's attempt count.
      if (attempts != null) {
        attempts.forEach((localLessonKey, count) {
          // localLessonKey is "lesson1", "lesson2"
          // This creates update paths like: "module5.activityLogs.attempts.lesson1": newCount
          dataToUpdate['$moduleId.activityLogs.attempts.$localLessonKey'] =
              count;
          _logger.d(
              'Firestore update path for attempt count: $moduleId.activityLogs.attempts.$localLessonKey = $count');
        });
      }

      _logger.d("Final dataToUpdate object for module progress: $dataToUpdate");
      await userDocRef.update(dataToUpdate);

      // Module completion check logic (after successfully updating lesson status and attempts)
      final doc = await userDocRef.get();
      if (!doc.exists || doc.data() == null) {
        _logger.e(
            'User document not found for $userId after lesson update. Cannot check module completion.');
        return;
      }
      final userData = doc.data() as Map<String, dynamic>;
      final moduleData = userData[moduleId] as Map<String, dynamic>?;

      if (moduleData == null || moduleData['lessons'] == null) {
        _logger.e(
            'Module data or lessons map not found for $moduleId in user $userId. Cannot check module completion.');
        return;
      }

      final lessonsInProgressMap =
          Map<String, bool>.from(moduleData['lessons'] as Map? ?? {});
      _logger.i(
          'For module completion check of $moduleId - Lessons map from Firestore: $lessonsInProgressMap');

      List<String> actualLessonKeysForCompletion = [];
      final config =
          courseConfig[moduleId]; // courseConfig from your modules_config.dart

      if (config != null &&
          config['lessons'] is List &&
          (config['lessons'] as List).every((item) => item is String)) {
        actualLessonKeysForCompletion = List<String>.from(config['lessons']);
        _logger.i(
            "Module completion check for $moduleId: Using lesson keys from courseConfig: $actualLessonKeysForCompletion");
      } else {
        _logger.w(
            "Module completion check for $moduleId: Lesson keys not found/invalid in courseConfig. Using keys from user's progress map: ${lessonsInProgressMap.keys.toList()}");
        actualLessonKeysForCompletion = lessonsInProgressMap.keys.toList();
        // Add specific fallbacks if a module's keys are known but config might be missing
        // Ensure these match your actual lesson keys in modules_config.dart
        if (actualLessonKeysForCompletion.isEmpty && moduleId == 'module5') {
          actualLessonKeysForCompletion = ['lesson1', 'lesson2'];
          _logger.w(
              "Module completion check for $moduleId: Using hardcoded default lesson keys for completion check: $actualLessonKeysForCompletion");
        } else if (actualLessonKeysForCompletion.isEmpty &&
            moduleId == 'module1') {
          actualLessonKeysForCompletion = ['lesson1', 'lesson2', 'lesson3'];
          _logger.w(
              "Module completion check for $moduleId: Using hardcoded default lesson keys for completion check: $actualLessonKeysForCompletion");
        }
        // Add other module fallbacks as needed
      }

      bool allRequiredLessonsCompleted =
          actualLessonKeysForCompletion.isNotEmpty &&
              actualLessonKeysForCompletion
                  .every((key) => lessonsInProgressMap[key] == true);

      _logger.d(
          "For $moduleId, required keys: $actualLessonKeysForCompletion. All completed: $allRequiredLessonsCompleted");

      await userDocRef
          .update({'$moduleId.isCompleted': allRequiredLessonsCompleted});

      _logger.i(
          'Updated lesson $lessonKeyInModule in $moduleId: completed=$completed. Module $moduleId completion is $allRequiredLessonsCompleted for user $userId.');
    } catch (e, s) {
      _logger.e(
          'Error updating lesson progress for $moduleId/$lessonKeyInModule: $e\n$s');
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

  Future<bool> checkPreAssessmentComplete(String lessonKey) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userProgressDoc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .get();

      if (!userProgressDoc.exists) return false;

      final data = userProgressDoc.data();
      if (data == null) return false;

      final preAssessmentsCompleted = data['preAssessmentsCompleted'] as Map<String, dynamic>?;
      if (preAssessmentsCompleted == null) return false;

      // I-ensure na boolean ang return value
      final isComplete = preAssessmentsCompleted[lessonKey];
      return isComplete == true; // Explicitly check for true value

    } catch (e) {
      _logger.e("Error checking pre-assessment status: $e");
      return false; // Safe default
    }
  }

  /// Marks a specific pre-assessment as complete for the current user.
  /// The [lessonKey] is the identifier for the pre-assessment (e.g., 'module3_pre_assessment').
  Future<void> markPreAssessmentAsComplete(String lessonKey) async {
    final uId = userId;
    if (uId == null) {
      _logger.e('User not authenticated to mark pre-assessment complete.');
      throw Exception('User not authenticated');
    }
    if (lessonKey.isEmpty) {
      _logger.w('Lesson key is empty, cannot mark pre-assessment as complete.');
      return;
    }

    try {
      final userProgressDocRef = _firestore.collection('userProgress').doc(uId);
      // Use dot notation to update a specific field within the 'preAssessmentsCompleted' map.
      // This will create the map if it doesn't exist and add/update the lessonKey.
      await userProgressDocRef.set({
        'preAssessmentsCompleted': {
          lessonKey: true,
        }
      }, SetOptions(merge: true)); // Use merge:true to avoid overwriting the whole document

      _logger.i('Successfully marked pre-assessment "$lessonKey" as complete for user $uId.');
    } catch (e, s) {
      _logger.e('Error marking pre-assessment "$lessonKey" as complete: $e\n$s');
      rethrow;
    }
  }

  // This seems to be a duplicate of the async version above.
  // It's better to use the async version directly. I'm leaving it empty.
  void markPreAssessmentComplete(String s) {}

  /// Submits the specific data for Lesson 3.2, wrapping it for the generic save function.
  Future<void> submitLesson3_2Data({
    required int attemptNumber,
    required double overallScore,
    required int timeSpent,
    required Map<String, String> reflections,
    required List<Map<String, dynamic>> submittedPrompts, required String lessonIdKey, required List<Map<String, dynamic>> promptDetails, required String lessonId
  }) async {
    const String lessonIdKey = 'Lesson 3.2'; // Hardcoded for this specific function
    _logger.i('Submitting data for $lessonIdKey, attempt: $attemptNumber');

    try {
      // Construct the detailed payload from the specific parameters
      final detailedResponsesPayload = {
        'prompts': submittedPrompts,
        'reflections': reflections,
        // You can add any other specific data for L3.2 here
      };

      // Use the existing generic method to save the attempt
      await saveSpecificLessonAttempt(
        lessonIdKey: lessonIdKey,
        score: overallScore.toInt(), // Convert double to int if score is always integer
        attemptNumberToSave: attemptNumber,
        timeSpent: timeSpent,
        detailedResponsesPayload: detailedResponsesPayload,
        isUpdate: false, // Assuming this is a new submission
      );

      _logger.i('Successfully submitted data for $lessonIdKey.');
    } catch (e) {
      _logger.e('Error submitting data for $lessonIdKey: $e');
      rethrow;
    }
  }

  /// Directly updates the completion status of a specific module.
  Future<void> updateModuleCompletionStatus(String moduleId, bool isCompleted) async {
    final uId = userId;
    if (uId == null) {
      _logger.e('User not authenticated to update module completion status.');
      throw Exception('User not authenticated');
    }
    if (moduleId.isEmpty) {
      _logger.w('Module ID is empty, cannot update completion status.');
      return;
    }

    try {
      final userProgressDocRef = _firestore.collection('userProgress').doc(uId);
      // Use dot notation to update only the 'isCompleted' field of the specified module
      await userProgressDocRef.update({
        '$moduleId.isCompleted': isCompleted,
        '$moduleId.lastUpdated': FieldValue.serverTimestamp(),
      });
      _logger.i('Updated module "$moduleId" completion status to $isCompleted for user $uId.');
    } catch (e, s) {
      _logger.e('Error updating module completion status for "$moduleId": $e\n$s');
      rethrow;
    }
  }

  Future getLessonAttempts(String s) async {}

  Future getUserProgress(String s, String t) async {}
}