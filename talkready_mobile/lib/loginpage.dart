import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'forgotpass.dart';
import 'loading_screen.dart';
import 'homepage.dart';
import 'welcome_page.dart';
import 'TrainerDashboard.dart'; // <-- Add this import

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Updated onboarding check: looks for onboardingCompleted == true
  Future<bool> _hasCompletedOnboarding(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;

      // If onboardingCompleted is already true, return true
      if (doc.exists && userData != null && userData['onboardingCompleted'] == true) {
        return true;
      }

      // Check if onboarding info fields exist (customize these fields as needed)
      bool hasOnboardingInfo = userData != null &&
          userData['firstName'] != null &&
          userData['lastName'] != null &&
          userData['firstName'].toString().isNotEmpty &&
          userData['lastName'].toString().isNotEmpty;

      if (hasOnboardingInfo) {
        // Set onboardingCompleted to true if info exists
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'onboardingCompleted': true});
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Updated: Navigate based on userType
  Future<void> _navigateAfterLogin(User user) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;

      // Check userType
      String? userType = userData?['userType']?.toString().toLowerCase();

      // If onboarding is not completed, go to WelcomePage
      bool hasOnboardingData = await _hasCompletedOnboarding(user.uid);
      if (!mounted) return;

      if (!hasOnboardingData) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
        return;
      }

      // Navigate based on userType
      if (userType == 'trainer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TrainerDashboard()),
        );
      } else {
        // Default to HomePage for students and others
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: $e')),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Ensure user document exists in Firestore for Google users
      if (userCredential.user != null) {
        final userDoc = _firestore.collection('users').doc(userCredential.user!.uid);
        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          await userDoc.set({
            'email': userCredential.user!.email,
            'firstName': userCredential.user!.displayName?.split(' ').first ?? '',
            'lastName': userCredential.user!.displayName?.split(' ').skip(1).join(' ') ?? '',
            'onboardingCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        await _navigateAfterLogin(userCredential.user!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _signInWithEmailPassword() async {
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoadingScreen()),
      );

      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (userCredential.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        await _navigateAfterLogin(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'Login failed: $e';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  void _showTermsOfServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: const BorderSide(color: Color(0xFF00568D), width: 2.0),
        ),
        title: const Text(
          'Terms of Service',
          style: TextStyle(
            color: Color(0xFF00568D),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Scrollbar(
            thumbVisibility: true,
            thickness: 6.0,
            radius: const Radius.circular(3.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Welcome to TalkReady! These Terms of Service govern your use of our app. By creating an account or using TalkReady, you agree to these terms.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '1. Eligibility',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'You must be at least 13 years old to use TalkReady. Accounts are personal and cannot be shared or transferred.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '2. Content Ownership',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'Your data, such as profile pictures and learning progress, belongs to you. You grant TalkReady a license to use this data to provide and improve our services.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '3. Prohibited Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'You may not misuse TalkReady, including hacking, spamming, or sharing harmful or illegal content.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '4. Account Termination',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'We reserve the right to suspend or terminate accounts for violations of these terms.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '5. Changes to Terms',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'We may update these terms from time to time. You will be notified of significant changes via the app or email.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF00568D)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: const BorderSide(color: Color(0xFF00568D), width: 2.0),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Color(0xFF00568D),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Scrollbar(
            thumbVisibility: true,
            thickness: 6.0,
            radius: const Radius.circular(3.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Privacy Policy for TalkReady',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Last Updated: May 11, 2025',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'At TalkReady, we value your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, share, and safeguard your data when you use our app. By using TalkReady, you agree to the practices described in this policy.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '1. Information We Collect',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'We collect the following types of information:\n- Personal Information: When you sign up or log in using Google Sign-In or email/password, we collect your email address, name (if provided via Google), and user ID.\n- Usage Data: We collect data about your interactions with the app, such as lessons completed, progress scores (e.g., Fluency, Grammar), and preferences (e.g., onboarding responses).\n- Device Information: We may collect device details like device type, operating system, and IP address to improve app performance.\n- Analytics: We use anonymized data to analyze app usage and enhance our services.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '2. How We Use Your Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'We use your information to:\n- Provide and personalize your learning experience (e.g., track progress, recommend lessons).\n- Authenticate your account and ensure security.\n- Improve our app through analytics and feedback.\n- Communicate with you, such as sending updates or responding to inquiries.\n- Comply with legal obligations.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '3. How We Share Your Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'We do not sell your personal information. We may share data in these cases:\n- Service Providers: With trusted third parties (e.g., Firebase for authentication and data storage) who help operate the app, bound by confidentiality agreements.\n- Legal Requirements: If required by law or to protect our rights, we may disclose data to authorities.\n- Anonymized Data: We may share aggregated, non-identifiable data for analytics or research.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '4. Data Security',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'We implement industry-standard measures (e.g., encryption, secure authentication) to protect your data. However, no system is completely secure, and we cannot guarantee absolute security.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '5. Your Rights',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'Depending on your location, you may have rights to:\n- Access, correct, or delete your personal information.\n- Opt out of certain data collection (e.g., analytics).\n- Request a copy of your data.\nTo exercise these rights, contact us at support@talkready.app.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '6. Third-Party Services',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'TalkReady uses third-party services like Google Sign-In and Firebase, which have their own privacy policies. We encourage you to review their policies:\n- Google Privacy Policy: https://policies.google.com/privacy\n- Firebase Privacy: https://firebase.google.com/support/privacy',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '7. Children’s Privacy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'TalkReady is not intended for children under 13. We do not knowingly collect data from users under 13. If we learn such data has been collected, we will delete it.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '8. Changes to This Policy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'We may update this Privacy Policy from time to time. Significant changes will be notified via the app or email. The updated policy will be effective upon posting.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '9. Contact Us',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Text(
                    'If you have questions or concerns about this Privacy Policy, contact us at:\n- Email: support@talkready.app\n- Address: TalkReady, 123 Learning Lane, Education City, EC 12345',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF00568D)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 5),
            SizedBox(
              height: 250,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: -15,
                    child: Image.asset(
                      'images/TR Logo.png',
                      height: 180,
                      width: 180,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.error,
                        size: 120,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 85,
                    child: Image.asset(
                      'images/TR Text.png',
                      height: 180,
                      width: 260,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'TalkReady',
                        style: TextStyle(
                          fontSize: 32,
                          color: Color(0xFF00568D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 0),
            const Text(
              'Hello, welcome back!',
              style: TextStyle(fontSize: 24, color: Color(0xFF00568D)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-mail address',
                labelStyle: TextStyle(color: Color(0xFF00568D)),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00568D)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Color(0xFF00568D)),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00568D)),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF00568D),
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                  );
                },
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(color: Color(0xFF00568D), fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFF00568D), thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR', style: TextStyle(color: Color(0xFF00568D), fontSize: 16)),
                ),
                Expanded(child: Divider(color: Color(0xFF00568D), thickness: 1)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _signInWithGoogle(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              child: const Text('Continue with Google', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signInWithEmailPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              child: const Text('Log in', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Color(0xFF00568D)),
                  children: [
                    const TextSpan(text: 'By continuing, you agree to our '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: Color(0xFF00568D),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          _showPrivacyPolicyDialog();
                        },
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        color: Color(0xFF00568D),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          _showTermsOfServiceDialog();
                        },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}