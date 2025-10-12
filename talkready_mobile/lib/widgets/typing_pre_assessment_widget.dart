// lib/widgets/typing_pre_assessment_widget.dart
import 'package:flutter/material.dart';
import '../services/unified_progress_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TypingPreAssessmentWidget extends StatefulWidget {
  final String lessonKey;
  final VoidCallback onComplete;
  final Map<String, dynamic>? assessmentData;

  const TypingPreAssessmentWidget({
    super.key,
    required this.lessonKey,
    required this.onComplete,
    this.assessmentData,
  });

  @override
  State<TypingPreAssessmentWidget> createState() =>
      _TypingPreAssessmentWidgetState();
}

class _TypingPreAssessmentWidgetState extends State<TypingPreAssessmentWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  String? _feedback;

  // ✅ ADD: Create instance of UnifiedProgressService
  final UnifiedProgressService _progressService = UnifiedProgressService();

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty) {
      setState(() => _error = "Please type your clarification question.");
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
      _feedback = null;
    });

    try {
      // ✅ FIXED: Use the service method instead of direct HTTP call
      final feedback = await _progressService.evaluateTypingPreAssessment(
        answer: answer,
        customerStatement:
            widget.assessmentData?['correctAnswerReference'] ?? '',
        lessonKey: widget.lessonKey,
      );

      if (feedback != null) {
        setState(() => _feedback = feedback);

        await _progressService.markPreAssessmentAsComplete(widget.lessonKey);

        // Wait 3 seconds before automatically proceeding to the lesson
        Future.delayed(const Duration(seconds: 3), widget.onComplete);
      } else {
        setState(() => _error = "Error fetching feedback. Try again.");
      }
    } catch (e) {
      setState(
        () => _error = "Could not connect to the server. Check network.",
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rest of your build method remains the same...
    final title = widget.assessmentData?['title'] ?? 'Pre-Lesson Check-in';
    final instruction =
        widget.assessmentData?['instruction'] ??
        'Read the customer\'s statement below...';
    final prompt = widget.assessmentData?['prompt'] ?? 'Customer states: ...';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              instruction,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              padding: const EdgeInsets.all(12),
              child: Text(
                prompt,
                style: const TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Type your clarification response...",
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              enabled: !_isSubmitting && _feedback == null,
            ),
            const SizedBox(height: 16),
            if (_feedback == null)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text(_isSubmitting ? "Checking..." : "Check Answer"),
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            if (_isSubmitting) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_feedback != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _feedback!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  "Now, let's begin the lesson...",
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
