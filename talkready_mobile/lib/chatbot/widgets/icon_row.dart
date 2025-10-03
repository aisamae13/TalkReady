import 'package:flutter/material.dart';
import '../screens/tutorial_service.dart';

class IconRow extends StatelessWidget {
  final VoidCallback onMicTap;
  final VoidCallback onKeyboardTap;
  final bool isListening;
  final bool isTyping;
  final GlobalKey micKey;
  final GlobalKey keyboardKey;

  const IconRow({
    super.key,
    required this.onMicTap,
    required this.onKeyboardTap,
    required this.isListening,
    required this.isTyping,
    required this.micKey,
    required this.keyboardKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TutorialService.buildShowcase(
          context: context,
          key: keyboardKey,
          title: 'Keyboard Input',
          description: 'Type your message here.',
          targetShapeBorder: CircleBorder(),
          child: _buildIcon(
            Icons.keyboard_alt_outlined,
            isTyping ? theme.colorScheme.primary.withOpacity(0.5) : theme.colorScheme.secondary,
            onKeyboardTap,
            isActive: isTyping,
            tooltip: 'Type message',
          ),
        ),
        TutorialService.buildShowcase(
          context: context,
          key: micKey,
          title: 'Microphone',
          description: 'Record your voice here.',
          targetShapeBorder: CircleBorder(),
          child: _buildIcon(
            isListening ? Icons.stop_circle_outlined : Icons.mic_none_outlined,
            isListening ? Colors.red.shade400 : theme.primaryColor,
            onMicTap,
            isActive: isListening,
            tooltip: isListening ? 'Stop recording' : 'Start recording',
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(IconData icon, Color color, VoidCallback onTap, {bool isActive = false, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.8) : color.withOpacity(0.7),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isActive ? 0.2 : 0.1),
                spreadRadius: isActive ? 2 : 1,
                blurRadius: isActive ? 4 : 2,
                offset: Offset(0, isActive ? 2 : 1),
              ),
            ],
            border: isActive ? Border.all(color: Colors.white.withOpacity(0.7), width: 2) : null,
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}