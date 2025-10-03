import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../models/message.dart';
import 'azure_feedback_display.dart';

final logger = Logger();

class ChatMessage extends StatefulWidget {
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
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  bool _showTimestamp = false;

  String _formatTimestamp(String? isoTimestamp) {
    if (isoTimestamp == null) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(isoTimestamp).toLocal();
      if (DateTime.now().difference(dateTime).inDays == 0) {
        return DateFormat('h:mm a').format(dateTime);
      } else if (DateTime.now().difference(dateTime).inDays == 1) {
        return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
      } else {
        return DateFormat('MMM d, h:mm a').format(dateTime);
      }
    } catch (e) {
      logger.e('Error parsing timestamp: $e');
      return 'Invalid time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Handle Azure feedback messages
    if (widget.message.type == MessageType.azureFeedback && widget.message.metadata != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: AzureFeedbackDisplay(
          feedback: widget.message.metadata!,
          originalText: widget.message.metadata?['originalText'] ?? '',
        ),
      );
    }

    // Handle typing indicator
    if (widget.message.typing) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('images/talkready_bot.png'),
              backgroundColor: Colors.blueGrey[50],
            ),
            SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    widget.message.text,
                    style: TextStyle(fontSize: 15, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() => _showTimestamp = !_showTimestamp);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          crossAxisAlignment: widget.message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: widget.message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.message.isUser) ...[
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: AssetImage('images/talkready_bot.png'),
                    backgroundColor: Colors.blueGrey[50],
                  ),
                  SizedBox(width: 10),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: EdgeInsets.only(
                      top: widget.message.isUser ? 2 : 4,
                      bottom: 2,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.message.isUser
                          ? theme.primaryColor.withOpacity(0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: widget.message.isUser ? Radius.circular(16) : Radius.circular(4),
                        bottomRight: widget.message.isUser ? Radius.circular(4) : Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message.text,
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        if (widget.message.isUser && widget.message.audioPath != null && widget.onPlayAudio != null) ...[
                          SizedBox(height: 8),
                          IconButton(
                            icon: Icon(
                              widget.isPlaying ? Icons.stop : Icons.play_arrow,
                              color: theme.primaryColor,
                            ),
                            onPressed: widget.onPlayAudio,
                            tooltip: widget.isPlaying ? 'Stop playback' : 'Play your recording',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.message.isUser) ...[
                  SizedBox(width: 10),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: widget.userProfileImage,
                    child: widget.userProfileImage == null
                        ? Text(
                            widget.message.text.isNotEmpty ? widget.message.text[0].toUpperCase() : 'U',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ],
              ],
            ),
            if (_showTimestamp)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  left: widget.message.isUser ? 0 : 58,
                  right: widget.message.isUser ? 58 : 0,
                ),
                child: Text(
                  _formatTimestamp(widget.message.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}