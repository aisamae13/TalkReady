import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class VocabularyFlashcardsPage extends StatefulWidget {
  const VocabularyFlashcardsPage({Key? key}) : super(key: key);

  @override
  State<VocabularyFlashcardsPage> createState() =>
      _VocabularyFlashcardsPageState();
}

class _VocabularyFlashcardsPageState extends State<VocabularyFlashcardsPage>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final _user = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  bool _isLoadingWords = false;
  List<Map<String, dynamic>> _words = [];
  int _currentCardIndex = 0;
  bool _showingDefinition = false;

  // Settings
  String _selectedDifficulty = 'beginner';
  String _selectedCategory = 'general';

  // Animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // Session tracking
  int _cardsViewed = 0;
  int _cardsMarkedKnown = 0;
  int _cardsMarkedUnknown = 0;
  DateTime? _sessionStartTime;

  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  // ✅ NEW CODE
  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _setupAnimation();

    // Show dialog after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSettingsDialog();
    });
  }

  void _setupAnimation() {
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎴 Flashcard Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty Level',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                DropdownMenuItem(
                  value: 'intermediate',
                  child: Text('Intermediate'),
                ),
                DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDifficulty = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(
                  value: 'customer_service',
                  child: Text('Customer Service'),
                ),
                DropdownMenuItem(
                  value: 'technical_terms',
                  child: Text('Technical Terms'),
                ),
                DropdownMenuItem(
                  value: 'business_vocabulary',
                  child: Text('Business Vocabulary'),
                ),
                DropdownMenuItem(
                  value: 'phone_etiquette',
                  child: Text('Phone Etiquette'),
                ),
                DropdownMenuItem(
                  value: 'problem_solving',
                  child: Text('Problem Solving'),
                ),
                DropdownMenuItem(
                  value: 'payment_and_billing',
                  child: Text('Payment & Billing'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _loadWords();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Learning'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadWords() async {
    if (!mounted) return; // ✅ Add this
    setState(() => _isLoadingWords = true);

    try {
      _logger.i('Loading flashcard vocabulary...');

      final response = await http
          .post(
            Uri.parse('$_backendUrl/generate-vocabulary-words'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'difficulty': _selectedDifficulty,
              'category': _selectedCategory,
              'count': 15,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return; // ✅ Add this

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['words'] != null) {
          if (!mounted) return; // ✅ Add this

          setState(() {
            _words = List<Map<String, dynamic>>.from(data['words']);
            _isLoadingWords = false;
            _isLoading = false;
            _currentCardIndex = 0;
            _showingDefinition = false;
          });
          _logger.i('Loaded ${_words.length} flashcards');
        }
      }
    } catch (e) {
      _logger.e('Error loading flashcards: $e');

      if (!mounted) return; // ✅ Add this

      setState(() {
        _isLoadingWords = false;
        _isLoading = false;
      });
      _showError('Failed to load flashcards: ${e.toString()}');
    }
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_showingDefinition) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }

    setState(() {
      _showingDefinition = !_showingDefinition;
    });

    if (!_showingDefinition) {
      _cardsViewed++;
    }
  }

  void _nextCard({required bool isKnown}) {
    if (_currentCardIndex < _words.length - 1) {
      if (isKnown) {
        _cardsMarkedKnown++;
        _saveWordProgress(_words[_currentCardIndex], true);
      } else {
        _cardsMarkedUnknown++;
        _saveWordProgress(_words[_currentCardIndex], false);
      }

      setState(() {
        _currentCardIndex++;
        _showingDefinition = false;
      });
      _flipController.reset();
    } else {
      _completeSession();
    }
  }

  Future<void> _saveWordProgress(
    Map<String, dynamic> word,
    bool isKnown,
  ) async {
    try {
      await http.post(
        Uri.parse('$_backendUrl/save-vocabulary-progress'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _user?.uid,
          'wordData': {
            'wordId': word['id'],
            'word': word['word'],
            'category': word['category'],
            'difficulty': word['difficulty'],
            'masteryLevel': isKnown ? 3 : 1,
            'timesReviewed': 1,
            'correctAttempts': isKnown ? 1 : 0,
            'totalAttempts': 1,
            'isLearned': isKnown,
          },
        }),
      );
      _logger.i('Saved flashcard progress for: ${word['word']}');
    } catch (e) {
      _logger.e('Error saving progress: $e');
    }
  }

  void _completeSession() {
    final duration = DateTime.now().difference(_sessionStartTime!);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great work, ${_user?.displayName?.split(' ')[0] ?? 'there'}!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildStatRow('Cards Studied', '$_cardsViewed'),
            _buildStatRow('Known', '$_cardsMarkedKnown', Colors.green),
            _buildStatRow('Need Review', '$_cardsMarkedUnknown', Colors.orange),
            _buildStatRow(
              'Session Time',
              '${duration.inMinutes}m ${duration.inSeconds % 60}s',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSession();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Study Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  void _resetSession() {
    setState(() {
      _currentCardIndex = 0;
      _showingDefinition = false;
      _cardsViewed = 0;
      _cardsMarkedKnown = 0;
      _cardsMarkedUnknown = 0;
      _sessionStartTime = DateTime.now();
    });
    _flipController.reset();
    _showSettingsDialog();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingWords) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('🎴 Flashcards'),
          backgroundColor: Colors.purple,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.purple),
              SizedBox(height: 16),
              Text('Loading flashcards...'),
            ],
          ),
        ),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('🎴 Flashcards'),
          backgroundColor: Colors.purple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No flashcards available'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showSettingsDialog,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final currentWord = _words[_currentCardIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎴 Flashcards'),
        backgroundColor: Colors.purple,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentCardIndex + 1}/${_words.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentCardIndex + 1) / _words.length,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            minHeight: 8,
          ),

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip('✓ Known', _cardsMarkedKnown, Colors.green),
                _buildStatChip('? Review', _cardsMarkedUnknown, Colors.orange),
                _buildStatChip('👁 Viewed', _cardsViewed, Colors.blue),
              ],
            ),
          ),

          // Flashcard
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * math.pi;
                      final transform = Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle);

                      return Transform(
                        transform: transform,
                        alignment: Alignment.center,
                        child: angle >= math.pi / 2
                            ? Transform(
                                transform: Matrix4.identity()..rotateY(math.pi),
                                alignment: Alignment.center,
                                child: _buildCardBack(currentWord),
                              )
                            : _buildCardFront(currentWord),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Action buttons
          if (_showingDefinition)
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _nextCard(isKnown: false),
                      icon: const Icon(Icons.close),
                      label: const Text('Need Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _nextCard(isKnown: true),
                      icon: const Icon(Icons.check),
                      label: const Text('I Know This'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.touch_app, color: Colors.grey, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Tap card to see definition',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCardFront(Map<String, dynamic> word) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        height: 400,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                word['partOfSpeech'] ?? 'word',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              word['word'],
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              word['pronunciation'] ?? '',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.flip_camera_android,
              color: Colors.white.withOpacity(0.5),
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(Map<String, dynamic> word) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        height: 400,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.purple, width: 3),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Definition',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                word['definition'] ?? '',
                style: const TextStyle(fontSize: 18, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Text(
                'Example',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  word['example'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
              if (word['synonyms'] != null &&
                  (word['synonyms'] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Synonyms',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (word['synonyms'] as List).map((syn) {
                    return Chip(
                      label: Text(syn),
                      backgroundColor: Colors.purple.shade100,
                      labelStyle: const TextStyle(fontSize: 13),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
