import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class InteractiveText extends StatefulWidget {
  final String text;
  final Map<String, String> definitions;
  final TextStyle? baseTextStyle;
  final TextStyle? clickableTextStyle;

  const InteractiveText({
    super.key,
    required this.text,
    required this.definitions,
    this.baseTextStyle,
    this.clickableTextStyle,
  });

  @override
  State<InteractiveText> createState() => _InteractiveTextState();
}

class _InteractiveTextState extends State<InteractiveText> {
  bool _isModalOpen = false;
  String _modalContent = '';
  String _modalTitle = '';

  void _handleWordClick(String key) {
    if (widget.definitions.containsKey(key)) {
      // Capitalize the first letter for the title
      final title = key[0].toUpperCase() + key.substring(1);
      setState(() {
        _modalTitle = 'Definition: $title';
        _modalContent = widget.definitions[key]!;
        _isModalOpen = true;
      });
    }
  }

  List<TextSpan> _parseText() {
    if (widget.text.isEmpty || widget.definitions.isEmpty) {
      return [
        TextSpan(
          text: widget.text,
          style: widget.baseTextStyle ?? const TextStyle(color: Colors.black87),
        )
      ];
    }

    // Create a list of definition keys
    final keys = widget.definitions.keys.toList();
    if (keys.isEmpty) {
      return [
        TextSpan(
          text: widget.text,
          style: widget.baseTextStyle ?? const TextStyle(color: Colors.black87),
        )
      ];
    }

    // Sort keys by length, longest first, to match phrases before individual words
    keys.sort((a, b) => b.length.compareTo(a.length));

    // Create regex pattern from all keys
    final pattern = keys.map((key) => RegExp.escape(key)).join('|');
    final regex = RegExp('($pattern)', caseSensitive: false);

    // Split text by the regex pattern
    final parts = widget.text.split(regex);
    final matches = regex.allMatches(widget.text).map((m) => m.group(0)!).toList();

    List<TextSpan> spans = [];
    int matchIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      // Add regular text part
      if (parts[i].isNotEmpty) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: widget.baseTextStyle ?? 
                   const TextStyle(
                     color: Colors.black87,
                     height: 1.5,
                   ),
          ),
        );
      }

      // Add clickable match if there's one available
      if (matchIndex < matches.length) {
        final match = matches[matchIndex];
        final lowerCaseMatch = match.toLowerCase();
        
        if (widget.definitions.containsKey(lowerCaseMatch)) {
          spans.add(
            TextSpan(
              text: match,
              style: widget.clickableTextStyle ?? 
                     const TextStyle(
                       color: Color(0xFF2563EB), // Blue color
                       fontWeight: FontWeight.bold,
                       decoration: TextDecoration.underline,
                       height: 1.5,
                     ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _handleWordClick(lowerCaseMatch),
            ),
          );
        } else {
          // If somehow the match isn't in definitions, treat as regular text
          spans.add(
            TextSpan(
              text: match,
              style: widget.baseTextStyle ?? 
                     const TextStyle(
                       color: Colors.black87,
                       height: 1.5,
                     ),
            ),
          );
        }
        matchIndex++;
      }
    }

    return spans;
  }

  void _closeModal() {
    setState(() {
      _isModalOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: _parseText(),
          ),
        ),
        
        // Modal overlay
        if (_isModalOpen)
          _DefinitionModal(
            title: _modalTitle,
            content: _modalContent,
            onClose: _closeModal,
          ),
      ],
    );
  }
}

// Custom Modal Widget for Definitions
class _DefinitionModal extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onClose;

  const _DefinitionModal({
    required this.title,
    required this.content,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClose,
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Content
                  Text(
                    content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Close button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Alternative implementation using showDialog
class InteractiveTextWithDialog extends StatelessWidget {
  final String text;
  final Map<String, String> definitions;
  final TextStyle? baseTextStyle;
  final TextStyle? clickableTextStyle;

  const InteractiveTextWithDialog({
    super.key,
    required this.text,
    required this.definitions,
    this.baseTextStyle,
    this.clickableTextStyle,
  });

  void _handleWordClick(BuildContext context, String key) {
    if (definitions.containsKey(key)) {
      final title = key[0].toUpperCase() + key.substring(1);
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Definition: $title'),
            content: Text(
              definitions[key]!,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  List<TextSpan> _parseText(BuildContext context) {
    if (text.isEmpty || definitions.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: baseTextStyle ?? const TextStyle(color: Colors.black87),
        )
      ];
    }

    final keys = definitions.keys.toList();
    if (keys.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: baseTextStyle ?? const TextStyle(color: Colors.black87),
        )
      ];
    }

    keys.sort((a, b) => b.length.compareTo(a.length));
    final pattern = keys.map((key) => RegExp.escape(key)).join('|');
    final regex = RegExp('($pattern)', caseSensitive: false);

    final parts = text.split(regex);
    final matches = regex.allMatches(text).map((m) => m.group(0)!).toList();

    List<TextSpan> spans = [];
    int matchIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: baseTextStyle ?? 
                   const TextStyle(
                     color: Colors.black87,
                     height: 1.5,
                   ),
          ),
        );
      }

      if (matchIndex < matches.length) {
        final match = matches[matchIndex];
        final lowerCaseMatch = match.toLowerCase();
        
        if (definitions.containsKey(lowerCaseMatch)) {
          spans.add(
            TextSpan(
              text: match,
              style: clickableTextStyle ?? 
                     const TextStyle(
                       color: Color(0xFF2563EB),
                       fontWeight: FontWeight.bold,
                       decoration: TextDecoration.underline,
                       height: 1.5,
                     ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _handleWordClick(context, lowerCaseMatch),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: match,
              style: baseTextStyle ?? 
                     const TextStyle(
                       color: Colors.black87,
                       height: 1.5,
                     ),
            ),
          );
        }
        matchIndex++;
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: _parseText(context),
      ),
    );
  }
}