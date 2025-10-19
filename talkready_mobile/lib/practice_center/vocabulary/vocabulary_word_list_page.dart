import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VocabularyWordListPage extends StatefulWidget {
  final String initialCategory;

  const VocabularyWordListPage({Key? key, this.initialCategory = 'general'})
    : super(key: key);

  @override
  State<VocabularyWordListPage> createState() => _VocabularyWordListPageState();
}

class _VocabularyWordListPageState extends State<VocabularyWordListPage> {
  final Logger _logger = Logger();
  final _user = FirebaseAuth.instance.currentUser;

  bool _isLoading = false;
  List<Map<String, dynamic>> _words = [];
  String _selectedDifficulty = 'beginner';
  String _selectedCategory = 'general';
  final Map<String, bool> _isMarkedForReview = {};

  static const String _backendUrl = 'https://talkready-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadWords();
  }

  Future<void> _loadWords() async {
    // ✅ Check if widget is still mounted before setting state
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      _logger.i('Loading vocabulary words...');

      final response = await http
          .post(
            Uri.parse('$_backendUrl/generate-vocabulary-words'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'difficulty': _selectedDifficulty,
              'category': _selectedCategory,
              'count': 10,
            }),
          )
          .timeout(const Duration(seconds: 30));

      // ✅ Check mounted before processing response
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['words'] != null) {
          // ✅ Check mounted again before setState
          if (!mounted) return;

          setState(() {
            _words = List<Map<String, dynamic>>.from(data['words']);
            _isLoading = false;
            _isMarkedForReview.clear();
          });
          _logger.i('Loaded ${_words.length} words');
        }
      }
    } catch (e) {
      _logger.e('Error loading words: $e');

      // ✅ Check mounted before setState in error handler
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showError('Failed to load words: ${e.toString()}');
    }
  }

 Future<void> _saveWordProgress(
    Map<String, dynamic> word,
    bool isLearned,
  ) async {
    try { // <--- START of try block
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
            'masteryLevel': isLearned ? 3 : 1,
            'timesReviewed': 1,
            'correctAttempts': 1,
            'totalAttempts': 1,
            'isLearned': isLearned,
          },
        }),
      );

      // ✅ Check mounted before logging (optional, but safe)
      if (!mounted) return;

      _logger.i('Saved progress for: ${word['word']}');

      // ✅ Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLearned ? '✅ Marked as learned!' : '📌 Saved for review',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
     if (!isLearned && word['word'] != null && mounted) {
        setState(() {
          // Use the word string as the key to match the Map<String, bool> definition
          _isMarkedForReview[word['word'] as String] = true;
        });
      }
    } catch (e) { // <--- ADDED CATCH CLAUSE to fix both errors
      _logger.e('Error saving progress: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word List'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 16),
                  Text('Loading vocabulary...'),
                ],
              ),
            )
          : Column(
              children: [
                // Current filters
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.purple.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category: ${_formatCategory(_selectedCategory)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Level: ${_selectedDifficulty.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Word list
                Expanded(
                  child: _words.isEmpty
                      ? const Center(child: Text('No words loaded'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _words.length,
                          itemBuilder: (context, index) {
                            return _buildWordCard(_words[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildWordCard(Map<String, dynamic> word) {
    final wordString = word['word'] as String? ?? '';
    final isBookmarked = _isMarkedForReview[wordString] ?? false;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                word['partOfSpeech'] ?? 'word',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                 wordString,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            word['pronunciation'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 12),

                // Definition
                _buildSection(
                  icon: Icons.description,
                  title: 'Definition',
                  content: word['definition'] ?? '',
                ),
                const SizedBox(height: 16),

                // Example
                _buildSection(
                  icon: Icons.format_quote,
                  title: 'Example',
                  content: word['example'] ?? '',
                  isItalic: true,
                ),
                const SizedBox(height: 16),

                // Synonyms
                if (word['synonyms'] != null &&
                    (word['synonyms'] as List).isNotEmpty)
                  _buildSection(
                    icon: Icons.swap_horiz,
                    title: 'Synonyms',
                    content: (word['synonyms'] as List).join(', '),
                  ),
                const SizedBox(height: 16),

                // Filipino Tip
                if (word['filipinoTip'] != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filipino Tip',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                word['filipinoTip'],
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Action buttons
              Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _saveWordProgress(word, true),
                        icon: const Icon(Icons.check),
                        label: const Text('Mark as Learned'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // NEW: Dynamic Bookmark Icon
                  IconButton(
                onPressed: () => _saveWordProgress(word, false),
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                color: isBookmarked ? Colors.purple : Colors.grey,
                tooltip: 'Save for review',
              ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    bool isItalic = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.purple),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Words'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
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
              decoration: const InputDecoration(labelText: 'Category'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadWords();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  String _formatCategory(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
