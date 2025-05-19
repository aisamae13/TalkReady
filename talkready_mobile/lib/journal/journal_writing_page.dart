import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'journal_page.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF00568D);
  static const Color secondaryColor = Color(0xFF003F6A);
  static const Color accentColor = Colors.yellow;
  static const Color backgroundGradientStart = Color(0xFF00568D);
  static const Color backgroundGradientMid = Colors.white;
  static const Color backgroundGradientEnd = Color(0xFFE0FFD6);
  static const Color containerGradientStart = Color(0xFFDEE3FF);
  static const Color containerGradientEnd = Color(0xFFD8F6F7);
  static const TextStyle titleStyle = TextStyle(
    fontSize: 24,
    color: primaryColor,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle dateStyle = TextStyle(
    wordSpacing: 2,
    letterSpacing: 1,
    fontSize: 14,
    color: primaryColor,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle moodTagStyle = TextStyle(
    fontSize: 16,
    fontStyle: FontStyle.italic,
    color: primaryColor,
  );
}

class JournalWritingPage extends StatefulWidget {
  final String? mood;
  final String? tag;
  final List<JournalEntry> entries;
  final Function(JournalEntry) addEntry;
  final Function(int, JournalEntry) updateEntry;
  final Function(int) deleteEntry;
  final Function(int) toggleFavorite;
  final JournalEntry? initialEntry;

  const JournalWritingPage({
    Key? key,
    required this.mood,
    required this.tag,
    required this.entries,
    required this.addEntry,
    required this.updateEntry,
    required this.deleteEntry,
    required this.toggleFavorite,
    this.initialEntry,
  }) : super(key: key);

  @override
  State<JournalWritingPage> createState() => _JournalWritingPageState();
}

class _JournalWritingPageState extends State<JournalWritingPage> {
  final Logger logger = Logger();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? selectedPrompt;
  bool _isSaving = false;

  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _alignment = 'left';

  int _wordCount = 0;
  int _charCount = 0;

  final List<String> prompts = [
    "What's on my mind right now?",
    "What do I need to hear today?",
    "3 things I want to appreciate today",
    "A quote to live by?",
    "What can I improve today?",
    "Five things you would like to do more",
  ];

  final Map<String, String> promptResponses = {
    "What's on my mind right now?": "I’ve been thinking about my goals for the week...",
    "What do I need to hear today?": "You’re doing great—keep pushing forward!",
    "3 things I want to appreciate today": "1. A sunny morning\n2. My cozy coffee\n3. A good book",
    "A quote to live by?": "‘The only way to do great work is to love what you do.’ – Steve Jobs",
    "What can I improve today?": "I could focus more on time management...",
    "Five things you would like to do more": "1. Read\n2. Exercise\n3. Cook\n4. Travel\n5. Meditate",
  };

  @override
  void initState() {
    super.initState();
    logger.i('Received mood: ${widget.mood}, tag: ${widget.tag}');
    if (widget.initialEntry != null) {
      _titleController.text = widget.initialEntry!.title;
      try {
        final content = jsonDecode(widget.initialEntry!.content);
        _textController.text = content['text'] ?? '';
        _isBold = content['isBold'] ?? false;
        _isItalic = content['isItalic'] ?? false;
        _isUnderline = content['isUnderline'] ?? false;
        _alignment = content['alignment'] ?? 'left';
      } catch (e) {
        logger.e('Failed to load entry: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading entry')),
        );
      }
    }
    _updateCounts();
    _textController.addListener(_updateCounts);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        logger.i('TextField gained focus');
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateCounts() {
    final text = _textController.text;
    setState(() {
      _wordCount = RegExp(r'\S+').allMatches(text).length;
      _charCount = text.length;
    });
    logger.i('Word count: $_wordCount, Char count: $_charCount');
  }

  int _getWordCount() => _wordCount;
  int _getCharCount() => _charCount;

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }

  Future<bool> _confirmOverwrite() async {
    if (_textController.text.isEmpty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Overwrite Content?'),
            content: const Text('Selecting a new prompt will replace existing content. Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Overwrite'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _saveEntry() async {
    final contentText = _textController.text.trim();
    if (contentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content is required')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final mood = widget.mood ?? 'Unknown';
    final tag = widget.tag ?? 'Unknown';
    if (mood == 'Unknown' || tag == 'Unknown') {
      logger.w('Saving entry with missing mood or tag: mood=$mood, tag=$tag');
    }

    final newEntry = JournalEntry(
      mood: mood,
      tag: tag,
      title: _titleController.text.trim(),
      content: jsonEncode({
        'text': contentText,
        'isBold': _isBold,
        'isItalic': _isItalic,
        'isUnderline': _isUnderline,
        'alignment': _alignment,
      }),
      timestamp: DateTime.now(),
      isFavorite: widget.initialEntry?.isFavorite ?? false,
    );

    logger.i('Saving entry with mood: ${newEntry.mood}, tag: ${newEntry.tag}');

    try {
      if (widget.initialEntry != null) {
        final index = widget.entries.indexWhere((e) => e == widget.initialEntry);
        if (index != -1) {
          widget.updateEntry(index, newEntry);
          logger.i('Updated journal entry at index: $index');
        } else {
          widget.addEntry(newEntry);
          logger.i('Added new entry as initial entry not found');
        }
      } else {
        widget.addEntry(newEntry);
        logger.i('Added new journal entry');
      }
      setState(() {
        _titleController.clear();
        _textController.clear();
        _isBold = false;
        _isItalic = false;
        _isUnderline = false;
        _alignment = 'left';
        _isSaving = false;
      });
      Navigator.pushNamed(context, '/journal-entries');
    } catch (e) {
      logger.e('Error saving entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving entry')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _navigateToEntries() {
    logger.i('Navigating to JournalEntriesPage without saving');
    Navigator.pushNamed(context, '/journal-entries');
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? AppTheme.primaryColor : Colors.grey,
        size: 20,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _getWordCount();
    final charCount = _getCharCount();
    logger.i('Word count: $wordCount, Char count: $charCount');

    TextAlign textAlign;
    switch (_alignment) {
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
      default:
        textAlign = TextAlign.left;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        logger.i('System back button pressed on JournalWritingPage');
        if (_textController.text.isNotEmpty || _titleController.text.isNotEmpty) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (shouldDiscard != true) return;
        }
        if (widget.initialEntry != null) {
          Navigator.pushNamed(context, '/journal-entries');
        } else {
          Navigator.pushNamed(context, '/mood-selection');
        }
      },
      child: Scaffold(
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.containerGradientStart.withOpacity(0.5),
                        AppTheme.containerGradientEnd.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select your Prompts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: prompts.map((prompt) {
                            bool isSelected = selectedPrompt == prompt;
                            return ChoiceChip(
                              label: Text(prompt),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryColor.withOpacity(0.5),
                              backgroundColor: Colors.white.withOpacity(0.8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2)),
                              ),
                              elevation: 2,
                              onSelected: (selected) async {
                                if (selected) {
                                  if (!await _confirmOverwrite()) return;
                                  setState(() {
                                    selectedPrompt = prompt;
                                    final response = promptResponses[prompt] ?? 'Start writing...';
                                    _textController.text = '$prompt\n\n$response';
                                  });
                                } else {
                                  setState(() {
                                    selectedPrompt = null;
                                  });
                                }
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: const Icon(
              Icons.lightbulb_outline,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.backgroundGradientStart.withOpacity(0.1),
                AppTheme.backgroundGradientMid,
                AppTheme.backgroundGradientEnd.withOpacity(0.3),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                          onPressed: () {
                            logger.i('Back button pressed on JournalWritingPage');
                            Navigator.pop(context);
                          },
                        ),
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, snapshot) {
                            final now = DateTime.now();
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                '${now.day} ${_getMonthName(now.month)} ${now.year} | ${TimeOfDay.fromDateTime(now).format(context)}',
                                style: AppTheme.dateStyle,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.mood != null || widget.tag != null)
                      Text(
                        'Mood: ${widget.mood ?? "Unknown"} | Tag: ${widget.tag ?? "Unknown"}',
                        style: AppTheme.moodTagStyle,
                      ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.containerGradientStart.withOpacity(0.5),
                            AppTheme.containerGradientEnd.withOpacity(0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Reflection',
                            style: AppTheme.titleStyle,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: 'TITLE...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.primaryColor),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _buildToolbarButton(
                                  icon: Icons.format_bold,
                                  isActive: _isBold,
                                  onPressed: () {
                                    setState(() {
                                      _isBold = !_isBold;
                                    });
                                  },
                                  tooltip: 'Bold',
                                ),
                                _buildToolbarButton(
                                  icon: Icons.format_italic,
                                  isActive: _isItalic,
                                  onPressed: () {
                                    setState(() {
                                      _isItalic = !_isItalic;
                                    });
                                  },
                                  tooltip: 'Italic',
                                ),
                                _buildToolbarButton(
                                  icon: Icons.format_underline,
                                  isActive: _isUnderline,
                                  onPressed: () {
                                    setState(() {
                                      _isUnderline = !_isUnderline;
                                    });
                                  },
                                  tooltip: 'Underline',
                                ),
                                _buildToolbarButton(
                                  icon: Icons.format_align_left,
                                  isActive: _alignment == 'left',
                                  onPressed: () {
                                    setState(() {
                                      _alignment = 'left';
                                    });
                                  },
                                  tooltip: 'Align Left',
                                ),
                                _buildToolbarButton(
                                  icon: Icons.format_align_center,
                                  isActive: _alignment == 'center',
                                  onPressed: () {
                                    setState(() {
                                      _alignment = 'center';
                                    });
                                  },
                                  tooltip: 'Align Center',
                                ),
                                _buildToolbarButton(
                                  icon: Icons.format_align_right,
                                  isActive: _alignment == 'right',
                                  onPressed: () {
                                    setState(() {
                                      _alignment = 'right';
                                    });
                                  },
                                  tooltip: 'Align Right',
                                ),
                                _buildToolbarButton(
                                  icon: Icons.format_align_justify,
                                  isActive: _alignment == 'justify',
                                  onPressed: () {
                                    setState(() {
                                      _alignment = 'justify';
                                    });
                                  },
                                  tooltip: 'Justify',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            constraints: BoxConstraints(
                              minHeight: 200,
                              maxHeight: MediaQuery.of(context).size.height * 0.4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                            ),
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              maxLines: null,
                              textAlign: textAlign,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                                fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                                fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                                decoration: _isUnderline ? TextDecoration.underline : TextDecoration.none,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Start typing...',
                                hintStyle: TextStyle(color: Colors.grey.shade600),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Words: $wordCount',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              Text(
                                'Chars: $charCount',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _saveEntry,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : Text(
                                            widget.initialEntry != null ? 'Update Entry' : 'Save Entry',
                                            style: const TextStyle(fontSize: 18, color: Colors.white),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _navigateToEntries,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 24,
                                    ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}