// journal_entry_details_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'journal_writing_page.dart';
import 'journal_models.dart';

class JournalEntryDetailsPage extends StatefulWidget {
  final JournalEntry entry;
  final int entryIndex;
  final Function(int) toggleFavorite;
  final Function(int) deleteEntry;
  final List<JournalEntry> entries;
  final Function(JournalEntry) addEntry;
  final Function(int, JournalEntry) updateEntry;

  const JournalEntryDetailsPage({
    super.key,
    required this.entry,
    required this.entryIndex,
    required this.toggleFavorite,
    required this.deleteEntry,
    required this.entries,
    required this.addEntry,
    required this.updateEntry,
  });

  @override
  State<JournalEntryDetailsPage> createState() => _JournalEntryDetailsPageState();
}

class _JournalEntryDetailsPageState extends State<JournalEntryDetailsPage> {
  final Logger logger = Logger();

  String _getMonthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month];
  }

  String _getMoodEmoji(String mood) {
    const moods = {
      'Rad': '😎',
      'Happy': '😄',
      'Meh': '😐',
      'Sad': '😢',
      'Angry': '😠',
    };
    return moods[mood] ?? '❓';
  }

  IconData _getTagIcon(String tag) {
    switch (tag) {
      case 'Personal':
        return Icons.person_outline;
      case 'Work':
        return Icons.work_outline;
      case 'Travel':
        return Icons.flight_takeoff;
      case 'Study':
        return Icons.school_outlined;
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Plant':
        return Icons.eco_outlined;
      default:
        return Icons.label_outline;
    }
  }

  TextAlign _getTextAlign(String? alignment) {
    switch (alignment) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  Future<void> _deleteEntry() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Delete Entry', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to delete this journal entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF605E5C))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE74856))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      widget.deleteEntry(widget.entryIndex);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted successfully'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _editEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalWritingPage(
          mood: widget.entry.mood,
          tagId: widget.entry.tagId,
          tagName: widget.entry.tagName,
          entries: widget.entries,
          addEntry: (entry) => widget.addEntry(entry),
          updateEntry: (index, entry) => widget.updateEntry(index, entry),
          deleteEntry: (index) => widget.deleteEntry(index),
          toggleFavorite: (index) => widget.toggleFavorite(index),
          initialEntry: widget.entry,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final content = jsonDecode(widget.entry.content);
    final contentText = content['text'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Entry Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF252423),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF605E5C)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: _editEntry,
                        child: const Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20, color: Color(0xFF0078D4)),
                            SizedBox(width: 12),
                            Text('Edit Entry'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () {
                          widget.toggleFavorite(widget.entryIndex);
                          setState(() {});
                        },
                        child: Row(
                          children: [
                            Icon(
                              widget.entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                              size: 20,
                              color: const Color(0xFFE74856),
                            ),
                            const SizedBox(width: 12),
                            Text(widget.entry.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: _deleteEntry,
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Color(0xFFE74856)),
                            SizedBox(width: 12),
                            Text('Delete Entry', style: TextStyle(color: Color(0xFFE74856))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Draft badge
                    if (widget.entry.isDraft)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC83D),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DRAFT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    // Title
                    if (widget.entry.title.isNotEmpty) ...[
                      Text(
                        widget.entry.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF252423),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Date, mood, and tag
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: const Color(0xFF8A8886),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.entry.timestamp.day} ${_getMonthName(widget.entry.timestamp.month)} ${widget.entry.timestamp.year}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF605E5C),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: const Color(0xFF8A8886),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          TimeOfDay.fromDateTime(widget.entry.timestamp).format(context),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF605E5C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Mood and Tag badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.entry.mood != 'Not specified')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F2F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getMoodEmoji(widget.entry.mood),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.entry.mood,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF605E5C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.entry.tagName != null && widget.entry.tagName != 'Not specified')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F2F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getTagIcon(widget.entry.tagName!),
                                  size: 14,
                                  color: const Color(0xFF605E5C),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.entry.tagName!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF605E5C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    const Divider(color: Color(0xFFEDEBE9)),
                    const SizedBox(height: 24),

                    // Content
                    Text(
                      contentText,
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF252423),
                        height: 1.6,
                        fontWeight: content['isBold'] ?? false ? FontWeight.bold : FontWeight.normal,
                        fontStyle: content['isItalic'] ?? false ? FontStyle.italic : FontStyle.normal,
                        decoration: content['isUnderline'] ?? false ? TextDecoration.underline : TextDecoration.none,
                      ),
                      textAlign: _getTextAlign(content['alignment']),
                    ),

                    // Last modified
                    if (widget.entry.lastModified != null) ...[
                      const SizedBox(height: 32),
                      Text(
                        'Last modified: ${widget.entry.lastModified!.day} ${_getMonthName(widget.entry.lastModified!.month)} ${widget.entry.lastModified!.year} at ${TimeOfDay.fromDateTime(widget.entry.lastModified!).format(context)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8886),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}