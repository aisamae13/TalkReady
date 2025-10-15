import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'device_session_manager.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;

  // Session will timeout after 10 minutes (600 seconds) of inactivity
  static const Duration sessionTimeout = Duration(minutes: 10);

  // Warning will show 1 minute before logout (at 9 minutes)
  static const Duration warningDuration = Duration(minutes: 9);

  bool _isWarningShown = false;
  BuildContext? _currentContext;

  void initialize(BuildContext context) {
    _currentContext = context;
    resetTimer();
  }

  void resetTimer() {
    _lastActivityTime = DateTime.now();
    _isWarningShown = false;
    _inactivityTimer?.cancel();

    // Check every 1 second instead of 30 seconds for better accuracy
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastActivityTime == null) return;

      final now = DateTime.now();
      final inactiveDuration = now.difference(_lastActivityTime!);

      // Show warning at 29 seconds
      if (inactiveDuration >= warningDuration && !_isWarningShown) {
        _showWarningDialog();
        _isWarningShown = true;
      }

      // Auto logout after 30 seconds
      if (inactiveDuration >= sessionTimeout) {
        _performLogout();
        timer.cancel();
      }
    });
  }

 void updateActivity() {
  _lastActivityTime = DateTime.now();
  _isWarningShown = false;

  // Also update device session
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    DeviceSessionManager().updateActivity(user.uid);
  }
}

  void _showWarningDialog() {
    if (_currentContext != null && _currentContext!.mounted) {
      showDialog(
        context: _currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Session Timeout Warning',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            'You will be automatically logged out in 1 minute due to inactivity. '
            'Click "Stay Logged In" to continue your session.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogout();
              },
              child: Text(
                'Logout Now',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                resetTimer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Stay Logged In',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _performLogout() async {
    try {
      // Close any open dialogs first
      if (_currentContext != null && _currentContext!.mounted) {
        Navigator.of(_currentContext!).popUntil((route) => route.isFirst);
      }

      await FirebaseAuth.instance.signOut();

      if (_currentContext != null && _currentContext!.mounted) {
        Navigator.of(_currentContext!).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );

        ScaffoldMessenger.of(_currentContext!).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('You have been logged out due to inactivity'),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during auto-logout: $e');
    }
  }

  void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _currentContext = null;
  }
}