import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class TypingPreAssessment extends StatefulWidget {
  final VoidCallback onComplete;
  final Map<String, dynamic> assessmentData;

  const TypingPreAssessment({
    super.key,
    required this.onComplete,
    required this.assessmentData,
  });

  @override
  _TypingPreAssessmentState createState() => _TypingPreAssessmentState();
}

class _TypingPreAssessmentState extends State<TypingPreAssessment>
    with TickerProviderStateMixin {
  final TextEditingController _answerController = TextEditingController();
  Map<String, dynamic>? _feedback;
  bool _isLoading = false;
  
  late AnimationController _slideController;
  late AnimationController _feedbackController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    ));

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }

  Future<void> _handleCheckAnswer() async {
    if (_answerController.text.trim().isEmpty || _isLoading) return;

    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/evaluate-preassessment-typing'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userAnswer': _answerController.text.trim(),
          'correctAnswerReference': widget.assessmentData['correctAnswerReference'],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() => _feedback = result);
        
        // Trigger feedback animation
        _feedbackController.forward();
        
        // Wait 4 seconds before proceeding to lesson
        Timer(const Duration(seconds: 4), () {
          if (mounted) {
            widget.onComplete();
          }
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error submitting pre-assessment: $error");
      setState(() {
        _feedback = {
          'isCorrect': false,
          'feedback': 'Could not connect to the server for evaluation.'
        };
      });
      _feedbackController.forward();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _slideController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildInstruction(),
              const SizedBox(height: 20),
              _buildQuestionSection(),
              const SizedBox(height: 24),
              if (_feedback == null) _buildCheckButton(),
              if (_feedback != null) _buildFeedbackSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.lightbulb,
            color: Colors.yellow[700],
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.assessmentData['title'] ?? 'Pre-Assessment',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3066be),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstruction() {
    return Text(
      widget.assessmentData['instruction'] ?? '',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[700],
        height: 1.5,
      ),
    );
  }

  Widget _buildQuestionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50] ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.assessmentData['prompt'] != null) ...[
            Text(
              widget.assessmentData['prompt'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            widget.assessmentData['question'] ?? 'Please provide your answer:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            decoration: InputDecoration(
              hintText: 'Type your response here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3066be)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            minLines: 3,
            enabled: !_isLoading && _feedback == null,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    final bool isAnswerEmpty = _answerController.text.trim().isEmpty;
    
    return Center(
      child: ElevatedButton.icon(
        onPressed: isAnswerEmpty || _isLoading ? null : _handleCheckAnswer,
        icon: _isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check_circle, size: 18),
        label: Text(
          _isLoading ? 'Checking...' : 'Check Answer',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isAnswerEmpty || _isLoading 
              ? Colors.grey[400] 
              : Colors.green[500],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: isAnswerEmpty || _isLoading ? 0 : 3,
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    if (_feedback == null) return const SizedBox.shrink();

    final bool isCorrect = _feedback!['isCorrect'] ?? false;
    final String feedbackText = _feedback!['feedback'] ?? '';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCorrect ? Colors.green[500] : Colors.orange[500],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isCorrect ? Colors.green : Colors.orange).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedbackText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Now, let's begin the lesson...",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}