import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'loading_screen.dart'; // Import your LoadingScreen if you want to use it

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    try {
      if (_emailController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email address')),
        );
        return;
      }

      // Show LoadingScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoadingScreen()),
      );

      // Send password reset email
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());

      // Hide LoadingScreen
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset link sent! Check your email to reset your password.',
          ),
        ),
      );

      // Optionally, navigate back to the login page or close this page
      Navigator.pop(context); // Go back to the previous page (e.g., LoginPage)
    } on FirebaseAuthException catch (e) {
      // Hide LoadingScreen on error
      Navigator.pop(context);

      String message;
      if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else if (e.code == 'user-not-found') {
        message = 'No user found with that email.';
      } else {
        message = 'Failed to send password reset link: $e';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      // Hide LoadingScreen on error
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
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
              'Forgot password?',
              style: TextStyle(fontSize: 24, color: Color(0xFF00568D)),
            ),
            const SizedBox(height: 10),
            Text(
              'Just confirm your email and we’ll send you a link to initiate a new password.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-mail address',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _sendPasswordResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              child: const Text('Send the Link', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}