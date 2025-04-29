import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'loading_screen.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  Timer? _resendTimer;
  int _secondsRemaining = 60;
  bool _cooldownActive = false;
  int _attemptCount = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownActive = true;
      _secondsRemaining = 60;
      _attemptCount++;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _resendTimer?.cancel();
        setState(() => _cooldownActive = false);
      }
    });
  }

  Future<void> _sendPasswordResetEmail() async {
    try {
      if (_cooldownActive) return;

      if (_emailController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email address')),
        );
        return;
      }

      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address')),
        );
        return;
      }

      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoadingScreen()));

      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _startCooldown();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📨 Reset Link Sent!', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                'Check spam folder if not received within 2 minutes\n'
                'Attempts remaining: ${3 - _attemptCount}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00568D),
          duration: const Duration(seconds: 5),
        ),
      );

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      String message = _handleFirebaseError(e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred')),
      );
    }
  }

  String _handleFirebaseError(String code) {
    switch (code) {
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-not-found':
        return 'No account found with this email';
      default:
        return 'Error: $code';
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text(''),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    body: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🔒 Forgot Password?',
            style: TextStyle(fontSize: 24, color: Color(0xFF00568D), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter your registered email to receive password reset instructions',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email, color: Color(0xFF00568D)),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00568D)),
              ),
            ),
          ),
            const Spacer(),
            ElevatedButton(
              onPressed: _cooldownActive ? null : _sendPasswordResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cooldownActive
                    ? Colors.grey
                    : const Color(0xFF00568D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _cooldownActive
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Resend in '),
                        Text(
                          '${_secondsRemaining}s',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : const Text('Send Reset Link', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 10),
            if (_attemptCount >= 3)
              Text(
                'Still not receiving emails? Contact support@talkready.app',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
