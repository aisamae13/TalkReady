import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'loading_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:carousel_slider/carousel_slider.dart';

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
  Future<void> _handleGoogleSignIn() async {
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
        bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? true;
        hideLoadingScreen(context);

        if (!context.mounted) return;

        if (isNewUser) {
          Navigator.pushNamed(context, '/welcome');
        } else {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              title: const Text(
                'Account Already Registered',
                style: TextStyle(
                  color: Color(0xFF00568D),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: Text(
                'Your Google account has already been used to login.',
                style: TextStyle(
                  color: Color(0xFF00568D).withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF00568D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            ),
          );
        }
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
  }

  // List of background images for the carousel
  final List<String> backgroundImages = [
    'images/callcenter.jpg',
    'images/callcenter2.jpg',
    'images/AI_Human_Hand.jpg',
  ];

  // List of corresponding header and subtext pairs
  final List<Map<String, String>> textContent = [
    {
      'header': 'Welcome to TalkReady.',
      'subtext': 'Your solution for English pronunciation training.',
    },
    {
      'header': 'Master Your Speech.',
      'subtext': 'Enhance your communication with expert guidance.',
    },
    {
      'header': 'AI-Powered Learning.',
      'subtext': 'Personalized feedback with cutting-edge technology.',
    },
  ];

  // State to track the current carousel page
  int _currentPage = 0;
final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background carousel
          CarouselSlider(
            carouselController: _carouselController,
            options: CarouselOptions(
              height: double.infinity,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.easeInOut,
              enableInfiniteScroll: true,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentPage = index;
                });
              },
            ),
            items: backgroundImages.map((imagePath) {
              return Builder(
                builder: (BuildContext context) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(imagePath),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha:0.5),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          // Foreground content
          Column(
            children: [
              // Logo at the top
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Center(
                  child: Image.asset(
                    'images/TR Logo.png',
                    height: 90,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'TalkReady',
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              // Spacer to push the header and subtext lower
              Expanded(
                flex: 5,
                child: Container(),
              ),
              // Header, subtext, and dot indicator aligned to the left
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      textContent[_currentPage]['header']!,
                      style: const TextStyle(
                        fontSize: 25,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      textContent[_currentPage]['subtext']!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 50),
                    // Dot indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: backgroundImages.asMap().entries.map((entry) {
                        int index = entry.key;
                        return Container(
                          width: 8.0,
                          height: 8.0,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha:0.4),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              // Spacer to push the blue container to the bottom
              Expanded(
                flex: 1,
                child: Container(),
              ),
              // Blue container with buttons
              Container(
                padding: const EdgeInsets.all(45),
                decoration: const BoxDecoration(
                  color: Color(0xFF00568D),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _handleGoogleSignIn(),
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
                        Expanded(child: Divider(color: Colors.white, thickness: 1)),
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
                        Expanded(child: Divider(color: Colors.white, thickness: 1)),
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
            ],
          ),
        ],
      ),
    );
  }
}
