// LoginPage

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart'; // Add this if not already included
import 'forgotpass.dart';
import 'loading_screen.dart';
import 'homepage.dart';
import 'welcome_page.dart';
import '../Teachers/TrainerDashboard.dart';
import 'chooseUserType.dart';
import '../session/device_session_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  ); // Added 'profile' for more data
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  @override
  void initState() {
    super.initState();
    _configureAuthSettings(); // Configure Firebase settings on init
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _configureAuthSettings() async {
    try {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting:
            false, // Enable reCAPTCHA for production
        // For testing only (disable in production):
        // appVerificationDisabledForTesting: true,
      );
      logger.i('Firebase auth settings configured successfully');
    } catch (e) {
      logger.e('Error configuring auth settings: $e');
    }
  }

  Future<bool> _hasCompletedOnboarding(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      Map<String, dynamic>? userData = doc.data() as Map<String, dynamic>?;

      if (doc.exists &&
          userData != null &&
          userData['onboardingCompleted'] == true) {
        return true;
      }

      bool hasOnboardingInfo =
          userData != null &&
          userData['firstName'] != null &&
          userData['lastName'] != null &&
          userData['firstName'].toString().isNotEmpty &&
          userData['lastName'].toString().isNotEmpty;

      if (hasOnboardingInfo) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'onboardingCompleted': true,
        });
        return true;
      }

      return false;
    } catch (e) {
      logger.e('Error checking onboarding: $e');
      return false;
    }
  }

  // Replace your _navigateAfterLogin method with this fixed version

  void _navigateAfterLogin(User user) async {
    try {
      // Fetch user data FIRST before showing any loading screen
      final docSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final Map<String, dynamic>? userData = docSnapshot.data();

      if (!mounted) return;

      // Show loading screen AFTER we know where to go
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoadingScreen()),
      );

      // Small delay to show loading screen
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // --- Core Logic Check ---

      // 1. Check if the user document exists and has the necessary data
      if (!docSnapshot.exists ||
          userData == null ||
          userData['userType'] == null) {
        // If the document doesn't exist, create a minimal one (for new users)
        if (!docSnapshot.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? user.email?.split('@').first,
            'createdAt': FieldValue.serverTimestamp(),
            'userType': null,
            'onboardingCompleted': false,
          }, SetOptions(merge: true));
        }

        // Remove loading screen
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        // Action: Needs to select user type
        logger.i(
          'User ${user.uid} needs user type selection. Navigating to ChooseUserTypePage.',
        );
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/chooseUserType');
        }
        return;
      }

      final role = userData['userType'];
      final onboardingCompleted = userData['onboardingCompleted'] ?? false;

      // 2. Check if the user type is set but onboarding isn't complete
      if (role != null && onboardingCompleted == false) {
        // Remove loading screen
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        // Action: Has user type, but needs to start/complete onboarding
        logger.i(
          'User ${user.uid} has user type ($role) but needs onboarding. Navigating to WelcomePage.',
        );
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/welcome');
        }
        return;
      }

      // 3. Check for existing, fully onboarded user (Role-based navigation)
      if (onboardingCompleted == true && role != null) {
        // Remove loading screen
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        logger.i(
          'User ${user.uid} is fully onboarded as $role. Navigating to Dashboard.',
        );
        if (mounted) {
          if (role == 'trainer' || role == 'teacher') {
            Navigator.pushReplacementNamed(context, '/trainer-dashboard');
          } else {
            Navigator.pushReplacementNamed(context, '/homepage');
          }
        }
        return;
      }

      // Fallback
      logger.w(
        'User ${user.uid} fell through navigation logic. Sending to ChooseUserTypePage.',
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chooseUserType');
      }
    } catch (e, stackTrace) {
      // Ensure loading screen is removed on error
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
      // Log error and show snackbar
      logger.e(
        'Login failed or profile error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login failed or profile error. Check logs for details.',
            ),
          ),
        );
      }
    }
  }

 Future<void> _signInWithGoogle() async {
  try {
    await _googleSignIn.signOut();
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    if (!mounted) return;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );
    final user = userCredential.user;

    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-in failed. Please try again.'),
        ),
      );
      return;
    }

    // ✅ NEW: Check if user can login (no active session on another device)
    final loginCheck = await DeviceSessionManager().canLogin(user.uid);

    if (loginCheck['canLogin'] == false) {
      // Another device is active - sign out and show dialog
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      await showDialog(
        context: context,
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
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.devices_other,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Already Logged In',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your account is currently active on another device:',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_android, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loginCheck['activeDevice'] ?? 'Unknown Device',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please logout from the other device first, or wait 10 minutes for the session to expire automatically.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return; // Stop login process
    }

    // ✅ NEW: Create session for this device
    await DeviceSessionManager().createSession(user.uid, context);

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDocRef.get();
    final existingData = docSnapshot.data() as Map<String, dynamic>? ?? {};

    final Map<String, dynamic> dataToMerge = {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? googleUser.email.split('@').first,
      'photoURL': user.photoURL ?? googleUser.photoUrl,
      'emailVerified': user.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existingData.containsKey('userType')) {
      dataToMerge['userType'] = null;
    }
    if (!existingData.containsKey('onboardingCompleted')) {
      dataToMerge['onboardingCompleted'] = false;
    }
    if (!existingData.containsKey('createdAt')) {
      dataToMerge['createdAt'] = FieldValue.serverTimestamp();
    }

    await userDocRef.set(dataToMerge, SetOptions(merge: true));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login successful!')),
    );

    _navigateAfterLogin(user);
  } catch (e, stackTrace) {
    logger.e('Google Sign-In error: $e', error: e, stackTrace: stackTrace);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Sign-In error: An error occurred during authentication.',
          ),
        ),
      );
    }
  }
}

 Future<void> _signInWithEmailPassword() async {
  try {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
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

    // If the email is associated only with a non-password provider, show suggestion
    final providers = await _auth.fetchSignInMethodsForEmail(email);

    // Check if providers exist BUT 'password' is not one of them (e.g., only 'google.com')
    if (providers.isNotEmpty && !providers.contains('password')) {
      Navigator.pop(context); // Dismiss the LoadingScreen
      if (!mounted) return;

      String message;
      if (providers.contains('google.com')) {
        message =
            'It looks like you signed up with Google. Please use the "Continue with Google" button below.';
      } else {
        final suggestion = providers.join(', ');
        message =
            'This email is linked to a non-password account (e.g., $suggestion). Please use the appropriate sign-in method.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final UserCredential userCredential = await _auth
        .signInWithEmailAndPassword(email: email, password: password);

    final user = userCredential.user;

    if (user != null) {
      // ✅ NEW: Check if user can login (no active session on another device)
      final loginCheck = await DeviceSessionManager().canLogin(user.uid);

      if (loginCheck['canLogin'] == false) {
        // Another device is active - sign out and show dialog
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        Navigator.pop(context); // Close loading screen

        await showDialog(
          context: context,
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
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.devices_other,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Already Logged In',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your account is currently active on another device:',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loginCheck['activeDevice'] ?? 'Unknown Device',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please logout from the other device first, or wait 10 minutes for the session to expire automatically.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return; // Stop login process
      }

      if (!mounted) return;
      Navigator.pop(context);

      // ✅ NEW: Create session for this device
      await DeviceSessionManager().createSession(user.uid, context);

      // Ensure a users/{uid} doc exists but don't overwrite role/onboarding flags.
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final doc = await userDocRef.get();
      if (!doc.exists) {
        await userDocRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.email?.split('@').first ?? '',
          'emailVerified': user.emailVerified,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!')),
      );
      _navigateAfterLogin(user);
    }
  } on FirebaseAuthException catch (e) {
    try {
      Navigator.pop(context);
    } catch (_) {}
    if (!mounted) return;
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found for that email.';
        break;
      case 'wrong-password':
        message = 'Incorrect password.';
        break;
      case 'invalid-credential':
        final email = _emailController.text.trim();
        final providers = await _auth.fetchSignInMethodsForEmail(email);

        if (providers.contains('google.com')) {
          message =
              'It looks like you signed up with Google. Please use the "Continue with Google" button below.';
        } else {
          message =
              'The credential is invalid, or the account is linked to a different sign-in method.';
        }
        break;
      default:
        message = e.message ?? 'Login failed.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    logger.e('FirebaseAuthException: ${e.code} - ${e.message}');
  } catch (e) {
    try {
      Navigator.pop(context);
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
    logger.e('Unexpected error during email/password sign-in: $e');
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
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
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
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordPage(),
                    ),
                  );
                },
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(color: Color(0xFF00568D), fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ✅✅✅ START OF CHANGED SECTION ✅✅✅

            // Log in button (MOVED UP - now appears before OR divider)
            ElevatedButton(
              onPressed: _signInWithEmailPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
              child: const Text('Log in', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 20),

            // OR divider
            const Row(
              children: [
                Expanded(
                  child: Divider(color: Color(0xFF00568D), thickness: 1),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR',
                    style: TextStyle(color: Color(0xFF00568D), fontSize: 16),
                  ),
                ),
                Expanded(
                  child: Divider(color: Color(0xFF00568D), thickness: 1),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Continue with Google button
            ElevatedButton(
              onPressed: () => _signInWithGoogle(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
              child: const Text(
                'Continue with Google',
                style: TextStyle(fontSize: 16),
              ),
            ),

            // ✅✅✅ END OF CHANGED SECTION ✅✅✅
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00568D),
                  ),
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
