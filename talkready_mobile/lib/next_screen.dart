import 'package:flutter/material.dart';
import 'homepage.dart';

class NextScreen extends StatefulWidget {
  final Map<String, dynamic> responses; // Receive onboarding responses

  const NextScreen({super.key, required this.responses});

  @override
  State<NextScreen> createState() => _NextScreenState();
}

class _NextScreenState extends State<NextScreen> {
  late List<bool> _isLoading; // Track loading state for each item
  late List<bool> _isCompleted; // Track completion state for each item

  @override
  void initState() {
    super.initState();
    // Initialize loading and completion states for 4 items
    _isLoading = List.filled(4, true); // Start with all items loading
    _isCompleted = List.filled(4, false); // None completed initially
    _simulateProcessing(); // Start the processing simulation
  }

  // Simulate processing for each item with a delay
  void _simulateProcessing() async {
    for (int i = 0; i < _isLoading.length; i++) {
      await Future.delayed(const Duration(seconds: 5)); // 5-second processing
      if (mounted) {
        setState(() {
          _isLoading[i] = false; // Stop loading
          _isCompleted[i] = true; // Mark as completed
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0), // Reduced from 20px
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20), // Top spacer
              const Text(
                'Personalizing your\nlearning plan...',
                style: TextStyle(
                  fontSize: 26, // Slightly smaller
                  color: Color(0xFF00568D),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenSize.height * 0.05), // 5% of screen height
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoading[0]
                          ? const CircularProgressIndicator(
                              color: Color(0xFF00568D),
                              strokeWidth: 2,
                            )
                          : const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00568D),
                              size: 16,
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Creating diverse topics...',
                          style: const TextStyle(fontSize: 15), // Slightly smaller
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8), // Increased for clarity
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoading[1]
                          ? const CircularProgressIndicator(
                              color: Color(0xFF00568D),
                              strokeWidth: 2,
                            )
                          : const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00568D),
                              size: 16,
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Preparing interactive dialogues...',
                          style: const TextStyle(fontSize: 15),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoading[2]
                          ? const CircularProgressIndicator(
                              color: Color(0xFF00568D),
                              strokeWidth: 2,
                            )
                          : const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00568D),
                              size: 16,
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Optimizing your learning path...',
                          style: const TextStyle(fontSize: 15),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoading[3]
                          ? const CircularProgressIndicator(
                              color: Color(0xFF00568D),
                              strokeWidth: 2,
                            )
                          : const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00568D),
                              size: 16,
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Finalizing your plan...',
                          style: const TextStyle(fontSize: 15),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: screenSize.height * 0.03), // 3% of screen height
              Container(
                width: screenSize.width * 0.4, // 40% of screen width
                height: screenSize.width * 0.4, // Square aspect ratio
                decoration: const BoxDecoration(
                  color: Colors.white,
                  image: DecorationImage(
                    image: AssetImage('images/get-plan.png'),
                    fit: BoxFit.contain, // Changed to contain
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.03),
              ElevatedButton(
                onPressed: _isLoading.contains(true)
                    ? null // Disable until all items are loaded
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HomePage()),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00568D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Get My Plan',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16), // Bottom spacer
            ],
          ),
        ),
      ),
    );
  }
}