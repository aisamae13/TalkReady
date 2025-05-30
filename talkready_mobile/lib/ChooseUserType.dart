import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_page.dart';
import 'package:talkready_mobile/next_screen.dart'; // For student flow

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
    // Navigate to WelcomePage first
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
    );
    // Then navigate to onboarding
    Navigator.pushNamed(
      context,
      '/onboarding',
      arguments: {'userType': userType},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Choose User Type'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFB2FEFA), // sky blue
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
                // Glassmorphic Card
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
                              color: Colors.blue.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
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
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Select your role to continue",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 40),
                            AnimatedUserTypeButton(
                              icon: Icons.school,
                              label: 'I am a Trainer',
                              color: Color(0xFF2196F3), // Solid blue
                              onTap: () => _saveUserTypeAndNavigate(context, 'trainer'),
                            ),
                            const SizedBox(height: 28),
                            AnimatedUserTypeButton(
                              icon: Icons.person,
                              label: 'I am a Student',
                              color: Color(0xFF2196F3), // Solid blue
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
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
      _isPressed = false;
    });
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
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isPressed)
              Container(
                width: 270,
                height: 80,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.4),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 34),
                      const SizedBox(width: 18),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}