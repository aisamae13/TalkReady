import 'package:flutter/material.dart';

class AIBotScreen extends StatelessWidget {
  const AIBotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
        'TalkReady AI Bot',
        style: TextStyle(
          color: Color.fromARGB(255, 41,115,178), // Change text color
          fontWeight: FontWeight.bold, // Makes text bold
          fontSize: 20, // Adjust text size
        ),
      ),
      backgroundColor: Colors.white, // Set AppBar background color
        actions: [
          // Timer Icon
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: const Row(
                children: [
                  Icon(Icons.timer, size: 18, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    '05:00',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: ListView.builder(
                itemCount: 5, // Example messages
                itemBuilder: (context, index) {
                  bool isUser = index % 2 == 0;
                  return ChatMessage(
                    message: isUser ? "Hello, how are you?" : "I'm fine, thank you!",
                    isUser: isUser,
                  );
                },
              ),
            ),
          ),
          // Add IconRow below messages
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: IconRow(),
          ),
        ],
      ),
    );
  }
}

// Chat Message Widget
class ChatMessage extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatMessage({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(message),
      ),
    );
  }
}

// Icon Row Widget
class IconRow extends StatelessWidget {
  const IconRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIcon(Icons.keyboard, Colors.purple.shade200),
        const SizedBox(width: 20),
        _buildIcon(Icons.mic, Colors.blue.shade300),
        const SizedBox(width: 20),
        _buildIcon(Icons.book, Colors.amber.shade200),
      ],
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}