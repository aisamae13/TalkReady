// enhanced_journal_entries.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'journal_entry_details_page.dart';
import 'journal_stats_page.dart';
import 'journal_models.dart';

class JournalEntriesPage extends StatefulWidget {
  final List<JournalEntry> entries;
  final Function(JournalEntry) addEntry;
  final Function(int, JournalEntry) updateEntry;
  final Function(int) deleteEntry;
  final Function(int) toggleFavorite;

  const JournalEntriesPage({
    super.key,
    required this.entries,
    required this.addEntry,
    required this.updateEntry,
    required this.deleteEntry,
    required this.toggleFavorite,
    required Future<void> Function(int index, JournalEntry updatedEntry) onUpdateEntry,
  });

  @override
  State<JournalEntriesPage> createState() => _JournalEntriesPageState();
}

class _JournalEntriesPageState extends State<JournalEntriesPage> {
  final Logger logger = Logger();
  String filterMood = 'All';
  String filterTag = 'All';
  bool filterFavorites = false;
  bool filterDrafts = false;
  String filterTime = 'All';
  int currentPage = 1;
  static const int pageSize = 10;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Filter entries
    List<JournalEntry> filteredEntries = widget.entries.where((entry) {
  bool matchesMood = filterMood == 'All' || entry.mood == filterMood;
  bool matchesTag = filterTag == 'All' || (entry.tagName ?? '') == filterTag;
  bool matchesFavorite = !filterFavorites || entry.isFavorite;
  bool matchesDraft = !filterDrafts || entry.isDraft;
  bool matchesTime = true;
  final now = DateTime.now();
  if (filterTime == 'Last 7 Days') {
    matchesTime = entry.timestamp.isAfter(now.subtract(const Duration(days: 7)));
  } else if (filterTime == 'Last 30 Days') {
    matchesTime = entry.timestamp.isAfter(now.subtract(const Duration(days: 30)));
  } else if (filterTime == 'Last 3 Months') {
    matchesTime = entry.timestamp.isAfter(now.subtract(const Duration(days: 90)));
  } else if (filterTime == 'Last 6 Months') {
    matchesTime = entry.timestamp.isAfter(now.subtract(const Duration(days: 180)));
  } else if (filterTime == 'This Year') {
    matchesTime = entry.timestamp.year == now.year;
  }
  return matchesMood && matchesTag && matchesFavorite && matchesDraft && matchesTime;
}).toList();

    int startIndex = (currentPage - 1) * pageSize;
    int endIndex = startIndex + pageSize;
    List<JournalEntry> paginatedEntries = filteredEntries.sublist(
      startIndex,
      endIndex > filteredEntries.length ? filteredEntries.length : endIndex,
    );

    bool hasPrevious = currentPage > 1;
    bool hasNext = endIndex < filteredEntries.length;

    // Check if this is first time user (no entries at all)
    final isFirstTime = widget.entries.isEmpty;

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
                    onPressed: () {
                      logger.i('Back button pressed on JournalEntriesPage');
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Journal Entries',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF252423),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Stats Button
                  if (widget.entries.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined, color: Color(0xFF0078D4)),
                      tooltip: 'Journal Insights',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JournalStatsPage(entries: widget.entries),
                          ),
                        );
                      },
                    ),
                  // Filter Button
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Color(0xFF605E5C)),
                    tooltip: 'Filter Entries',
                    onPressed: () {
                      _showFilterModal(context);
                    },
                  ),
                ],
              ),
            ),

            // Active Filters Display
            if (filterMood != 'All' || filterTag != 'All' || filterFavorites || filterDrafts || filterTime != 'All')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFF3F2F1),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (filterMood != 'All')
                      _buildFilterChip('Mood: $filterMood', () {
                        setState(() => filterMood = 'All');
                      }),
                    if (filterTag != 'All')
                      _buildFilterChip('Tag: $filterTag', () {
                        setState(() => filterTag = 'All');
                      }),
                    if (filterFavorites)
                      _buildFilterChip('Favorites', () {
                        setState(() => filterFavorites = false);
                      }),
                    if (filterDrafts)
                      _buildFilterChip('Drafts', () {
                        setState(() => filterDrafts = false);
                      }),
                    if (filterTime != 'All')
                      _buildFilterChip(filterTime, () {
                        setState(() => filterTime = 'All');
                      }),
                  ],
                ),
              ),

            // Entries List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0078D4),
                      ),
                    )
                  : paginatedEntries.isEmpty
                      ? _buildEmptyState(isFirstTime)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: paginatedEntries.length,
                          itemBuilder: (context, index) {
                            final entry = paginatedEntries[index];
                            final entryIndex = widget.entries.indexOf(entry);

                            return _buildEntryCard(entry, entryIndex);
                          },
                        ),
            ),

            // Pagination
            if (hasPrevious || hasNext)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: const Color(0xFFEDEBE9), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: hasPrevious
                          ? () {
                              setState(() {
                                currentPage--;
                              });
                            }
                          : null,
                      color: const Color(0xFF0078D4),
                      disabledColor: const Color(0xFF8A8886),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Page $currentPage',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF252423),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: hasNext
                          ? () {
                              setState(() {
                                currentPage++;
                              });
                            }
                          : null,
                      color: const Color(0xFF0078D4),
                      disabledColor: const Color(0xFF8A8886),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isFirstTime) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0078D4).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.library_books_outlined,
                size: 64,
                color: Color(0xFF0078D4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFirstTime ? 'Start Your Journey' : 'No entries found',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF252423),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFirstTime
                  ? 'Your journal is empty. Begin by capturing your thoughts, feelings, and experiences.'
                  : 'Try adjusting your filters to see more entries',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF605E5C),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (isFirstTime) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/mood-selection');
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Create Your First Entry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0078D4),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F2F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tips for journaling:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF252423),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTip('Write regularly to build a habit'),
                    _buildTip('Be honest with yourself'),
                    _buildTip('Don\'t worry about grammar'),
                    _buildTip('Reflect on your mood patterns'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF0078D4),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF605E5C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0078D4).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0078D4).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0078D4),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF0078D4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(JournalEntry entry, int entryIndex) {
    final content = jsonDecode(entry.content);
    final contentText = content['text'] ?? '';

    return Dismissible(
      key: Key(entry.id ?? entry.timestamp.toString()),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10893E),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE74856),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Toggle favorite
          widget.toggleFavorite(entryIndex);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(entry.isFavorite ? 'Added to favorites' : 'Removed from favorites'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        } else {
          // Delete
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: const Text('Delete Entry', style: TextStyle(fontWeight: FontWeight.w600)),
              content: const Text('Are you sure you want to delete this journal entry?'),
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
            setState(() => _isLoading = true);
            try {
              widget.deleteEntry(entryIndex);
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Entry deleted successfully'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete entry: ${e.toString()}'),
                    backgroundColor: const Color(0xFFE74856),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          }
          return confirm ?? false;
        }
      },
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JournalEntryDetailsPage(
                entry: entry,
                entryIndex: entryIndex,
                toggleFavorite: widget.toggleFavorite,
                deleteEntry: widget.deleteEntry,
                entries: widget.entries,
                addEntry: (JournalEntry e) => widget.addEntry(e),
                updateEntry: (int i, JournalEntry e) => widget.updateEntry(i, e),
              ),
            ),
          ).then((_) => setState(() {}));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: entry.isDraft
                  ? const Color(0xFFFFC83D)
                  : const Color(0xFFEDEBE9),
              width: entry.isDraft ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (entry.isDraft)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC83D),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DRAFT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (entry.title.isNotEmpty)
                              Expanded(
                                child: Text(
                                  entry.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF252423),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.timestamp.day} ${_getMonthName(entry.timestamp.month)} ${entry.timestamp.year} • ${TimeOfDay.fromDateTime(entry.timestamp).format(context)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF605E5C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: entry.isFavorite ? const Color(0xFFE74856) : const Color(0xFF8A8886),
                      size: 20,
                    ),
                    onPressed: () {
                      widget.toggleFavorite(entryIndex);
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content Preview with proper formatting
              Text(
                contentText,
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF605E5C),
                  fontWeight: content['isBold'] ?? false ? FontWeight.bold : FontWeight.normal,
                  fontStyle: content['isItalic'] ?? false ? FontStyle.italic : FontStyle.normal,
                  decoration: content['isUnderline'] ?? false ? TextDecoration.underline : TextDecoration.none,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: _getTextAlign(content['alignment']),
              ),
              const SizedBox(height: 12),

              // Tags Row
              Row(
                children: [
                  // Mood Badge
                  if (entry.mood != 'Not specified')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getMoodEmoji(entry.mood),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.mood,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF605E5C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),

                  // Tag Badge
                  if (entry.tagName != 'Not specified')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getTagIcon(entry.tagName ?? ''),
                            size: 12,
                            color: const Color(0xFF605E5C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.tagName ?? 'None',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF605E5C),
                            ),
                          ),
                        ],
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

void _showFilterModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      String tempMood = filterMood;
      String tempTag = filterTag;
      bool tempFavorites = filterFavorites;
      bool tempDrafts = filterDrafts;
      String tempTime = filterTime;

      // Get unique moods and tags from entries
      final moods = ['All', ...widget.entries.map((e) => e.mood).where((m) => m != 'Not specified').toSet()];
      final tags = ['All', ...widget.entries.map((e) => e.tagName ?? '').where((t) => t.isNotEmpty && t != 'Not specified').toSet()];

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter modalSetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Filter Entries',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF252423),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF8A8886)),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Mood Filter
                        const Text(
                          'Filter by Mood',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF605E5C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: moods.map((mood) {
                            final isSelected = tempMood == mood;
                            return InkWell(
                              onTap: () {
                                modalSetState(() => tempMood = mood);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0078D4)
                                      : const Color(0xFFF3F2F1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0078D4)
                                        : const Color(0xFFEDEBE9),
                                  ),
                                ),
                                child: Text(
                                  mood,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF605E5C),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Tag Filter
                        const Text(
                          'Filter by Tag',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF605E5C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tags.map((tag) {
                            final isSelected = tempTag == tag;
                            return InkWell(
                              onTap: () {
                                modalSetState(() => tempTag = tag);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0078D4)
                                      : const Color(0xFFF3F2F1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0078D4)
                                        : const Color(0xFFEDEBE9),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF605E5C),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Time Period Filter
                        const Text(
                          'Time Period',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF605E5C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['All', 'Last 7 Days', 'Last 30 Days', 'Last 3 Months', 'Last 6 Months', 'This Year'].map((period) {
                            final isSelected = tempTime == period;
                            return InkWell(
                              onTap: () {
                                modalSetState(() => tempTime = period);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0078D4)
                                      : const Color(0xFFF3F2F1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0078D4)
                                        : const Color(0xFFEDEBE9),
                                  ),
                                ),
                                child: Text(
                                  period,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF605E5C),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Status Filters
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF605E5C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Favorites Only', style: TextStyle(fontSize: 13)),
                                value: tempFavorites,
                                onChanged: (value) {
                                  modalSetState(() => tempFavorites = value ?? false);
                                },
                                activeColor: const Color(0xFF0078D4),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Drafts Only', style: TextStyle(fontSize: 13)),
                                value: tempDrafts,
                                onChanged: (value) {
                                  modalSetState(() => tempDrafts = value ?? false);
                                },
                                activeColor: const Color(0xFFFFC83D),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  modalSetState(() {
                                    tempMood = 'All';
                                    tempTag = 'All';
                                    tempFavorites = false;
                                    tempDrafts = false;
                                    tempTime = 'All';
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFF8A8886)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  'Clear All',
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
                                  setState(() {
                                    filterMood = tempMood;
                                    filterTag = tempTag;
                                    filterFavorites = tempFavorites;
                                    filterDrafts = tempDrafts;
                                    filterTime = tempTime;
                                    currentPage = 1;
                                  });
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
                                  'Apply Filters',
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
              ],
            ),
          );
        },
      );
    },
  );
}
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
}