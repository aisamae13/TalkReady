import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'loading_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
Future<UserCredential?> signInWithGoogle() async {
  try {
    if (kDebugMode) {
      debugPrint('Starting Google Sign-In');
    }

    // Initialize GoogleSignIn
    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);

    // Sign out muna para i-clear ang cached account
    await googleSignIn.signOut();

    // Trigger the Google sign-in process na may picker
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      if (kDebugMode) {
        debugPrint('User canceled the sign-in');
      }
      return null; // User canceled the login
    }

    if (kDebugMode) {
      debugPrint('Signed in as: ${googleUser.email}');
    }

    // Get authentication details
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    if (kDebugMode) {
      debugPrint('Access Token: ${googleAuth.accessToken}');
      debugPrint('ID Token: ${googleAuth.idToken}');
    }

    // Create a credential for Firebase
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase
    return await FirebaseAuth.instance.signInWithCredential(credential);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error during Google Sign-In: $e');
    }
    return null;
  }
}
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
           child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'images/logoTR.png',
                    width: 400,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Talk Ready',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(55),
            decoration: const BoxDecoration(
              color: Color(0xFF00568D),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
               ElevatedButton.icon(
                    onPressed: () async {
                      // First, attempt to sign in with Google
                      UserCredential? user = await signInWithGoogle();

                      // Then show loading screen if sign-in was successful
                      if (user != null) {
                        showLoadingScreen(context);

                        // Check if context is still mounted before proceeding
                        if (!context.mounted) return;

                        // Hide loading screen and navigate
                        hideLoadingScreen(context);
                        Navigator.pushNamed(context, '/welcome');
                      }
                    },
                  icon: const FaIcon(FontAwesomeIcons.google, color: Color(0xFF00568D)),
                  label: const Text('Continue with Google', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00568D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white, thickness: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('OR', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    Expanded(child: Divider(color: Colors.white, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                  },
                  icon: const Icon(Icons.email, color: Color(0xFF00568D)),
                  label: const Text('Continue with Email', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00568D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: <TextSpan>[
                      const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      TextSpan(
                        text: 'Log in',
                        style: const TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.bold),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pushNamed(context, '/login');
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
