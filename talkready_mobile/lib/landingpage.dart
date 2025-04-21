import 'package:firebase_auth/firebase_auth.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart' hide CarouselController;
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

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  int _currentSlide = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Horizontal Carousel Section
          Column(
            children: [
              CarouselSlider(
                carouselController: _carouselController,
                options: CarouselOptions(
                  height: 400,
                  viewportFraction: 1.0,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 5),
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                  enlargeCenterPage: true,
                  scrollDirection: Axis.horizontal,
                  onPageChanged: (index, reason) {
                    setState(() => _currentSlide = index);
                  },
                  autoPlayCurve: Curves.easeInOut,
                  pauseAutoPlayOnTouch: true,
                  scrollPhysics: const BouncingScrollPhysics(),
                ),
                items: [
                  _buildSlide(
                    'images/TR Logo.png',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Welcome to ',
                          style: TextStyle(
                            fontSize: 22,
                            color: Color(0xFF00568D),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Image.asset(
                          'images/TR Text (1).png',
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Text(
                            'TalkReady',
                            style: TextStyle(
                              fontSize: 22,
                              color: Color(0xFF00568D),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSlide(
                    'images/carousel-img-1.png',
                    const Text(
                      'Practice Conversations',
                      style: TextStyle(
                        fontSize: 22,
                        color: Color(0xFF00568D),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildSlide(
                    'images/carousel-img-2.gif',
                    const Text(
                      'AI-Powered Feedback',
                      style: TextStyle(
                        fontSize: 22,
                        color: Color(0xFF00568D),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildSlide(
                    'images/carousel-img-3.png',
                    const Text(
                      'Track Your Progress',
                      style: TextStyle(
                        fontSize: 22,
                        color: Color(0xFF00568D),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              // Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentSlide == index ? 12 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentSlide == index
                          ? const Color(0xFF00568D)
                          : Colors.grey.withValues(alpha: 0.5),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
            ],
          ),

          // Bottom Button Section
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(55),
              decoration: const BoxDecoration(
                color: Color(0xFF00568D),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (kDebugMode) {
                        debugPrint('Button pressed, showing loading screen');
                      }
                      showLoadingScreen(context);
                      UserCredential? userCredential = await signInWithGoogle();

                      if (!context.mounted) {
                        hideLoadingScreen(context);
                        return;
                      }

                      if (userCredential != null) {
                        try {
                          bool isNewUser =
                              userCredential.additionalUserInfo?.isNewUser ??
                                  true;

                          hideLoadingScreen(context);

                          if (!context.mounted) return;

                          Navigator.pushNamed(
                            context,
                            isNewUser ? '/welcome' : '/homepage',
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          hideLoadingScreen(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error during sign-in: $e'),
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) hideLoadingScreen(context);
                      }
                    },
                    icon: const FaIcon(
                      FontAwesomeIcons.google,
                      color: Color(0xFF00568D),
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 16),
                    ),
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
                      Expanded(
                          child: Divider(color: Colors.white, thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(color: Colors.white, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    icon: const Icon(
                      Icons.email,
                      color: Color(0xFF00568D),
                    ),
                    label: const Text(
                      'Continue with Email',
                      style: TextStyle(fontSize: 16),
                    ),
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
                            fontWeight: FontWeight.bold,
                          ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(String imagePath, Widget title) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey<String>(imagePath),
        margin: const EdgeInsets.all(8),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                maxWidth: MediaQuery.sizeOf(context).width * 0.8,
              ),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.error,
                  size: 100,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: title,
              ),
            ),
          ],
        ),
      ),
    );
  }
}