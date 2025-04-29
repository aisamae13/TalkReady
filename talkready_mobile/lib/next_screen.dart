import 'package:flutter/material.dart';
import 'homepage.dart';

class NextScreen extends StatefulWidget {
  final Map<String, dynamic> responses;

  const NextScreen({super.key, required this.responses});

  @override
  State<NextScreen> createState() => _NextScreenState();
}

class _NextScreenState extends State<NextScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final List<String> _features = [
    'AI-Powered Pronunciation Analysis',
    'Real Call Scenario Simulations',
    'Vocabulary Building Exercises',
    'Personalized Feedback System',
  ];

  int _currentFeatureIndex = 0;
  bool _showButton = false;
  bool _isLoadingFeature = true;
  bool _showAllFeatures = false;
  final List<bool> _completedFeatures = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _controller.forward();

    for (int i = 0; i < _features.length; i++) {
      setState(() {
        _currentFeatureIndex = i;
        _isLoadingFeature = true;
      });

      await Future.delayed(const Duration(seconds: 2));
      setState(() => _isLoadingFeature = false);

      await Future.delayed(const Duration(seconds: 1));
      _completedFeatures.add(true);

      if (i == _features.length - 1) {
        setState(() {
          _showAllFeatures = true;
          _showButton = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Itinaas na Title
                  SizedBox(height: screenSize.height * 0.04),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF00568D), Color(0xFF00A6CB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'Personalizing Your Learning Plan',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // GIF Container
                  Center(
                    child: Container(
                      height: screenSize.height * 0.23,
                      width: screenSize.width * 0.7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'images/AI.gif',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Features List
                     _showAllFeatures
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 20, top: 15),
                              child: Column(
                                children: _features.map((feature) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        child: ShaderMask(
                                          shaderCallback: (bounds) => const LinearGradient(
                                            colors: [Color(0xFF00568D), Color(0xFF00A6CB)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                          child: const Icon(
                                            Icons.check_circle_outlined,
                                            size: 22,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            feature,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                              height: 1.4,
                                            ),
                                            textAlign: TextAlign.left,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                        )
                       : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: screenSize.width * 0.9,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: Container(
                              key: ValueKey<int>(_currentFeatureIndex),
                              padding: const EdgeInsets.only(left: 20, top: 15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _isLoadingFeature
                                        ? ClipOval( // Added ClipOval to prevent square background
                                            child: ShaderMask(
                                              shaderCallback: (bounds) => const LinearGradient(
                                                colors: [Color(0xFF00568D), Color(0xFF00A6CB)],
                                              ).createShader(bounds),
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                color: Colors.transparent, // Added transparent background
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 3,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                                  backgroundColor: Colors.transparent, // Remove default background
                                                ),
                                              ),
                                            ),
                                          )
                                        : ShaderMask(
                                            shaderCallback: (bounds) => const LinearGradient(
                                              colors: [Color(0xFF00568D), Color(0xFF00A6CB)],
                                            ).createShader(bounds),
                                            child: const Icon(
                                              Icons.check_circle_outlined, // Changed to outlined icon
                                              size: 22,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        _features[_currentFeatureIndex],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                  // Button
                 if (_showButton)
                    Padding(
                      padding: const EdgeInsets.only(top: 35),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const HomePage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00568D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              // Removed borderSide property
                            ),
                            elevation: 5,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.rocket_launch_outlined,
                                size: 20,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'LAUNCH MY TRAINING',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}