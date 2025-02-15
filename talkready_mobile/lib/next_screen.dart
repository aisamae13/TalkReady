import 'package:flutter/material.dart';
import 'homepage.dart';
class NextScreen extends StatelessWidget {
  const NextScreen({super.key});

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
              padding: EdgeInsets.only(top: 10), // Add margin-top here
              child: Text(
                'Personalizing your\nlearning plan...',
                style: TextStyle(fontSize: 28, color: Color(0xFF00568D), fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 50),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00568D), size: 16),
                    SizedBox(width: 10),
                    Text('Creating diverse topics', style: TextStyle(fontSize: 16)),
                  ],
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00568D), size: 16),
                    SizedBox(width: 10),
                    Text('Preparing interactive dialogues', style: TextStyle(fontSize: 16)),
                  ],
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00568D), size: 16),
                    SizedBox(width: 10),
                    Text('Optimizing your learning path', style: TextStyle(fontSize: 16)),
                  ],
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00568D), size: 16),
                    SizedBox(width: 10),
                    Text('Finalizing your plan', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30), // Adjust this value as needed
            Container(
              width: 140,
              height: 100,
              color: Colors.grey[300],
              child: const Center(child: Text('Image', style: TextStyle(fontSize: 24))),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
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