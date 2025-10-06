// Updated chat_message.dart to handle both feedback types
import 'package:flutter/material.dart';
import '../models/message.dart';
import 'azure_feedback_display.dart';
import 'azure_fluency_display.dart'; // NEW import

class ChatMessage extends StatelessWidget {
  final Message message;
  final ImageProvider? userProfileImage;
  final VoidCallback? onPlayAudio;
  final bool isPlaying;

  const ChatMessage({
    super.key,
    required this.message,
    this.userProfileImage,
    this.onPlayAudio,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message.typing) {
      return _buildTypingIndicator();
    }

    // Handle Azure Pronunciation Feedback
    if (message.type == MessageType.azureFeedback) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              backgroundImage: AssetImage('images/talkready_bot.png'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AzureFeedbackDisplay(
                feedback: message.metadata ?? {},
                originalText: message.metadata?['originalText'],
              ),
            ),
          ],
        ),
      );
    }

    // Handle Azure Fluency Feedback (NEW)
    if (message.type == MessageType.azureFluency) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              backgroundImage: AssetImage('images/talkready_bot.png'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AzureFluencyDisplay(
                feedback: message.metadata ?? {},
                originalText: message.metadata?['originalText'],
              ),
            ),
          ],
        ),
      );
    }

    // Regular message display
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              backgroundImage: AssetImage('images/talkready_bot.png'),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? const Color.fromARGB(255, 41, 115, 178)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: message.isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (message.isUser && message.audioPath != null && onPlayAudio != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: isPlaying ? null : onPlayAudio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isPlaying ? Colors.grey.shade300 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPlaying ? Colors.grey.shade400 : Colors.blue.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPlaying ? Icons.volume_up : Icons.play_arrow,
                            size: 16,
                            color: isPlaying ? Colors.grey.shade600 : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPlaying ? 'Playing...' : 'Play recording',
                            style: TextStyle(
                              fontSize: 12,
                              color: isPlaying ? Colors.grey.shade600 : Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              backgroundImage: userProfileImage,
              child: userProfileImage == null
                  ? Icon(Icons.person, color: Colors.grey.shade600, size: 20)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Icon(Icons.smart_toy, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: (value + index * 0.3) % 1.0,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}