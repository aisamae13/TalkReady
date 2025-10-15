// enhanced_journal_writing_page.dart
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'journal_models.dart';

class JournalWritingPage extends StatefulWidget {
  final String? mood;
  final String? tagId;
  final String? tagName;
  final List<JournalEntry> entries;
  final Function(JournalEntry) addEntry;
  final Function(int, JournalEntry) updateEntry;
  final Function(int) deleteEntry;
  final Function(int) toggleFavorite;
  final JournalEntry? initialEntry;

  const JournalWritingPage({
    super.key,
    required this.mood,
    required this.tagId,
    required this.tagName,
    required this.entries,
    required this.addEntry,
    required this.updateEntry,
    required this.deleteEntry,
    required this.toggleFavorite,
    this.initialEntry,
  });

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
  Timer? _autoSaveTimer;
  Timer? _debounceTimer;
  DateTime? _lastAutoSave;
  bool _hasUnsavedChanges = false;
  bool _isAutoSaving = false;
  String? _currentDraftId;

  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _alignment = 'left';

  int _wordCount = 0;
  int _charCount = 0;

  JournalTemplate? _selectedTemplate;
  Map<String, String> _templateResponses = {};

  final List<String> prompts = [
    "What's on my mind right now?",
    "What do I need to hear today?",
    "3 things I want to appreciate today",
    "A quote to live by?",
    "What can I improve today?",
    "Five things you would like to do more",
  ];

 @override
  void initState() {
    super.initState();
    logger.i('Received mood: ${widget.mood}, tagId: ${widget.tagId}, tagName: ${widget.tagName}');

    if (widget.initialEntry != null) {
      _loadEntry(widget.initialEntry!);
      _currentDraftId = widget.initialEntry!.id;
    }

    _updateCounts();
    _textController.addListener(_onContentChanged);
    _titleController.addListener(_onContentChanged);

    _startAutoSave();
  }

  void _loadEntry(JournalEntry entry) {
    _titleController.text = entry.title;
    try {
      final content = jsonDecode(entry.content);
      _textController.text = content['text'] ?? '';
      _isBold = content['isBold'] ?? false;
      _isItalic = content['isItalic'] ?? false;
      _isUnderline = content['isUnderline'] ?? false;
      _alignment = content['alignment'] ?? 'left';

      // Load template if exists
      if (entry.templateId != null) {
        _selectedTemplate = JournalTemplates.getTemplateById(entry.templateId!);
        if (_selectedTemplate != null && content['templateResponses'] != null) {
          _templateResponses = Map<String, String>.from(content['templateResponses']);
        }
      }
    } catch (e) {
      logger.e('Failed to load entry: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading entry');
      }
    }
  }

void _onContentChanged() {
    setState(() {
      _hasUnsavedChanges = true;
      _updateCounts();
    });

    // Debounce auto-save: Only save after user stops typing for 3 seconds
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      if (_hasUnsavedChanges && !_isSaving && !_isAutoSaving) {
        _performAutoSave();
      }
    });
  }

void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges &&
          !_isSaving &&
          !_isAutoSaving &&
          (_textController.text.isNotEmpty || _titleController.text.isNotEmpty)) {
        _performAutoSave();
      }
    });
  }
@override
  void dispose() {
    _autoSaveTimer?.cancel();
    _debounceTimer?.cancel();
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
  }


  Future<bool> _confirmOverwrite() async {
    if (_textController.text.isEmpty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: const Text(
              'Overwrite Content?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: const Text('This will replace your current content. Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF605E5C))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Overwrite', style: TextStyle(color: Color(0xFF0078D4))),
              ),
            ],
          ),
        ) ??
        false;
  }

void _showErrorSnackBar(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFE74856),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10893E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

 Future<void> _performAutoSave() async {
    if (_isAutoSaving || _isSaving) return;

    final contentText = _textController.text.trim();
    final titleText = _titleController.text.trim();

    if (contentText.isEmpty && titleText.isEmpty) return;

    setState(() => _isAutoSaving = true);

    try {
      final draftEntry = _createDraftEntry(isDraft: true);

      if (_currentDraftId != null) {
        await _updateFirestoreDraft(_currentDraftId!, draftEntry);

        final index = widget.entries.indexWhere((e) => e.id == _currentDraftId);
        if (index != -1) {
          widget.updateEntry(index, draftEntry.copyWith(id: _currentDraftId));
        }
      } else {
        final docRef = await _createFirestoreDraft(draftEntry);
        _currentDraftId = docRef.id;
        widget.addEntry(draftEntry.copyWith(id: docRef.id));
      }

      setState(() {
        _hasUnsavedChanges = false;
        _lastAutoSave = DateTime.now();
      });

      logger.i('Auto-save successful at ${_lastAutoSave}');
    } catch (e) {
      logger.e('Auto-save failed: $e');
    } finally {
      setState(() => _isAutoSaving = false);
    }
  }

  JournalEntry _createDraftEntry({required bool isDraft}) {
    return JournalEntry(
      mood: widget.mood ?? 'Not specified',
      tagId: widget.tagId,
      tagName: widget.tagName ?? 'Not specified',
      title: _titleController.text.trim(),
      content: jsonEncode({
        'text': _textController.text.trim(),
        'isBold': _isBold,
        'isItalic': _isItalic,
        'isUnderline': _isUnderline,
        'alignment': _alignment,
        'templateResponses': _templateResponses,
      }),
      timestamp: widget.initialEntry?.timestamp ?? DateTime.now(),
      isFavorite: widget.initialEntry?.isFavorite ?? false,
      isDraft: isDraft,
      lastModified: DateTime.now(),
      templateId: _selectedTemplate?.id,
    );
  }

  Future<DocumentReference> _createFirestoreDraft(JournalEntry entry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return await FirebaseFirestore.instance.collection('journals').add({
      'userId': user.uid,
      ...entry.toMap(),
    });
  }

  Future<void> _updateFirestoreDraft(String draftId, JournalEntry entry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await FirebaseFirestore.instance.collection('journals').doc(draftId).update({
      'userId': user.uid,
      ...entry.toMap(),
    });
  }

 Future<void> _saveEntry({bool isDraft = false}) async {
  final contentText = _textController.text.trim();

  if (contentText.isEmpty) {
    _showErrorSnackBar('Content is required');
    return;
  }

  setState(() => _isSaving = true);

  try {
    final newEntry = _createDraftEntry(isDraft: isDraft);

    if (_currentDraftId != null) {
      await _updateFirestoreDraft(_currentDraftId!, newEntry);

      final index = widget.entries.indexWhere((e) => e.id == _currentDraftId);
      if (index != -1) {
        widget.updateEntry(index, newEntry.copyWith(id: _currentDraftId));
      }
    } else {
      final docRef = await _createFirestoreDraft(newEntry);
      widget.addEntry(newEntry.copyWith(id: docRef.id));
    }

    setState(() {
      _hasUnsavedChanges = false;
      _lastAutoSave = DateTime.now();
    });

    _showSuccessSnackBar(
      isDraft ? 'Draft saved successfully' : 'Entry saved successfully'
    );

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted && !isDraft) {
      Navigator.pushNamed(context, '/journal-entries');
    }
  } catch (e) {
    logger.e('Error saving entry: $e');
    _showErrorSnackBar('Failed to save: ${e.toString()}');
  } finally {
    setState(() => _isSaving = false);
  }
}

String _getAutoSaveStatus() {
    if (_isAutoSaving) {
      return 'Saving...';
    } else if (_lastAutoSave != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastAutoSave!);

      if (diff.inSeconds < 60) {
        return 'Saved just now';
      } else if (diff.inMinutes < 60) {
        return 'Saved ${diff.inMinutes}m ago';
      } else {
        return 'Saved ${diff.inHours}h ago';
      }
    } else if (_hasUnsavedChanges) {
      return 'Unsaved changes';
    }
    return '';
  }

  Color _getAutoSaveStatusColor() {
    if (_isAutoSaving) {
      return const Color(0xFF0078D4);
    } else if (_lastAutoSave != null && !_hasUnsavedChanges) {
      return const Color(0xFF10893E);
    } else if (_hasUnsavedChanges) {
      return const Color(0xFFFFC83D);
    }
    return const Color(0xFF8A8886);
  }

  IconData _getAutoSaveIcon() {
    if (_isAutoSaving) {
      return Icons.cloud_sync;
    } else if (_lastAutoSave != null && !_hasUnsavedChanges) {
      return Icons.cloud_done;
    } else if (_hasUnsavedChanges) {
      return Icons.cloud_queue;
    }
    return Icons.cloud_off;
  }
  void _navigateToEntries() {
    logger.i('Navigating to JournalEntriesPage');
    Navigator.pushNamed(context, '/journal-entries');
  }

  void _showTemplateSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a Template',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF252423),
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              itemCount: JournalTemplates.templates.length,
              itemBuilder: (context, index) {
                final template = JournalTemplates.templates[index];
                return InkWell(
                  onTap: () async {
                    if (!await _confirmOverwrite()) return;
                    setState(() {
                      _selectedTemplate = template;
                      _templateResponses.clear();
                    });
                    Navigator.pop(context);
                    _showTemplateEditor(template);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F2F1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEDEBE9)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          template.icon,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF252423),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                template.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF605E5C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Color(0xFF8A8886),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateEditor(JournalTemplate template) {
    final controllers = template.sections
        .map((s) => TextEditingController(text: _templateResponses[s.title] ?? ''))
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    template.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      template.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF252423),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: template.sections.length,
                  itemBuilder: (context, index) {
                    final section = template.sections[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.prompt,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF252423),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controllers[index],
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: section.placeholder ?? 'Your response...',
                              hintStyle: const TextStyle(color: Color(0xFF8A8886)),
                              filled: true,
                              fillColor: const Color(0xFFFAF9F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: Color(0xFF8A8886)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0078D4),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF8A8886)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF605E5C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Compile responses
                        final buffer = StringBuffer();
                        for (int i = 0; i < template.sections.length; i++) {
                          final section = template.sections[i];
                          final response = controllers[i].text.trim();
                          _templateResponses[section.title] = response;

                          buffer.writeln('${section.title}:');
                          buffer.writeln(response.isNotEmpty ? response : '(Not answered)');
                          buffer.writeln();
                        }

                        _textController.text = buffer.toString().trim();
                        _titleController.text = template.name;
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0078D4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Use Template',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0078D4).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isActive ? const Color(0xFF0078D4) : const Color(0xFF605E5C),
          size: 20,
        ),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  // In journal_writing_page.dart, replace the build method with this:

@override
Widget build(BuildContext context) {
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

      if (_hasUnsavedChanges) {
        final shouldSave = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: const Text('Unsaved Changes', style: TextStyle(fontWeight: FontWeight.w600)),
            content: const Text('Your changes will be saved as a draft.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: const Text('Discard', style: TextStyle(color: Color(0xFFE74856))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF605E5C))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: const Text('Save Draft', style: TextStyle(color: Color(0xFF0078D4))),
              ),
            ],
          ),
        );

       if (shouldSave == 'save') {
  await _performAutoSave(); // Auto-save as draft
} else if (shouldSave != 'discard') {
  return;
}
          }

      if (mounted) {
        if (widget.initialEntry != null) {
          Navigator.pushNamed(context, '/journal-entries');
        } else {
          Navigator.pushNamed(context, '/mood-selection');
        }
      }
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Template Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFEDEBE9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF605E5C)),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Write Entry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF252423),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final statusText = _getAutoSaveStatus();
                            if (statusText.isEmpty) return const SizedBox.shrink();

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getAutoSaveIcon(),
                                  size: 12,
                                  color: _getAutoSaveStatusColor(),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getAutoSaveStatusColor(),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Template Button in AppBar
                  IconButton(
                    icon: const Icon(Icons.article_outlined, color: Color(0xFF0078D4)),
                    tooltip: 'Use Template',
                    onPressed: _showTemplateSelector,
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Template indicator
                    if (_selectedTemplate != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8661C5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF8661C5).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selectedTemplate!.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Using template: ${_selectedTemplate!.name}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8661C5),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedTemplate = null;
                                  _templateResponses.clear();
                                });
                              },
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Color(0xFF8661C5),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Title Field
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Entry title',
                        hintStyle: TextStyle(
                          color: Color(0xFF8A8886),
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF252423),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Formatting Toolbar
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            _buildToolbarButton(
                              icon: Icons.format_bold,
                              isActive: _isBold,
                              onPressed: () => setState(() => _isBold = !_isBold),
                              tooltip: 'Bold',
                            ),
                            _buildToolbarButton(
                              icon: Icons.format_italic,
                              isActive: _isItalic,
                              onPressed: () => setState(() => _isItalic = !_isItalic),
                              tooltip: 'Italic',
                            ),
                            _buildToolbarButton(
                              icon: Icons.format_underline,
                              isActive: _isUnderline,
                              onPressed: () => setState(() => _isUnderline = !_isUnderline),
                              tooltip: 'Underline',
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: const Color(0xFFEDEBE9),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            _buildToolbarButton(
                              icon: Icons.format_align_left,
                              isActive: _alignment == 'left',
                              onPressed: () => setState(() => _alignment = 'left'),
                              tooltip: 'Align Left',
                            ),
                            _buildToolbarButton(
                              icon: Icons.format_align_center,
                              isActive: _alignment == 'center',
                              onPressed: () => setState(() => _alignment = 'center'),
                              tooltip: 'Align Center',
                            ),
                            _buildToolbarButton(
                              icon: Icons.format_align_right,
                              isActive: _alignment == 'right',
                              onPressed: () => setState(() => _alignment = 'right'),
                              tooltip: 'Align Right',
                            ),
                            _buildToolbarButton(
                              icon: Icons.format_align_justify,
                              isActive: _alignment == 'justify',
                              onPressed: () => setState(() => _alignment = 'justify'),
                              tooltip: 'Justify',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Text Editor
                    TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 10,
                      textAlign: textAlign,
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF252423),
                        fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                        decoration: _isUnderline ? TextDecoration.underline : TextDecoration.none,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Start writing your thoughts...',
                        hintStyle: TextStyle(
                          color: Color(0xFF8A8886),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Word and Character Count
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F2F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_wordCount words',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF605E5C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F2F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_charCount characters',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF605E5C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Buttons (Fixed - no overlap)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _navigateToEntries,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF0078D4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'View Entries',
                          style: TextStyle(
                            color: Color(0xFF0078D4),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _saveEntry(isDraft: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0078D4),
                          disabledBackgroundColor: const Color(0xFF8A8886),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                widget.initialEntry != null ? 'Update' : 'Save',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}