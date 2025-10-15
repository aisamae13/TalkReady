import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceSessionManager {
  static final DeviceSessionManager _instance = DeviceSessionManager._internal();
  factory DeviceSessionManager() => _instance;
  DeviceSessionManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _sessionListener;
  String? _currentDeviceId;
  String? _currentSessionId;

  // Get unique device identifier
  Future<String> getDeviceId() async {
    if (_currentDeviceId != null) return _currentDeviceId!;

    final deviceInfo = DeviceInfoPlugin();
    String deviceId;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Unique Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
      } else {
        deviceId = 'unknown-platform';
      }
    } catch (e) {
      deviceId = 'error-${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('Error getting device ID: $e');
    }

    _currentDeviceId = deviceId;
    return deviceId;
  }

  // Get device name for display
  Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} (${iosInfo.model})';
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
    }

    return 'Unknown Device';
  }

  // Check if user can login (no active session on another device)
  Future<Map<String, dynamic>> canLogin(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final sessionDoc = await _firestore
          .collection('userSessions')
          .doc(userId)
          .get();

      if (!sessionDoc.exists) {
        return {'canLogin': true};
      }

      final data = sessionDoc.data()!;
      final activeDeviceId = data['deviceId'] as String?;
      final lastActivity = (data['lastActivity'] as Timestamp?)?.toDate();
      final deviceName = data['deviceName'] as String?;

      // If same device, allow login
      if (activeDeviceId == deviceId) {
        return {'canLogin': true};
      }

      // Check if session expired (more than 10 minutes inactive)
      if (lastActivity != null) {
        final inactiveDuration = DateTime.now().difference(lastActivity);
        if (inactiveDuration.inMinutes > 10) {
          // Session expired, allow login
          return {'canLogin': true};
        }
      }

      // Another device has an active session
      return {
        'canLogin': false,
        'activeDevice': deviceName ?? 'Unknown Device',
        'lastActivity': lastActivity,
      };
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return {'canLogin': true}; // Allow login on error to avoid blocking users
    }
  }

  // Create session after successful login
  Future<void> createSession(String userId, BuildContext context) async {
    try {
      final deviceId = await getDeviceId();
      final deviceName = await getDeviceName();
      final sessionId = '${deviceId}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('userSessions').doc(userId).set({
        'userId': userId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'sessionId': sessionId,
        'loginTime': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      _currentSessionId = sessionId;

      // Start listening for session changes (force logout if logged in elsewhere)
      _startSessionListener(userId, sessionId, context);

      debugPrint('✅ Session created: $sessionId on $deviceName');
    } catch (e) {
      debugPrint('Error creating session: $e');
    }
  }

  // Update session activity (called periodically)
  Future<void> updateActivity(String userId) async {
    try {
      if (_currentSessionId == null) return;

      await _firestore.collection('userSessions').doc(userId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating activity: $e');
    }
  }

  // Listen for session changes (force logout if session invalidated)
  void _startSessionListener(String userId, String sessionId, BuildContext context) {
    _sessionListener?.cancel();

    _sessionListener = _firestore
        .collection('userSessions')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final currentSessionId = data['sessionId'] as String?;

      // If session ID changed, another device logged in
      if (currentSessionId != sessionId) {
        _forceLogout(context, 'You have been logged in from another device.');
      }
    });
  }

  // Force logout with message
  Future<void> _forceLogout(BuildContext context, String message) async {
    try {
      await FirebaseAuth.instance.signOut();
      _sessionListener?.cancel();
      _currentSessionId = null;

      if (context.mounted) {
        // Close all dialogs and navigate to login
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

        // Show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during force logout: $e');
    }
  }

  // End session (logout)
  Future<void> endSession(String userId) async {
    try {
      await _firestore.collection('userSessions').doc(userId).delete();
      _sessionListener?.cancel();
      _currentSessionId = null;
      debugPrint('✅ Session ended for user: $userId');
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  // Force logout from specific device (admin feature)
  Future<void> forceLogoutDevice(String userId) async {
    try {
      await _firestore.collection('userSessions').doc(userId).update({
        'sessionId': 'force_logout_${DateTime.now().millisecondsSinceEpoch}',
      });
      debugPrint('✅ Forced logout for user: $userId');
    } catch (e) {
      debugPrint('Error forcing logout: $e');
    }
  }

  void dispose() {
    _sessionListener?.cancel();
  }
}