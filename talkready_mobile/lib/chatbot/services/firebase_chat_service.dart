import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/message.dart';

class FirebaseChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger logger;

  String? _currentSessionId;

  FirebaseChatService({required this.logger});

  String? get currentSessionId => _currentSessionId;

  Future<void> initializeNewChatSession(Message initialMessage) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e("Cannot initialize chat session: user not logged in.");
      throw Exception("User not logged in");
    }

    try {
      Map<String, dynamic> firestoreInitialMessage = {
        'text': initialMessage.text,
        'sender': 'bot',
        'timestamp': Timestamp.fromDate(DateTime.parse(initialMessage.timestamp)),
        'audioUrl': null,
      };

      DocumentReference sessionRef = _firestore.collection('chatSessions').doc();
      _currentSessionId = sessionRef.id;

      await sessionRef.set({
        'userId': user.uid,
        'startTime': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'messages': [firestoreInitialMessage],
      });

      logger.i('New chat session created with ID: $_currentSessionId');
    } catch (e) {
      logger.e('Error initializing new chat session: $e');
      rethrow;
    }
  }

  Future<void> addMessageToSession(Message message, {String? audioUrl}) async {
    if (_currentSessionId == null) {
      logger.w('No active chat session ID. Cannot save message to Firestore.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.e("Cannot add message to session: user not logged in.");
      return;
    }

    try {
      final firestoreMessage = {
        'text': message.text,
        'sender': message.isUser ? 'user' : 'bot',
        'timestamp': Timestamp.fromDate(DateTime.parse(message.timestamp)),
        'audioUrl': message.isUser ? audioUrl : null,
      };

      await _firestore.collection('chatSessions').doc(_currentSessionId).update({
        'messages': FieldValue.arrayUnion([firestoreMessage]),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      logger.i('Message added to chat session: $_currentSessionId');
    } catch (e) {
      logger.e('Error adding message to chat session $_currentSessionId: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.w("User is null in fetchUserData");
      return null;
    }

    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;

      if (userData != null) {
        logger.i('Fetched user data for ${user.uid}');
        return userData;
      } else {
        logger.e('User data is null for user ${user.uid}');
        return null;
      }
    } catch (e) {
      logger.e('Error fetching user data: $e');
      return null;
    }
  }

  Future<void> saveTutorialStatus(bool hasSeenTutorial) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.w('Cannot save tutorial status: user not logged in.');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'hasSeenTutorial': hasSeenTutorial,
      });
      logger.i('Tutorial status saved: hasSeenTutorial=$hasSeenTutorial for user ${user.uid}');
    } catch (e) {
      logger.e('Error saving tutorial status: $e');
      rethrow;
    }
  }

  void clearCurrentSession() {
    _currentSessionId = null;
    logger.i('Current session cleared');
  }
}