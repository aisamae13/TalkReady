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

    final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
    await googleSignIn.signOut();

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      if (kDebugMode) {
        debugPrint('User canceled the sign-in');
      }
      return null;
    }

    if (kDebugMode) {
      debugPrint('Signed in as: ${googleUser.email}');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

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
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    if (kDebugMode) {
                      debugPrint('Button pressed, showing loading screen');
                    }
                    // Show loading screen immediately when button is pressed
                    showLoadingScreen(context);

                    // Attempt to sign in with Google
                    UserCredential? userCredential = await signInWithGoogle();

                    if (!context.mounted) {
                      if (kDebugMode) {
                        debugPrint('Context not mounted after sign-in');
                      }
                      hideLoadingScreen(context);
                      return;
                    }

                    if (userCredential != null) {
                      try {
                        // Check if this is a new user
                        bool isNewUser =
                            userCredential.additionalUserInfo?.isNewUser ??
                                true;

                        if (kDebugMode) {
                          debugPrint('Is new user: $isNewUser');
                          debugPrint('User email: ${userCredential.user?.email}');
                        }

                        // Hide loading screen before navigation
                        hideLoadingScreen(context);

                        if (!context.mounted) {
                          if (kDebugMode) {
                            debugPrint('Context not mounted before navigation');
                          }
                          return;
                        }

                        // Navigate based on user status
                        if (isNewUser) {
                          if (kDebugMode) {
                            debugPrint('Navigating to /welcome');
                          }
                          Navigator.pushNamed(context, '/welcome');
                        } else {
                          if (kDebugMode) {
                            debugPrint('Navigating to /homepage');
                          }
                          Navigator.pushNamed(context, '/homepage');
                        }
                      } catch (e) {
                        if (!context.mounted) return;

                        hideLoadingScreen(context);
                        if (kDebugMode) {
                          debugPrint('Error in try block: $e');
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error during sign-in: $e'),
                            duration: const Duration(seconds: 3),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        hideLoadingScreen(context);
                      }
                      if (kDebugMode) {
                        debugPrint('Sign-in cancelled or failed');
                      }
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.google,
                      color: Color(0xFF00568D)),
                  label: const Text('Continue with Google',
                      style: TextStyle(fontSize: 16)),
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
                      child: Text('OR',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
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
                  label: const Text('Continue with Email',
                      style: TextStyle(fontSize: 16)),
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
                        style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
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