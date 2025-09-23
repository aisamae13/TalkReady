// lib/widgets/typing_pre_assessment_widget.dart
import 'package:flutter/material.dart';
import '../services/unified_progress_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TypingPreAssessmentWidget extends StatefulWidget {
  final String lessonKey;
  final VoidCallback onComplete;
  final Map<String, dynamic>?
  assessmentData; // <-- ADD THIS: To receive the data

  const TypingPreAssessmentWidget({
    super.key,
    required this.lessonKey,
    required this.onComplete,
    this.assessmentData, // <-- ADD THIS: In the constructor
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
      // --- THIS IS THE CORRECTED API CALL ---
      final response = await http.post(
        Uri.parse('http://192.168.254.103:5000/evaluate-preassessment-typing'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // The server expects 'userAnswer' and 'correctAnswerReference'
          'userAnswer': answer,
          'correctAnswerReference':
              widget.assessmentData?['correctAnswerReference'],
        }),
      );
      // --- END OF FIX ---

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feedbackText = data['feedback'] ?? "Evaluation complete.";
        setState(() => _feedback = feedbackText);

        await UnifiedProgressService().markPreAssessmentAsComplete(
          widget.lessonKey,
        );

        // Wait 3 seconds before automatically proceeding to the lesson
        Future.delayed(const Duration(seconds: 3), widget.onComplete);
      } else {
        // This is the error you were seeing, caused by the server rejecting the request
        setState(() => _error = "Error fetching feedback. Try again.");
      }
    } catch (e) {
      // This error would happen for network issues (e.g., wrong IP address)
      setState(
        () => _error = "Could not connect to the server. Check network.",
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically get content from the assessmentData map
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
                    title, // <-- DYNAMIC
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
              instruction, // <-- DYNAMIC
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
                prompt, // <-- DYNAMIC
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
