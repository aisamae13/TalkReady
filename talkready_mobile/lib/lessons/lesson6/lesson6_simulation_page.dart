// lib/lessons/lesson6/lesson6_simulation_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/unified_progress_service.dart';
import 'package:logger/logger.dart';

class Lesson6SimulationPage extends StatefulWidget {
  const Lesson6SimulationPage({super.key});

  @override
  State<Lesson6SimulationPage> createState() => _Lesson6SimulationPageState();
}

class _Lesson6SimulationPageState extends State<Lesson6SimulationPage> {
  final Logger _logger = Logger();
  final UnifiedProgressService _progressService = UnifiedProgressService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Core state management
  String _currentPhase = 'scenario_selection';
  Map<String, dynamic>? _selectedScenario;
  List<Map<String, dynamic>> _transcript = [];
  String _aiVoice = 'female';
  bool _isListening = false;
  bool _isAiSpeaking = false;
  bool _isLoadingAiResponse = false;
  int _timer = 180; // 3 minutes
  Timer? _callTimer;
  Map<String, dynamic>? _feedbackReport;
  int _attemptNumber = 1;
  bool _isLoading = false;
  String? _currentRecordingPath;

  bool _isRecording = false;
  bool _isProcessingAudio = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  int _recordingDuration = 0; // in seconds

  // Enhanced state for interactive features
  String? _selectedCriterion;
  bool _isTranscriptExpanded = false;
  String _activeTab = 'overview';

  // Scenarios data (matching web version)
  final List<Map<String, dynamic>> _scenarios = [
    {
      'id': 'tech_support',
      'title': 'Technical Support: Unstable Internet',
      'description':
          'Handle a frustrated customer whose internet service is not working.',
      'icon': Icons.wifi_off,
      'color': const Color(0xFFEF4444),
      'briefing': {
        'role': 'Customer Support Agent',
        'company': 'ConnectNet ISP',
        'callerNames': {'male': 'John Carter', 'female': 'Jane Carter'},
        'situation':
            'The customer\'s home internet has been unstable for two days. Your goal is to diagnose the problem, show empathy, and provide a solution.',
      },
      'system_prompt':
          'You are an AI acting as a customer whose home internet has been unstable for two days. Stay in character. Keep your responses concise and conversational.',
    },
    {
      'id': 'billing_dispute',
      'title': 'Billing Inquiry: Unrecognized Charge',
      'description':
          'Assist a confused customer who has found an unexpected charge on their monthly bill.',
      'icon': Icons.receipt_long,
      'color': const Color(0xFF3B82F6),
      'briefing': {
        'role': 'Billing Specialist',
        'company': 'Global Services Inc.',
        'callerNames': {'male': 'Mario Reyes', 'female': 'Maria Reyes'},
        'situation':
            'The customer has found a \$15 \'Service Fee\' on their bill that they don\'t recognize. Your goal is to investigate the charge, explain it clearly, and offer a resolution.',
      },
      'system_prompt':
          'You are an AI acting as a polite but confused customer who has a question about a \$15 charge on their bill. Stay in character. Ask questions to understand the fee.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAttemptNumber();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAttemptNumber() async {
    try {
      final attempts = await _progressService.getLessonAttempts('Lesson-6-1');
      setState(() {
        _attemptNumber = attempts.length + 1;
      });
    } catch (e) {
      _logger.e('Error loading attempt number: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _buildCurrentPhase(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String title = 'Advanced Call Simulation';

    switch (_currentPhase) {
      case 'scenario_selection':
        title = 'Choose Your Challenge';
        break;
      case 'briefing':
        title = _selectedScenario?['title'] ?? 'Briefing';
        break;
      case 'live':
        title = 'Live Call - ${_formatTime(_timer)}';
        break;
      case 'feedback':
        title = 'Performance Review';
        break;
    }

    return AppBar(
      backgroundColor: _getPhaseColor(),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _handleBackPress,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: _currentPhase == 'live'
          ? [
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_timer),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ]
          : null,
    );
  }

  Color _getPhaseColor() {
    switch (_currentPhase) {
      case 'scenario_selection':
        return const Color(0xFF3B82F6);
      case 'briefing':
        return const Color(0xFF8B5CF6);
      case 'live':
        return const Color(0xFF10B981);
      case 'feedback':
        return const Color(0xFF1E40AF);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _handleBackPress() {
    switch (_currentPhase) {
      case 'scenario_selection':
        Navigator.pop(context);
        break;
      case 'briefing':
        setState(() {
          _currentPhase = 'scenario_selection';
          _selectedScenario = null;
        });
        break;
      case 'live':
        _showEndCallConfirmation();
        break;
      case 'feedback':
        _showFeedbackExitConfirmation();
        break;
    }
  }

  Widget _buildCurrentPhase() {
    switch (_currentPhase) {
      case 'scenario_selection':
        return _buildScenarioSelection();
      case 'briefing':
        return _buildBriefing();
      case 'live':
        return _buildLiveCall();
      case 'feedback':
        return _buildFeedback();
      default:
        return _buildScenarioSelection();
    }
  }

  Widget _buildScenarioSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Challenge',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a scenario to begin your live call simulation.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ..._scenarios.map((scenario) => _buildScenarioCard(scenario)),
          const SizedBox(height: 20),
          _buildScenarioTips(),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(Map<String, dynamic> scenario) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectScenario(scenario),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (scenario['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        scenario['icon'] as IconData,
                        size: 32,
                        color: scenario['color'] as Color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scenario['title'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scenario['description'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: const Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Tips for Success',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Listen carefully to the customer\'s concerns\n'
            '• Ask clarifying questions when needed\n'
            '• Speak clearly and at a natural pace\n'
            '• Show empathy and professionalism\n'
            '• Provide specific solutions to problems',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1E293B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefing() {
    if (_selectedScenario == null) return const SizedBox();

    final briefing = _selectedScenario!['briefing'] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedScenario!['title'] as String,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          _buildBriefingCard(briefing),
          const SizedBox(height: 24),
          _buildVoiceSelection(),
          const SizedBox(height: 24),
          _buildReadinessCheck(),
          const SizedBox(height: 32),
          _buildBriefingActions(),
        ],
      ),
    );
  }

  Widget _buildBriefingCard(Map<String, dynamic> briefing) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Call Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildBriefingItem('Your Role:', briefing['role'] as String),
          _buildBriefingItem('Company:', briefing['company'] as String),
          _buildBriefingItem(
            'Caller:',
            (briefing['callerNames'] as Map<String, dynamic>)[_aiVoice]
                as String,
          ),
          _buildBriefingItem('Situation:', briefing['situation'] as String),
        ],
      ),
    );
  }

  Widget _buildBriefingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Voice Selection',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildVoiceOption(
                  'female',
                  'Female Voice',
                  Icons.person,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVoiceOption(
                  'male',
                  'Male Voice',
                  Icons.person_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceOption(String value, String label, IconData icon) {
    final isSelected = _aiVoice == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _aiVoice = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessCheck() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: const Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Ready to Start?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Make sure you\'re in a quiet environment with a stable internet connection. The call will last up to 3 minutes.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1E293B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _startCall,
            icon: const Icon(Icons.call, size: 24),
            label: const Text(
              'Start Call',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () {
              setState(() {
                _currentPhase = 'scenario_selection';
                _selectedScenario = null;
              });
            },
            child: const Text(
              'Choose Different Scenario',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveCall() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF10B981), const Color(0xFF059669)],
        ),
      ),
      child: Column(
        children: [
          // Call header info (keep existing)
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_selectedScenario!['briefing']['callerNames']
                                  as Map<String, dynamic>)[_aiVoice]
                              as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _selectedScenario!['briefing']['company'] as String,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Call in Progress - ${_formatTime(_timer)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Transcript area (keep existing)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Call Transcript',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _transcript.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mic_none,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Conversation will appear here...',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _transcript.length,
                            itemBuilder: (context, index) {
                              final entry = _transcript[index];
                              final isUser = entry['speaker'] == 'User';

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: isUser
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                            0.7,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? const Color(0xFF3B82F6)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isUser
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isUser ? 'You' : 'Customer',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isUser
                                                  ? Colors.white70
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            entry['text'] as String,
                                            style: TextStyle(
                                              color: isUser
                                                  ? Colors.white
                                                  : const Color(0xFF1E293B),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // UPDATED: Much more user-friendly controls
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Recording status with duration
                if (_isRecording || _isProcessingAudio)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isRecording ? Colors.red : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isRecording) ...[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _buildPulsingDot(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '🎤 Recording: ${_formatRecordingTime(_recordingDuration)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ] else if (_isProcessingAudio) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '🤖 Processing your message...',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Main status text
                if (!_isRecording && !_isProcessingAudio)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isAiSpeaking
                          ? '🔊 Customer is speaking...'
                          : '💬 Tap the microphone to speak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // End call button
                    _buildControlButton(
                      icon: Icons.call_end,
                      color: const Color(0xFFEF4444),
                      onTap: _showEndCallConfirmation,
                      size: 64,
                      enabled: !_isProcessingAudio,
                    ),

                    // UPDATED: Much better microphone button
                    _buildMicrophoneButton(),

                    // Placeholder for symmetry
                    Container(width: 64, height: 64),
                  ],
                ),

                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    _isRecording
                        ? '💡 Tap the microphone again to stop recording and send your message'
                        : _isProcessingAudio
                        ? '⏳ Please wait while we process your message...'
                        : '💡 Tap the microphone to start recording. Speak clearly and naturally.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Pulsing dot animation for recording
  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.5, end: 1.0),
      onEnd: () {
        if (mounted && _isRecording) {
          setState(() {}); // Restart animation
        }
      },
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(value),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }

  // NEW: Much better microphone button
  Widget _buildMicrophoneButton() {
    Color buttonColor;
    IconData buttonIcon;
    double buttonSize = 80;

    if (_isRecording) {
      buttonColor = const Color(0xFFEF4444);
      buttonIcon = Icons.stop;
    } else if (_isProcessingAudio) {
      buttonColor = const Color(0xFFF59E0B);
      buttonIcon = Icons.hourglass_empty;
    } else if (_isAiSpeaking) {
      buttonColor = Colors.grey[400]!;
      buttonIcon = Icons.mic_off;
    } else {
      buttonColor = Colors.white;
      buttonIcon = Icons.mic;
    }

    bool isEnabled = !_isAiSpeaking && !_isProcessingAudio;

    return GestureDetector(
      onTap: isEnabled ? _handleMicrophoneTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: buttonColor.withOpacity(0.3),
                    blurRadius: _isRecording ? 25 : 15,
                    spreadRadius: _isRecording ? 6 : 3,
                  ),
                ]
              : [],
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: _isRecording ? 1.1 : 1.0,
          child: Icon(
            buttonIcon,
            color: _isRecording || !isEnabled
                ? Colors.white
                : const Color(0xFF10B981),
            size: 36,
          ),
        ),
      ),
    );
  }

  // NEW: Reusable control button
  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double size,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: enabled ? color : Colors.grey[400],
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.4),
      ),
    );
  }

  // UPDATED: Simple tap-to-record functionality
  void _handleMicrophoneTap() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  Widget _buildFeedback() {
    if (_feedbackReport == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(height: 24),
            Text(
              'Analyzing your performance...',
              style: TextStyle(fontSize: 18, color: Color(0xFF64748B)),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildFeedbackHeader(),
          const SizedBox(height: 24),
          _buildOverallScore(),
          const SizedBox(height: 24),

          // ✅ NEW: Your Progress Section
          _buildYourProgress(),
          const SizedBox(height: 24),

          // ✅ ENHANCED: Performance Summary with Scoring Guide
          _buildPerformanceSummaryEnhanced(),
          const SizedBox(height: 24),

          // ✅ NEW: Strengths, Areas to Improve, Customer Impact
          _buildPerformanceBreakdown(),
          const SizedBox(height: 24),

          _buildDetailedCriteria(),
          const SizedBox(height: 24),
          _buildActionableRecommendations(),
          const SizedBox(height: 24),
          _buildTranscriptSection(),
          const SizedBox(height: 32),
          _buildFeedbackActions(),
        ],
      ),
    );
  }

  // ✅ NEW: Your Progress Section
  Widget _buildYourProgress() {
    final overallScore = _feedbackReport!['overallScore'] ?? 0;
    final callReadiness = _calculateCallReadiness(overallScore);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Call Career Readiness Progress Bar
          Row(
            children: [
              const Text(
                'Call Career Readiness',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const Spacer(),
              Text(
                '$callReadiness%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: callReadiness / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(callReadiness),
            ),
            minHeight: 8,
          ),
          const SizedBox(height: 16),

          // Progress Description
          Text(
            _getProgressDescription(callReadiness),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Skills Breakdown
          _buildSkillsBreakdown(),
        ],
      ),
    );
  }

  // ✅ FIXED: Skills breakdown with proper constraint handling
  Widget _buildSkillsBreakdown() {
    final criteria = _feedbackReport!['criteria'] as List<dynamic>? ?? [];

    if (criteria.isEmpty) {
      return const Text(
        'Skill breakdown will appear after completing the assessment.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue[600], size: 16),
            const SizedBox(width: 8),
            const Text(
              'Skills Overview',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...criteria.take(3).map((criterion) {
          final name = criterion['name'] as String? ?? 'Unknown';
          final score = criterion['score'] as int? ?? 0;
          final status = score >= 70
              ? 'Good'
              : score >= 50
              ? 'Developing'
              : 'Needs Work';
          final statusColor = score >= 70
              ? Colors.green
              : score >= 50
              ? Colors.orange
              : Colors.red;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // ✅ FIXED: Prevent text overflow
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$score%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor[700],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: TextStyle(fontSize: 12, color: statusColor[600]),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // ✅ ENHANCED: Performance Summary with Scoring Guide
  Widget _buildPerformanceSummaryEnhanced() {
    final summary = _feedbackReport!['summary'] ?? 'No summary available';
    final overallScore = _feedbackReport!['overallScore'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.summarize,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Performance Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),

          // ✅ NEW: Scoring Guide
          _buildScoringGuide(overallScore),
        ],
      ),
    );
  }

  Widget _buildScoringGuide(int overallScore) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scoring Guide:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 8),
          _buildScoreRange(
            '90-100%',
            'Excellent',
            '85-99%',
            'Good',
            overallScore,
          ),
          _buildScoreRange(
            '70-89%',
            'Good',
            '55-84%',
            'Developing',
            overallScore,
          ),
          _buildScoreRange(
            '50-69%',
            'Developing',
            '0-54%',
            'Needs Improvement',
            overallScore,
          ),
        ],
      ),
    );
  }

  // ✅ ALTERNATIVE: If you want to keep the horizontal layout, use this version instead
  Widget _buildPerformanceBreakdownHorizontal() {
    final criteria = _feedbackReport!['criteria'] as List<dynamic>? ?? [];
    final strengths = criteria
        .where((c) => (c['score'] as int? ?? 0) >= 75)
        .toList();
    final areasToImprove = criteria
        .where((c) => (c['score'] as int? ?? 0) < 75)
        .toList();
    final customerImpact =
        _feedbackReport!['customerImpact'] ??
        'The customer likely felt ${_calculateCustomerFeeling()} due to the agent\'s ${_calculateAgentPerformance()} and ${_calculateAssistanceLevel()}.';

    return SingleChildScrollView(
      // ✅ FIXED: Make it scrollable horizontally
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 280, // ✅ FIXED: Fixed width to prevent overflow
            child: _buildBreakdownCard(
              title: 'Strengths (${strengths.length})',
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF10B981),
              backgroundColor: const Color(0xFF10B981).withOpacity(0.05),
              borderColor: const Color(0xFF10B981).withOpacity(0.2),
              content: strengths.isEmpty
                  ? 'Complete more practice calls to identify your strengths.'
                  : strengths.map((s) => '• ${s['name']}').join('\n'),
            ),
          ),
          const SizedBox(width: 12),

          SizedBox(
            width: 280,
            child: _buildBreakdownCard(
              title: 'Areas to Improve',
              icon: Icons.trending_up,
              iconColor: const Color(0xFFF59E0B),
              backgroundColor: const Color(0xFFF59E0B).withOpacity(0.05),
              borderColor: const Color(0xFFF59E0B).withOpacity(0.2),
              content: areasToImprove.isEmpty
                  ? '• Continue practicing this skill area\n• Improve initial response to be more welcoming and helpful'
                  : areasToImprove
                        .map((a) => '• ${_getImprovementSuggestion(a['name'])}')
                        .join('\n'),
            ),
          ),
          const SizedBox(width: 12),

          SizedBox(
            width: 280,
            child: _buildBreakdownCard(
              title: 'Customer Impact',
              icon: Icons.sentiment_satisfied_alt,
              iconColor: const Color(0xFF8B5CF6),
              backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.05),
              borderColor: const Color(0xFF8B5CF6).withOpacity(0.2),
              content: customerImpact,
            ),
          ),
          const SizedBox(width: 20), // Extra padding at the end
        ],
      ),
    );
  }

  // ✅ FIXED: Better score range display to prevent overflow
  Widget _buildScoreRange(
    String range1,
    String label1,
    String range2,
    String label2,
    int userScore,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        // ✅ FIXED: Use Column instead of Row to prevent overflow
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$range1 $label1 • $range2 $label2',
            style: TextStyle(
              fontSize: 12,
              color:
                  (_isScoreInRange(range1, userScore) ||
                      _isScoreInRange(range2, userScore))
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF64748B),
              fontWeight:
                  (_isScoreInRange(range1, userScore) ||
                      _isScoreInRange(range2, userScore))
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Performance Breakdown with proper mobile layout
  Widget _buildPerformanceBreakdown() {
    final criteria = _feedbackReport!['criteria'] as List<dynamic>? ?? [];

    // Always show the cards even if criteria is empty, matching web version
    final strengths = criteria
        .where((c) => (c['score'] as int? ?? 0) >= 75)
        .toList();
    final areasToImprove = criteria
        .where((c) => (c['score'] as int? ?? 0) < 75)
        .toList();
    final customerImpact =
        _feedbackReport!['customerImpact'] ??
        'The customer likely felt ${_calculateCustomerFeeling()} due to the agent\'s ${_calculateAgentPerformance()} and ${_calculateAssistanceLevel()}.';

    return Column(
      children: [
        // ✅ FIXED: Use Column layout instead of Row to prevent overflow
        _buildBreakdownCard(
          title: 'Strengths (${strengths.length})',
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF10B981),
          backgroundColor: const Color(0xFF10B981).withOpacity(0.05),
          borderColor: const Color(0xFF10B981).withOpacity(0.2),
          content: strengths.isEmpty
              ? 'Complete more practice calls to identify your strengths.'
              : strengths.map((s) => '• ${s['name']}').join('\n'),
        ),
        const SizedBox(height: 16),

        _buildBreakdownCard(
          title: 'Areas to Improve',
          icon: Icons.trending_up,
          iconColor: const Color(0xFFF59E0B),
          backgroundColor: const Color(0xFFF59E0B).withOpacity(0.05),
          borderColor: const Color(0xFFF59E0B).withOpacity(0.2),
          content: areasToImprove.isEmpty
              ? '• Continue practicing this skill area\n• Improve initial response to be more welcoming and helpful\n• Enhance communication skills to provide clear and structured information'
              : areasToImprove
                    .map((a) => '• ${_getImprovementSuggestion(a['name'])}')
                    .join('\n'),
        ),
        const SizedBox(height: 16),

        _buildBreakdownCard(
          title: 'Customer Impact',
          icon: Icons.sentiment_satisfied_alt,
          iconColor: const Color(0xFF8B5CF6),
          backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.05),
          borderColor: const Color(0xFF8B5CF6).withOpacity(0.2),
          content: customerImpact,
        ),
      ],
    );
  }

  // ✅ ENHANCED: Better breakdown card that matches web version
  Widget _buildBreakdownCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required String content,
  }) {
    return Container(
      width: double.infinity, // ✅ FIXED: Full width to prevent overflow
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                // ✅ FIXED: Prevent text overflow
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              color: iconColor.withOpacity(0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Helper methods for the new features
  int _calculateCallReadiness(int overallScore) {
    // Base readiness on overall score but factor in attempt number
    final baseReadiness = overallScore;
    final experienceBonus = (_attemptNumber - 1) * 2; // 2% per attempt
    final readiness = (baseReadiness + experienceBonus).clamp(0, 100);
    return readiness;
  }

  Color _getProgressColor(int progress) {
    if (progress >= 80) return const Color(0xFF10B981); // Green
    if (progress >= 60) return const Color(0xFF3B82F6); // Blue
    if (progress >= 40) return const Color(0xFFF59E0B); // Orange
    return const Color(0xFFEF4444); // Red
  }

  String _getProgressDescription(int readiness) {
    if (readiness >= 85) {
      return 'Excellent! You\'re building your foundation skills. Keep practicing to become even more confident.';
    } else if (readiness >= 70) {
      return 'Good progress! You\'re developing solid call handling skills. Focus on areas needing improvement.';
    } else if (readiness >= 50) {
      return 'You\'re making progress! Continue practicing to strengthen your call handling abilities.';
    } else {
      return 'Keep practicing! Every attempt helps you improve your customer service skills.';
    }
  }

  bool _isScoreInRange(String range, int score) {
    if (range.contains('90-100%')) return score >= 90;
    if (range.contains('85-99%')) return score >= 85 && score <= 99;
    if (range.contains('70-89%')) return score >= 70 && score <= 89;
    if (range.contains('55-84%')) return score >= 55 && score <= 84;
    if (range.contains('50-69%')) return score >= 50 && score <= 69;
    if (range.contains('0-54%')) return score >= 0 && score <= 54;
    return false;
  }

  String _calculateCustomerFeeling() {
    final overallScore = _feedbackReport!['overallScore'] ?? 0;
    if (overallScore >= 80) return 'satisfied and well-helped';
    if (overallScore >= 60) return 'moderately satisfied';
    if (overallScore >= 40) return 'somewhat confused but willing to continue';
    return 'frustrated and confused';
  }

  String _calculateAgentPerformance() {
    final criteria = _feedbackReport!['criteria'] as List<dynamic>? ?? [];
    final avgCommunication =
        criteria
            .where(
              (c) =>
                  (c['name'] as String).toLowerCase().contains('communication'),
            )
            .fold(0, (sum, c) => sum + (c['score'] as int? ?? 0)) /
        criteria.length;

    if (avgCommunication >= 75) return 'clear communication skills';
    if (avgCommunication >= 50) return 'developing communication approach';
    return 'unclear communication methods';
  }

  String _calculateAssistanceLevel() {
    final criteria = _feedbackReport!['criteria'] as List<dynamic>? ?? [];
    final avgHelp =
        criteria
            .where(
              (c) =>
                  (c['name'] as String).toLowerCase().contains('solution') ||
                  (c['name'] as String).toLowerCase().contains('help'),
            )
            .fold(0, (sum, c) => sum + (c['score'] as int? ?? 0)) /
        criteria.length;

    if (avgHelp >= 75) return 'comprehensive assistance';
    if (avgHelp >= 50) return 'adequate support';
    return 'limited assistance';
  }

  // ✅ ENHANCED: Better improvement suggestions matching web content
  String _getImprovementSuggestion(String criterionName) {
    final name = criterionName.toLowerCase();
    if (name.contains('communication'))
      return 'Improve initial response to be more welcoming and helpful';
    if (name.contains('empathy'))
      return 'Enhance communication skills to provide clear and structured information';
    if (name.contains('solution') || name.contains('problem'))
      return 'Focus on providing more comprehensive solutions';
    if (name.contains('professional'))
      return 'Maintain professional tone throughout the conversation';
    if (name.contains('listening'))
      return 'Practice active listening techniques';
    if (name.contains('clarity'))
      return 'Speak more clearly and at appropriate pace';
    if (name.contains('follow')) return 'Better follow-up on customer concerns';
    return 'Continue practicing this skill area';
  }

  Widget _buildFeedbackHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Advanced Performance Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Comprehensive analysis for: "${_selectedScenario?['title'] ?? 'Unknown Scenario'}"',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _feedbackReport!['performanceLevel'] ?? 'Performance Level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // And in _buildOverallScore method:
  Widget _buildOverallScore() {
    // ✅ FIXED: Handle both int and double types
    final scoreValue = _feedbackReport!['overallScore'];
    final overallScore = scoreValue is int
        ? scoreValue
        : (scoreValue is double ? scoreValue.round() : 0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Overall Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: overallScore / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor(overallScore.toDouble()),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$overallScore%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(overallScore.toDouble()),
                        ),
                      ),
                      Text(
                        _getPerformanceLevel(overallScore),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getScoreColor(overallScore.toDouble()),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary() {
    final summary = _feedbackReport!['summary'] ?? 'No summary available';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.summarize,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Performance Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedCriteria() {
    final criteria = _feedbackReport!['criteria'] as List<dynamic>? ?? [];

    if (criteria.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Criteria',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...criteria.map((criterion) {
            final name = criterion['name'] as String? ?? 'Unknown';
            final score = criterion['score'] as int? ?? 0;
            final feedback =
                criterion['feedback'] as String? ?? 'No feedback available';
            final priority = criterion['priority'] as String? ?? 'Medium';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getScoreColor(score.toDouble()),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (priority != 'Medium')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priority == 'High'
                                ? Colors.red[100]
                                : Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            priority,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: priority == 'High'
                                  ? Colors.red[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        '$score%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score.toDouble()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor(score.toDouble()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feedback,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActionableRecommendations() {
    final recommendations =
        _feedbackReport!['actionableRecommendations'] as Map<String, dynamic>?;

    if (recommendations == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.rocket_launch,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Action Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (recommendations['immediate'] != null) ...[
            _buildRecommendationSection(
              '🎯 Practice Right Now',
              recommendations['immediate'] as List<dynamic>,
              Colors.red[50]!,
              Colors.red[700]!,
            ),
            const SizedBox(height: 12),
          ],

          if (recommendations['shortTerm'] != null) ...[
            _buildRecommendationSection(
              '📈 This Week',
              recommendations['shortTerm'] as List<dynamic>,
              Colors.orange[50]!,
              Colors.orange[700]!,
            ),
            const SizedBox(height: 12),
          ],

          if (recommendations['longTerm'] != null) ...[
            _buildRecommendationSection(
              '🎓 Long-term Goals',
              recommendations['longTerm'] as List<dynamic>,
              Colors.blue[50]!,
              Colors.blue[700]!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationSection(
    String title,
    List<dynamic> recommendations,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ...recommendations
              .map(
                (rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: textColor)),
                      Expanded(
                        child: Text(
                          rec.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection() {
    if (_transcript.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(
          child: Text(
            'No transcript available for this attempt',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conversation Transcript',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _transcript.length,
            itemBuilder: (context, index) {
              final entry = _transcript[index];
              final speaker = entry['speaker'] as String? ?? 'Unknown';
              final text = entry['text'] as String? ?? '';
              final isUser = speaker == 'User';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF3B82F6)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isUser ? Icons.person : Icons.support_agent,
                        size: 16,
                        color: isUser ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUser ? 'You' : 'Customer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUser
                                  ? const Color(0xFF3B82F6)
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _tryAgain,
            icon: const Icon(Icons.refresh, size: 24),
            label: const Text(
              'Try Again',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () {
              // ✅ OPTION 1: Direct navigation to courses (replace with your route)
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/courses', // Replace with your actual courses route name
                (route) => false, // Remove all previous routes
              );

              // ✅ OPTION 2: Or if you have a specific courses widget to navigate to:
              // Navigator.of(context).pushAndRemoveUntil(
              //   MaterialPageRoute(builder: (context) => YourCoursesPage()),
              //   (route) => false,
              // );
            },
            child: const Text(
              'Back to Courses',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods
  String _getPerformanceLevel(int score) {
    if (score >= 85) return 'Excellent Performance';
    if (score >= 70) return 'Good Performance';
    if (score >= 55) return 'Developing Performance';
    return 'Needs Improvement';
  }

  Color _getScoreColor(double score) {
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF3B82F6);
    if (score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  // Action methods
  void _selectScenario(Map<String, dynamic> scenario) {
    setState(() {
      _selectedScenario = scenario;
      _currentPhase = 'briefing';
    });
  }

  void _startCall() {
    setState(() {
      _currentPhase = 'live';
      _transcript = [
        {'speaker': 'AI', 'text': 'Hello? Can you help me?'},
      ];
    });
    _startTimer();

    // Play opening line with TTS
    _speakText('Hello? Can you help me?');
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timer--;
          if (_timer <= 0) {
            _endCall();
          }
        });
      }
    });
  }

  // UPDATED: Start recording with timer
  Future<void> _startRecording() async {
    if (_isAiSpeaking || _isProcessingAudio || _isRecording) return;

    try {
      // Check and request permission
      if (!(await _audioRecorder.hasPermission())) {
        _showPermissionDialog();
        return;
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _recordingDuration = 0;
      });

      // Start recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRecording) {
          setState(() {
            _recordingDuration = DateTime.now()
                .difference(_recordingStartTime!)
                .inSeconds;
          });

          // Auto-stop after 30 seconds
          if (_recordingDuration >= 30) {
            _stopRecording();
          }
        }
      });

      _logger.i('Started recording');
    } catch (e) {
      _logger.e('Error starting recording: $e');
      setState(() {
        _isRecording = false;
      });
      _showServerError();
    }
  }

  // UPDATED: Stop recording with better UX
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
        _isProcessingAudio = true;
        _recordingDuration = 0;
      });

      if (_currentRecordingPath != null &&
          File(_currentRecordingPath!).existsSync()) {
        await _processRecording();
      } else {
        throw Exception('Recording file not found');
      }
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _isProcessingAudio = false;
      });
      _showServerError();
    }
  }

  // UPDATED: Process recording with better error handling
  Future<void> _processRecording() async {
    if (_currentRecordingPath == null) return;

    try {
      // Upload audio for transcription
      final audioUrl = await _uploadAudioFile(_currentRecordingPath!);

      // Get transcription from Azure
      final transcriptionResponse = await http.post(
        Uri.parse('http://192.168.254.103:5000/transcribe-audio-azure'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'audioUrl': audioUrl}),
      );

      if (transcriptionResponse.statusCode == 200) {
        final transcriptionData = jsonDecode(transcriptionResponse.body);

        if (transcriptionData['success'] &&
            transcriptionData['transcript'] != null &&
            transcriptionData['transcript'].toString().trim().isNotEmpty) {
          final userText = transcriptionData['transcript'].toString().trim();

          // Add user message to transcript
          setState(() {
            _transcript.add({'speaker': 'User', 'text': userText});
          });

          // Get AI response
          await _getAiResponse();
        } else {
          _logger.w('No transcription received or empty transcript');
          _addErrorMessage(
            'Sorry, I didn\'t catch that. Could you please try again?',
          );
        }
      } else {
        _logger.e('Transcription failed: ${transcriptionResponse.statusCode}');
        throw Exception('Transcription service unavailable');
      }
    } catch (e) {
      _logger.e('Error processing recording: $e');
      _addErrorMessage(
        'Sorry, there was a technical issue. Please try speaking again.',
      );
      _showNetworkError();
    } finally {
      setState(() {
        _isProcessingAudio = false;
      });

      // Clean up recording file
      if (_currentRecordingPath != null &&
          File(_currentRecordingPath!).existsSync()) {
        try {
          File(_currentRecordingPath!).deleteSync();
        } catch (e) {
          _logger.w('Could not delete recording file: $e');
        }
      }
    }
  }

  // NEW: Format recording time nicely
  String _formatRecordingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<String> _uploadAudioFile(String filePath) async {
    final file = File(filePath);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.254.103:5000/upload-audio-temp'),
    );

    request.files.add(await http.MultipartFile.fromPath('audio', filePath));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return data['audioUrl'];
    } else {
      throw Exception('Failed to upload audio: $responseBody');
    }
  }

  Future<void> _getAiResponse() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.254.103:5000/ai-call-turn'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transcript': _transcript,
          'system_prompt': _selectedScenario!['system_prompt'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['ai_response'] as String;
        final emotion = data['emotion'] as String? ?? 'neutral';

        setState(() {
          _transcript.add({'speaker': 'AI', 'text': aiResponse});
        });

        // Speak the AI response
        await _speakText(aiResponse);
      } else {
        _logger.e('AI response failed: ${response.statusCode}');
        _addErrorMessage('Sorry, I need a moment to think. Please continue.');
      }
    } catch (e) {
      _logger.e('Error getting AI response: $e');
      _addErrorMessage(
        'I\'m having trouble responding right now. Please try again.',
      );
    }
  }

  Future<void> _speakText(String text) async {
    if (text.isEmpty || _isAiSpeaking) return;

    setState(() {
      _isAiSpeaking = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.254.103:5000/synthesize-speech'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'voice': _aiVoice}),
      );

      if (response.statusCode == 200) {
        // Save audio to temporary file
        final tempDir = await getTemporaryDirectory();
        final audioFile = File(
          '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await audioFile.writeAsBytes(response.bodyBytes);

        // Play audio
        await _audioPlayer.setFilePath(audioFile.path);
        await _audioPlayer.play();

        // Wait for playback to complete
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            setState(() {
              _isAiSpeaking = false;
            });
            // Clean up audio file
            if (audioFile.existsSync()) {
              audioFile.deleteSync();
            }
          }
        });
      }
    } catch (e) {
      _logger.e('Error with text-to-speech: $e');
      setState(() {
        _isAiSpeaking = false;
      });
    }
  }

  void _addErrorMessage(String message) {
    setState(() {
      _transcript.add({'speaker': 'AI', 'text': message});
    });
    _speakText(message);
  }

  void _showEndCallConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Call?'),
        content: const Text(
          'Are you sure you want to end the call? Your progress will be saved and analyzed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _endCall();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              'End Call',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Feedback?'),
        content: const Text(
          'Are you sure you want to leave? You can always view this feedback later in your activity log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _endCall() async {
    _callTimer?.cancel();
    setState(() {
      _currentPhase = 'feedback';
      _isLoading = true;
    });

    try {
      final callDuration = 180 - _timer;

      // ✅ FIX: Create a clean scenario object without IconData
      final cleanScenario = {
        'id': _selectedScenario!['id'],
        'title': _selectedScenario!['title'],
        'description': _selectedScenario!['description'],
        'briefing': _selectedScenario!['briefing'],
        'system_prompt': _selectedScenario!['system_prompt'],
        // ❌ DON'T include 'icon' or 'color' as they contain non-serializable objects
      };

      // Get enhanced feedback from server
      final response = await http.post(
        Uri.parse('http://192.168.254.103:5000/ai-call-feedback-enhanced'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transcript': _transcript,
          'scenario': cleanScenario, // ✅ Use the clean scenario object
          'callDuration': callDuration,
          'customerEmotion': 'auto-detected',
        }),
      );

      if (response.statusCode == 200) {
        final feedbackData = jsonDecode(response.body);
        setState(() {
          _feedbackReport = feedbackData;
        });

        // Save progress to Firebase
        await _saveAttemptToFirebase(feedbackData, callDuration);
      } else {
        _logger.e('Feedback request failed: ${response.statusCode}');
        throw Exception('Failed to get feedback from server');
      }
    } catch (error) {
      _logger.e('Error getting feedback: $error');
      setState(() {
        _feedbackReport = {
          'error': true,
          'overallScore': 0,
          'performanceLevel': 'Error',
          'summary':
              'Sorry, an error occurred while analyzing your performance. Please try again.',
          'criteria': [],
          'actionableRecommendations': null,
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAttemptToFirebase(
    Map<String, dynamic> feedbackData,
    int callDuration,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final detailedResponses = {
        'finalTranscript': _transcript,
        'feedbackReport': feedbackData,
        'scenarioTitle': _selectedScenario!['title'],
        'scenarioId': _selectedScenario!['id'],
        'callDuration': callDuration,
        'attemptTimestamp': DateTime.now().toIso8601String(),
        'aiVoice': _aiVoice,
      };

      await _progressService.saveLessonAttempt(
        lessonId: 'Lesson-6-1',
        score: feedbackData['overallScore'] ?? 0,
        maxScore: 100,
        timeSpent: callDuration,
        detailedResponses: detailedResponses,
      );

      // Update attempt number for next attempt
      setState(() {
        _attemptNumber++;
      });

      _logger.i('Successfully saved Module 6 attempt to Firebase');
    } catch (e) {
      _logger.e('Error saving attempt to Firebase: $e');
      // Don't throw error here, as we still want to show feedback even if saving fails
    }
  }

  void _tryAgain() {
    // Stop any ongoing audio
    _audioPlayer.stop();

    // Reset all state
    setState(() {
      _currentPhase = 'scenario_selection';
      _selectedScenario = null;
      _transcript.clear();
      _aiVoice = 'female';
      _isListening = false;
      _isAiSpeaking = false;
      _isLoadingAiResponse = false;
      _timer = 180;
      _feedbackReport = null;
      _isLoading = false;
      _selectedCriterion = null;
      _isTranscriptExpanded = false;
      _activeTab = 'overview';
    });

    // Cancel timer and clean up
    _callTimer?.cancel();

    // Clean up any recording file
    if (_currentRecordingPath != null &&
        File(_currentRecordingPath!).existsSync()) {
      try {
        File(_currentRecordingPath!).deleteSync();
      } catch (e) {
        _logger.w('Could not delete recording file: $e');
      }
    }
    _currentRecordingPath = null;

    _logger.i('Reset simulation for new attempt');
  }

  // UPDATED: Better permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mic, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('Microphone Access Required'),
          ],
        ),
        content: const Text(
          'To participate in this call simulation, we need access to your microphone to record your voice.\n\n'
          'Please grant microphone permission in your device settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // You could open app settings here if needed
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]),
            child: const Text(
              'Grant Permission',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Better error handling
  void _showNetworkError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Network error. Please check your connection and try again.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () {
            // You could add retry logic here
          },
        ),
      ),
    );
  }

  void _showServerError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Server error. Please try again in a moment.'),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void deactivate() {
    // Clean up when page is being disposed
    _audioPlayer.stop();
    _callTimer?.cancel();

    if (_currentRecordingPath != null &&
        File(_currentRecordingPath!).existsSync()) {
      try {
        File(_currentRecordingPath!).deleteSync();
      } catch (e) {
        _logger.w('Could not delete recording file on deactivate: $e');
      }
    }

    super.deactivate();
  }
}
