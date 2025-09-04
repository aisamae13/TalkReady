import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Local imports - adjust if your file locations differ
import 'DetailedFeedback.dart';
import 'UnscriptedFeedback.dart';

class AgentPrompt {
  final String? referenceText;
  final String? modelAnswerText;
  final String? instruction;
  final Map<String, dynamic>? scoringCriteria;

  AgentPrompt({
    this.referenceText,
    this.modelAnswerText,
    this.instruction,
    this.scoringCriteria,
  });

  factory AgentPrompt.fromMap(Map m) => AgentPrompt(
        referenceText: m['referenceText'] as String?,
        modelAnswerText: m['modelAnswerText'] as String?,
        instruction: m['instruction'] as String?,
        scoringCriteria: m['scoringCriteria'] as Map<String, dynamic>?,
      );
}

class Scenario {
  final String id;
  final AgentPrompt agentPrompt;
  final int maxScore;
  final Map<String, dynamic>? customerLine;

  Scenario({
    required this.id,
    required this.agentPrompt,
    this.maxScore = 1,
    this.customerLine,
  });

  factory Scenario.fromMap(Map m) => Scenario(
        id: m['id'].toString(),
        agentPrompt: AgentPrompt.fromMap(m['agentPrompt'] ?? {}),
        maxScore: m['maxScore'] ?? 1,
        customerLine: m['customerLine'] as Map<String, dynamic>?,
      );
}

class RolePlayQuestion {
  final String id;
  final int points;
  final List<Scenario> scenarios;

  RolePlayQuestion({
    required this.id,
    required this.points,
    required this.scenarios,
  });
}

class ScenarioResult {
  final double score;
  final String? audioUrl;
  final Map<String, dynamic>? feedback;
  final Map<String, dynamic>? detailedExplanation;
  final String? error;

  ScenarioResult({
    required this.score,
    this.audioUrl,
    this.feedback,
    this.detailedExplanation,
    this.error,
  });
}

class RolePlayScenarioQuestion extends StatefulWidget {
  final RolePlayQuestion question;
  final ValueChanged<Map<String, dynamic>> onChange;
  final bool showResults;
  final String? assessmentId;

  const RolePlayScenarioQuestion({
    Key? key,
    required this.question,
    required this.onChange,
    required this.showResults,
    this.assessmentId,
  }) : super(key: key);

  @override
  _RolePlayScenarioQuestionState createState() => _RolePlayScenarioQuestionState();
}

class _RolePlayScenarioQuestionState extends State<RolePlayScenarioQuestion> {
  int currentScenarioIndex = 0;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isRecording = false;
  bool isLoadingAudio = false;
  bool isProcessing = false;
  bool isSaving = false;
  bool isLoadingModelAudio = false;

  // Environment variables
  String get cloudinaryCloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'CLOUDINARY_CLOUD_NAME';
  String get cloudinaryUploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'CLOUDINARY_UPLOAD_PRESET';
  String get serverUrl => dotenv.env['SERVER_URL'] ?? 'http://localhost:5000';

  // Stored paths & cloud URLs
  final Map<String, String?> recordedPaths = {};
  final Map<String, String?> uploadedAudioUrls = {};
  final Map<String, ScenarioResult> scenarioResults = {};

  List<Scenario> get scenarios => widget.question.scenarios;
  Scenario get currentScenario => scenarios[currentScenarioIndex];
  bool get isLastScenario => currentScenarioIndex == scenarios.length - 1;

  // --- Recording helpers ---
  Future<void> handleStartRecording() async {
    final scenarioId = currentScenario.id;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required.')));
      return;
    }

    final dir = Directory.systemTemp;
    final filePath = '${dir.path}/assessment_${scenarioId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
      setState(() {
        isRecording = true;
        recordedPaths[scenarioId] = null;
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to start recording.')));
    }
  }

  Future<void> handleStopRecording() async {
    final scenarioId = currentScenario.id;
    try {
      final path = await _recorder.stop();
      setState(() {
        isRecording = false;
        recordedPaths[scenarioId] = path;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() => isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to stop recording.')));
    }
  }

  Future<void> handlePlayLocalRecording() async {
    final scenarioId = currentScenario.id;
    final path = recordedPaths[scenarioId] ?? uploadedAudioUrls[scenarioId];
    if (path == null) return;
    await _audioPlayer.play(DeviceFileSource(path));
  }

  // play given text by calling backend synth endpoint (returns audio blob)
  Future<void> handlePlayCustomerLine(String text) async {
    if (isLoadingAudio || text.isEmpty) return;
    setState(() => isLoadingAudio = true);
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/synthesize-speech'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');
      // save blob to temp file and play
      final bytes = res.bodyBytes;
      final file = File('${Directory.systemTemp.path}/customer_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Error playing customer line: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not play customer audio.')));
    } finally {
      setState(() => isLoadingAudio = false);
    }
  }

  Future<String> uploadToCloudinary(File file) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/video/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = cloudinaryUploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      debugPrint('Cloudinary error: ${resp.body}');
      throw Exception('Cloudinary upload failed');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  Future<void> handleFinalSubmit() async {
    setState(() => isProcessing = true);
    final Map<String, ScenarioResult> allFeedback = {};

    await Future.wait(scenarios.map((scenario) async {
      final path = recordedPaths[scenario.id];
      if (path == null) {
        allFeedback[scenario.id] = ScenarioResult(score: 0, error: 'No recording submitted.');
        return;
      }
      try {
        final file = File(path);
        final cloudUrl = await uploadToCloudinary(file);

        Map<String, dynamic>? feedbackResult;
        Map<String, dynamic>? detailedExplanation;
        double scoreValue = 0;

        // Scripted path: agentPrompt.referenceText present
        if (scenario.agentPrompt.referenceText != null && scenario.agentPrompt.referenceText!.isNotEmpty) {
          final azRes = await http.post(
            Uri.parse('$serverUrl/chatbot-evaluate-speech'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'audioUrl': cloudUrl, 'originalText': scenario.agentPrompt.referenceText}),
          );
          if (azRes.statusCode != 200) throw Exception('Azure evaluation failed');
          feedbackResult = jsonDecode(azRes.body) as Map<String, dynamic>;

          if (feedbackResult['success'] == true) {
            final expRes = await http.post(
              Uri.parse('$serverUrl/explain-azure-feedback-with-openai'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'azureFeedback': feedbackResult, 'originalText': scenario.agentPrompt.referenceText}),
            );
            if (expRes.statusCode == 200) {
              final expData = jsonDecode(expRes.body) as Map<String, dynamic>;
              detailedExplanation = expData['detailedFeedback'] as Map<String, dynamic>?;
            }
          }
          // assume feedbackResult contains accuracyScore out of 100
          scoreValue = (feedbackResult?['accuracyScore'] as num?)?.toDouble() ?? 0;
        } else if (scenario.agentPrompt.scoringCriteria != null) {
          // Unscripted path
          final unsRes = await http.post(
            Uri.parse('$serverUrl/evaluate-unscripted-simulation'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'audioUrl': cloudUrl, 'scoringCriteria': scenario.agentPrompt.scoringCriteria}),
          );
          if (unsRes.statusCode != 200) throw Exception('Unscripted evaluation failed');
          final unsJson = jsonDecode(unsRes.body) as Map<String, dynamic>;

          final openAiEvaluation = unsJson['openAiEvaluation'] as Map<String, dynamic>? ?? {};
          final openAiScore = (openAiEvaluation['score'] as num?)?.toDouble() ?? 0.0;
          // scale 1-10 to 10-100
          scoreValue = openAiScore * 10;
          feedbackResult = {'success': true, 'accuracyScore': scoreValue};
          detailedExplanation = openAiEvaluation['feedback'] as Map<String, dynamic>?;
        }

        allFeedback[scenario.id] = ScenarioResult(
          score: scoreValue,
          audioUrl: cloudUrl,
          feedback: feedbackResult,
          detailedExplanation: detailedExplanation,
        );

        // store uploaded url locally for playback in results
        uploadedAudioUrls[scenario.id] = cloudUrl;
      } catch (error) {
        debugPrint('Error processing ${scenario.id}: $error');
        final errString = error.toString();
        if (errString.contains('LANGUAGE_NOT_ENGLISH')) {
          // mirror React behavior: alert the user about language error
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evaluation Failed: Please speak in English only.')));
        }
        allFeedback[scenario.id] = ScenarioResult(score: 0, error: errString);
      }
    }));

    setState(() {
      scenarioResults.clear();
      scenarioResults.addAll(allFeedback);
      isProcessing = false;
    });

    // Inform parent about completion & computed scaled score
    final totalScore = scenarioResults.values.fold<double>(0.0, (s, r) => s + (r.score));
    final maxPossibleRawScore = scenarios.length * 100.0;
    final finalScaledScore = (totalScore / maxPossibleRawScore) * widget.question.points;
    widget.onChange({'target': {'name': widget.question.id, 'value': {'score': finalScaledScore, 'isComplete': true}}});
  }

  Future<void> handlePlayModelAnswer(String? text) async {
    if (isLoadingModelAudio || text == null || text.isEmpty) return;
    setState(() => isLoadingModelAudio = true);
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/synthesize-speech'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');
      final bytes = res.bodyBytes;
      final file = File('${Directory.systemTemp.path}/model_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Error playing model answer: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not play model answer.')));
    } finally {
      setState(() => isLoadingModelAudio = false);
    }
  }

  // Helper method to create UnscriptedFeedbackCard from feedbackData
  Widget _buildUnscriptedFeedback(Map<String, dynamic>? feedbackData) {
    if (feedbackData == null) {
      return const UnscriptedFeedbackCard(feedback: null);
    }

    try {
      final feedback = UnscriptedFeedback.fromMap(feedbackData);
      return UnscriptedFeedbackCard(feedback: feedback);
    } catch (e) {
      debugPrint('Error parsing unscripted feedback: $e');
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Error displaying feedback: ${e.toString()}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
  }

  // next / prev navigation
  void handleNextScenario() {
    if (!isLastScenario) setState(() => currentScenarioIndex += 1);
  }

  void handlePrevScenario() {
    if (currentScenarioIndex > 0) setState(() => currentScenarioIndex -= 1);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = scenarioResults.isNotEmpty;
    if (isCompleted && !widget.showResults) {
      // compute scaled score
      final totalScore = scenarioResults.values.fold<double>(0.0, (s, r) => s + r.score);
      final maxPossibleRawScore = scenarios.length * 100.0;
      final finalScaledScore = (totalScore / maxPossibleRawScore) * widget.question.points;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(FontAwesomeIcons.circleCheck, size: 72, color: Colors.green),
            const SizedBox(height: 12),
            const Text('Role-Play Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Your responses have been evaluated.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                const Text('Your Score for this Section', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('${finalScaledScore.toStringAsFixed(0)} / ${widget.question.points}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 18),
            // detailed feedback list
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: scenarios.asMap().entries.map((entry) {
                final idx = entry.key;
                final scenario = entry.value;
                final result = scenarioResults[scenario.id];
                final feedbackData = result?.detailedExplanation;
                final isUnscripted = feedbackData != null && feedbackData.containsKey('criteriaBreakdown');

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Scenario ${idx + 1} Review', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // audio player buttons
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: result?.audioUrl != null ? () => _audioPlayer.play(UrlSource(result!.audioUrl!)) : null,
                          icon: const Icon(FontAwesomeIcons.play),
                          label: const Text('Play Your Recording'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => handlePlayModelAnswer(scenario.agentPrompt.referenceText ?? scenario.agentPrompt.modelAnswerText),
                          icon: isLoadingModelAudio ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(FontAwesomeIcons.play),
                          label: const Text('Listen to Model Answer'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (isUnscripted)
                      _buildUnscriptedFeedback(feedbackData)
                    else if (feedbackData != null && feedbackData['feedback'] != null)
                      Column(
                        children: (feedbackData['feedback'] as List).map<Widget>((metricData) {
                          if (metricData == null) return const SizedBox.shrink();
                          return DetailedFeedback(
                            metric: metricData['metric'] ?? '',
                            score: (metricData['score'] as num?)?.toDouble() ?? 0,
                            whatItMeasures: metricData['whatItMeasures'],
                            whyThisScore: metricData['whyThisScore'],
                            tip: metricData['tip'],
                          );
                        }).toList(),
                      )
                    else if (result?.error != null)
                      Text(result!.error!, style: const TextStyle(color: Colors.red)),
                  ]),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isSaving ? null : () {
                // Hook: call your firebase save function here if you have one.
                // Example placeholder:
                // await saveModuleAssessmentAttempt(currentUser.uid, widget.assessmentId, finalScaledScore, widget.question.points);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Finish & Save pressed (implement save).')));
              },
              icon: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FontAwesomeIcons.arrowRight),
              label: Text(isSaving ? 'Saving...' : 'Finish & Save Attempt'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18)),
            ),
          ]),
        ),
      );
    }

    // Main interactive UI
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Scenario steps row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: scenarios.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final recorded = recordedPaths[s.id] != null;
              final selected = idx == currentScenarioIndex;
              return Row(children: [
                GestureDetector(
                  onTap: widget.showResults ? () => setState(() => currentScenarioIndex = idx) : null,
                  child: Column(children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected ? Colors.blue : Colors.grey[200],
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: selected ? Colors.blue : Colors.grey.shade400, width: 2),
                      ),
                      child: Center(child: recorded && !selected && !widget.showResults ? const Icon(FontAwesomeIcons.circleCheck, color: Colors.green) : Text('${idx + 1}', style: TextStyle(color: selected ? Colors.white : Colors.black))),
                    ),
                    const SizedBox(height: 6),
                    Text('Scenario ${idx + 1}', style: TextStyle(fontSize: 12, color: selected ? Colors.blue : Colors.grey[600])),
                  ]),
                ),
                if (idx < scenarios.length - 1)
                  Container(width: 40, height: 4, color: Colors.grey[200]),
              ]);
            }).toList()),
          ),
          const SizedBox(height: 14),

          // Instruction card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: Colors.blue.shade400, width: 4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your Task (Scenario ${currentScenarioIndex + 1}):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
              const SizedBox(height: 6),
              Text(currentScenario.agentPrompt.instruction ?? '', style: TextStyle(color: Colors.blue.shade700)),
            ]),
          ),
          const SizedBox(height: 12),

          // Prompt card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: Colors.indigo.shade500, width: 4))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(FontAwesomeIcons.microphone, size: 28, color: Colors.indigo),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Your Turn to Speak!', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Remember to speak your response clearly in English to receive an accurate evaluation from the AI coach.'),
              ])),
            ]),
          ),
          const SizedBox(height: 14),

          // Controls row
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            ElevatedButton.icon(
              onPressed: isLoadingAudio || isRecording || isProcessing
                  ? null
                  : () {
                      final text = currentScenario.customerLine?['text'] as String? ?? '';
                      handlePlayCustomerLine(text);
                    },
              icon: isLoadingAudio ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FontAwesomeIcons.volumeHigh),
              label: const Text('Listen to Customer'),
            ),

            if (!widget.showResults)
              isRecording
                  ? ElevatedButton.icon(
                      onPressed: handleStopRecording,
                      icon: const Icon(FontAwesomeIcons.stop),
                      label: const Text('Stop Recording'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    )
                  : ElevatedButton.icon(
                      onPressed: isProcessing ? null : handleStartRecording,
                      icon: const Icon(FontAwesomeIcons.microphone),
                      label: Text(recordedPaths[currentScenario.id] != null ? 'Re-record' : 'Record Response'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),

            if ((recordedPaths[currentScenario.id] != null || uploadedAudioUrls[currentScenario.id] != null) && !isRecording)
              ElevatedButton.icon(
                onPressed: handlePlayLocalRecording,
                icon: const Icon(FontAwesomeIcons.play),
                label: const Text('Play My Recording'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black),
              ),
          ]),
          const SizedBox(height: 12),

          if (isProcessing)
            Container(padding: const EdgeInsets.all(12), color: Colors.indigo[50], child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Analyzing all responses... Please wait.', style: TextStyle(fontWeight: FontWeight.w600))
            ])),

          if (widget.showResults && scenarioResults[currentScenario.id] != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Feedback for this Scenario', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                scenarioResults[currentScenario.id]!.error != null
                    ? const Text('Could not get feedback for this scenario.', style: TextStyle(color: Colors.red))
                    : Text('Score: ${scenarioResults[currentScenario.id]!.score.toStringAsFixed(0)} / ${currentScenario.maxScore * 10}', style: const TextStyle(fontSize: 20, color: Colors.green)),
              ]),
            ),

          const SizedBox(height: 18),

          // Navigation buttons
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            OutlinedButton.icon(
              onPressed: currentScenarioIndex == 0 ? null : handlePrevScenario,
              icon: const Icon(FontAwesomeIcons.arrowLeft),
              label: const Text('Previous'),
            ),
            if (!widget.showResults)
              isLastScenario
                  ? ElevatedButton.icon(
                      onPressed: (recordedPaths[currentScenario.id] == null || isProcessing) ? null : handleFinalSubmit,
                      icon: const Icon(FontAwesomeIcons.upload),
                      label: const Text('Submit All for Feedback'),
                    )
                  : ElevatedButton.icon(
                      onPressed: recordedPaths[currentScenario.id] == null ? null : handleNextScenario,
                      icon: const Icon(FontAwesomeIcons.arrowRight),
                      label: const Text('Next Scenario'),
                    )
            else
              ElevatedButton.icon(
                onPressed: currentScenarioIndex == scenarios.length - 1 ? null : () => setState(() => currentScenarioIndex += 1),
                icon: const Icon(FontAwesomeIcons.arrowRight),
                label: const Text('Next'),
              )
          ]),
        ]),
      ),
    );
  }
}