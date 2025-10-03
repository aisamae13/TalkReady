import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_page.dart';

class ChooseUserTypePage extends StatelessWidget {
  const ChooseUserTypePage({super.key});

  Future<void> _saveUserTypeAndNavigate(BuildContext context, String userType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'userType': userType}, SetOptions(merge: true));
    }

    // Navigate to WelcomePage WITH userType
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WelcomePage(userType: userType), // Pass userType here!
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color.fromARGB(255, 178, 211, 254),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.06),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Let's get started!",
                              style: TextStyle(
                                color: Color(0xFF00568D),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Select your role to continue",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 36),
                            AnimatedUserTypeButton(
                              icon: Icons.school_rounded,
                              label: 'I am a Trainer',
                              color: const Color(0xFF2E7D32),
                              onTap: () => _saveUserTypeAndNavigate(context, 'trainer'),
                            ),
                            const SizedBox(height: 22),
                            AnimatedUserTypeButton(
                              icon: Icons.person_2_rounded,
                              label: 'I am a Student',
                              color: const Color(0xFF1565C0),
                              onTap: () => _saveUserTypeAndNavigate(context, 'student'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedUserTypeButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const AnimatedUserTypeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<AnimatedUserTypeButton> createState() => _AnimatedUserTypeButtonState();
}

class _AnimatedUserTypeButtonState extends State<AnimatedUserTypeButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.96;
      _isPressed = true;
    });
    HapticFeedback.selectionClick();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
      _isPressed = false;
    });
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.98),
                  widget.color.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.22),
                  blurRadius: _isPressed ? 6 : 20,
                  offset: Offset(0, _isPressed ? 4 : 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}