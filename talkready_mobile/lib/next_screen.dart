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

  // Simulate processing for each item with a delay (e.g., 1 second per item)
  void _simulateProcessing() async {
    for (int i = 0; i < _isLoading.length; i++) {
      await Future.delayed(const Duration(seconds: 5)); // Simulate 1-second processing
      setState(() {
        _isLoading[i] = false; // Stop loading for this item
        _isCompleted[i] = true; // Mark as completed
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 5), // Add margin-top here
              child: Text(
                'Personalizing your\nlearning plan...',
                style: TextStyle(
                  fontSize: 28,
                  color: Color(0xFF00568D),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 50),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align items at the start for better wrapping
                  children: [
                    _isLoading[0]
                        ? const CircularProgressIndicator(
                            color: Color(0xFF00568D),
                            strokeWidth: 2,
                          )
                        : const Icon(Icons.check_circle, color: Color(0xFF00568D), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Creating diverse topics...',
                        style: const TextStyle(fontSize: 16),
                        softWrap: true, // Allow text to wrap to multiple lines
                        overflow: TextOverflow.ellipsis, // Fallback to truncate if needed (optional)
                        textAlign: TextAlign.start, // Align text to the start for better readability
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isLoading[1]
                        ? const CircularProgressIndicator(
                            color: Color(0xFF00568D),
                            strokeWidth: 2,
                          )
                        : const Icon(Icons.check_circle, color: Color(0xFF00568D), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Preparing interactive dialogues...',
                        style: const TextStyle(fontSize: 16),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isLoading[2]
                        ? const CircularProgressIndicator(
                            color: Color(0xFF00568D),
                            strokeWidth: 2,
                          )
                        : const Icon(Icons.check_circle, color: Color(0xFF00568D), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Optimizing your learning path...',
                        style: const TextStyle(fontSize: 16),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isLoading[3]
                        ? const CircularProgressIndicator(
                            color: Color(0xFF00568D),
                            strokeWidth: 2,
                          )
                        : const Icon(Icons.check_circle, color: Color(0xFF00568D), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Finalizing your plan...',
                        style: const TextStyle(fontSize: 16),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 30), // Adjust this value as needed
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  image: DecorationImage(
                    image: AssetImage('images/get-plan.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Process the responses further if needed (e.g., save to Firestore, generate a plan)
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Get My Plan', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}