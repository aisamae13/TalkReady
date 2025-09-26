import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'journal_page.dart';
import 'journal_writing_page.dart';

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
    required this.toggleFavorite, required Future<void> Function(int index, JournalEntry updatedEntry) onUpdateEntry,
  });

  @override
  State<JournalEntriesPage> createState() => _JournalEntriesPageState();
}

class _JournalEntriesPageState extends State<JournalEntriesPage> {
  final Logger logger = Logger();
  String filterMood = 'All';
  String filterTag = 'All';
  bool filterFavorites = false;
  String filterTime = 'All';
  int currentPage = 1;
  static const int pageSize = 10;

  @override
  Widget build(BuildContext context) {
    // Filter entries based on mood, tag, favorites, and time
       List<JournalEntry> filteredEntries = widget.entries.where((entry) {
      bool matchesMood = filterMood == 'All' || entry.mood == filterMood;
      bool matchesTag = filterTag == 'All' || (entry.tagName ?? '') == filterTag;
      bool matchesFavorite = !filterFavorites || entry.isFavorite;
      bool matchesTime = true;
      final now = DateTime.now();
      if (filterTime == 'Last 7 Days') {
        matchesTime = entry.timestamp.isAfter(now.subtract(const Duration(days: 7)));
      } else if (filterTime == 'Last 30 Days') {
        matchesTime = entry.timestamp.isAfter(now.subtract(const Duration(days: 30)));
      }
      return matchesMood && matchesTag && matchesFavorite && matchesTime;
    }).toList();

    int startIndex = (currentPage - 1) * pageSize;
    int endIndex = startIndex + pageSize;
    List<JournalEntry> paginatedEntries = filteredEntries.sublist(
      startIndex,
      endIndex > filteredEntries.length ? filteredEntries.length : endIndex,
    );

    bool hasPrevious = currentPage > 1;
    bool hasNext = endIndex < filteredEntries.length;

    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00568D), Color(0xFF003F6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    String tempMood = filterMood;
                    String tempTag = filterTag;
                    bool tempFavorites = filterFavorites;
                    String tempTime = filterTime;

                    return StatefulBuilder(
                      builder: (BuildContext context, StateSetter modalSetState) {
                        return Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFDEE3FF).withOpacity(0.5),
                                const Color(0xFFD8F6F7).withOpacity(0.5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.all(20.0),
                            children: [
                              const Text(
                                'Filter Entries',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00568D),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text('Mood'),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  'All',
                                  'Rad',
                                  'Happy',
                                  'Meh',
                                  'Sad',
                                  'Angry',
                                ].map((mood) {
                                  return ChoiceChip(
                                    label: Text(mood),
                                    selected: tempMood == mood,
                                    selectedColor: const Color(0xFF00568D).withOpacity(0.5),
                                    backgroundColor: Colors.white.withOpacity(0.8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(color: const Color(0xFF00568D).withOpacity(0.2)),
                                    ),
                                    elevation: 2,
                                    onSelected: (selected) {
                                      modalSetState(() {
                                        tempMood = mood;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              const Text('Tag'),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                 children:
                                 [
                                    'All',
                                    ...widget.entries
                                        .map((e) => e.tagName)
                                        .where((tag) => tag != null && tag.isNotEmpty)
                                        .toSet()
                                        .toList(),
                                  ].map((tag) {
                                 return ChoiceChip(
                                    label: Text(tag ?? 'Unknown'),
                                    selected: tempTag == (tag ?? ''),
                                    selectedColor: const Color(0xFF00568D).withOpacity(0.5),
                                    backgroundColor: Colors.white.withOpacity(0.8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(color: const Color(0xFF00568D).withOpacity(0.2)),
                                    ),
                                    elevation: 2,
                                    onSelected: (selected) {
                                      modalSetState(() {
                                        tempTag = tag ?? '';
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              const Text('Time'),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  'All',
                                  'Last 7 Days',
                                  'Last 30 Days',
                                ].map((time) {
                                  return ChoiceChip(
                                    label: Text(time),
                                    selected: tempTime == time,
                                    selectedColor: const Color(0xFF00568D).withOpacity(0.5),
                                    backgroundColor: Colors.white.withOpacity(0.8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(color: const Color(0xFF00568D).withOpacity(0.2)),
                                    ),
                                    elevation: 2,
                                    onSelected: (selected) {
                                      modalSetState(() {
                                        tempTime = time;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Favorites Only',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00568D),
                                      ),
                                    ),
                                    Switch(
                                      value: tempFavorites,
                                      onChanged: (value) {
                                        modalSetState(() {
                                          tempFavorites = value;
                                        });
                                      },
                                      activeColor: const Color(0xFF00568D),
                                      activeTrackColor: const Color(0xFF00568D).withOpacity(0.7),
                                      inactiveThumbColor: Colors.grey,
                                      inactiveTrackColor: Colors.grey.withOpacity(0.5),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(
                                    width: MediaQuery.of(context).size.width * 0.35,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00568D), Color(0xFF003F6A)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          filterMood = tempMood;
                                          filterTag = tempTag;
                                          filterFavorites = tempFavorites;
                                          filterTime = tempTime;
                                          currentPage = 1;
                                        });
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text(
                                        'Apply',
                                        style: TextStyle(fontSize: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Container(
                                    width: MediaQuery.of(context).size.width * 0.35,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF808080), Color(0xFF696969)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        modalSetState(() {
                                          tempMood = 'All';
                                          tempTag = 'All';
                                          tempFavorites = false;
                                          tempTime = 'All';
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(fontSize: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.filter_list,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00568D), Color(0xFF003F6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                logger.i('Navigating to Journal Stats Page');
                Navigator.pushNamed(context, '/journal-stats');
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.bar_chart,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00568D).withValues(alpha: 0.1),
              Colors.white,
              const Color(0xFFE0FFD6).withValues(alpha: 0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF00568D)),
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
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00568D),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: paginatedEntries.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
                            ),
                            child: const Text(
                              'No entries yet.',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: paginatedEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = paginatedEntries[index];
                                  final entryIndex = widget.entries.indexOf(entry);

                                  return GestureDetector(
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
                                            addEntry: widget.addEntry,
                                            updateEntry: widget.updateEntry,
                                          ),
                                        ),
                                      ).then((_) => setState(() {}));
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFDEE3FF).withOpacity(0.5),
                                            const Color(0xFFD8F6F7).withOpacity(0.5),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border(
                                          left: BorderSide(
                                            color: const Color(0xFF00568D),
                                            width: 2.0,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left side: Date and Time
                                          SizedBox(
                                            width: 85,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${entry.timestamp.day} ${_getMonthName(entry.timestamp.month)} ${entry.timestamp.year}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  TimeOfDay.fromDateTime(entry.timestamp).format(context),
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Vertical line separator
                                          SizedBox(
                                            height: 70,
                                            child: Container(
                                              width: 1,
                                              color: Colors.grey.withOpacity(0.5),
                                              margin: const EdgeInsets.symmetric(horizontal: 12),
                                            ),
                                          ),
                                          // Right side: Title, Content, Mood, Tag, and Favorite
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          if (entry.title.isNotEmpty)
                                                            Text(
                                                              entry.title,
                                                              style: const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFF00568D),
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          const SizedBox(height: 5),
                                                          Text(
                                                            jsonDecode(entry.content)['text'] ?? '',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.black,
                                                              fontWeight: jsonDecode(entry.content)['isBold'] ?? false
                                                                  ? FontWeight.bold
                                                                  : FontWeight.normal,
                                                              fontStyle: jsonDecode(entry.content)['isItalic'] ?? false
                                                                  ? FontStyle.italic
                                                                  : FontStyle.normal,
                                                              decoration: jsonDecode(entry.content)['isUnderline'] ?? false
                                                                  ? TextDecoration.underline
                                                                  : TextDecoration.none,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                                                        color: entry.isFavorite ? Colors.red : Colors.grey,
                                                      ),
                                                      onPressed: () {
                                                        widget.toggleFavorite(entryIndex);
                                                        setState(() {});
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    // Mood display
                                                    Expanded(
                                                      child: entry.mood == 'Not specified'
                                                          ? Text(
                                                              'Mood: Not specified',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Color(0xFF00568D),
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            )
                                                          : Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Text(
                                                                  _getMoodEmoji(entry.mood),
                                                                  style: const TextStyle(fontSize: 16),
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  entry.mood,
                                                                  style: const TextStyle(
                                                                    fontSize: 12,
                                                                    color: Color(0xFF00568D),
                                                                    fontStyle: FontStyle.italic,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    // Tag display
                                                    Expanded(
                                                      child: entry.tagName == 'Not specified'
                                                          ? Text(
                                                              'Tag: Not specified',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Color(0xFF00568D),
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            )
                                                          : Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  _getTagIcon(entry.tagName ?? ''),
                                                                  size: 16,
                                                                  color: const Color(0xFF00568D),
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  entry.tagName ?? 'Unknown',
                                                                  style: const TextStyle(
                                                                    fontSize: 12,
                                                                    color: Color(0xFF00568D),
                                                                    fontStyle: FontStyle.italic,
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ],
                                                            ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (hasPrevious || hasNext)
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF00568D), Color(0xFF003F6A)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                                        onPressed: hasPrevious
                                            ? () {
                                                setState(() {
                                                  currentPage--;
                                                });
                                              }
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Text(
                                      'Page $currentPage',
                                      style: const TextStyle(fontSize: 16, color: Color(0xFF00568D)),
                                    ),
                                    const SizedBox(width: 20),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF00568D), Color(0xFF003F6A)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_forward, color: Colors.white),
                                        onPressed: hasNext
                                            ? () {
                                                setState(() {
                                                  currentPage++;
                                                });
                                              }
                                            : null,
                                      ),
                                    ),
                                  ],
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

  String _getMoodEmoji(String mood) {
    const moods = {
      'Rad': '😊',
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
        return Icons.person;
      case 'Work':
        return Icons.work;
      case 'Travel':
        return Icons.flight;
      case 'Study':
        return Icons.school;
      case 'Food':
        return Icons.fastfood;
      case 'Plant':
        return Icons.local_florist;
      default:
        return Icons.label; // Default icon for "Not specified" or invalid tags
    }
  }
}

class JournalEntryDetailsPage extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final content = jsonDecode(entry.content);
    TextAlign textAlign;
    switch (content['alignment'] ?? 'left') {
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

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00568D).withValues(alpha: 0.1),
              Colors.white,
              const Color(0xFFE0FFD6).withValues(alpha: 0.3),
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
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF00568D)),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF00568D)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => JournalWritingPage(
                                    mood: entry.mood,
                                    tagId: entry.tagId,
                                    tagName: entry.tagName,
                                    entries: entries,
                                    addEntry: addEntry,
                                    updateEntry: (index, updatedEntry) {
                                      updateEntry(index, updatedEntry);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Journal entry updated successfully'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    deleteEntry: deleteEntry,
                                    toggleFavorite: toggleFavorite,
                                    initialEntry: entry,
                                  ),
                                ),
                              ).then((_) => Navigator.pop(context));
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: entry.isFavorite ? Colors.red : Colors.grey,
                            ),
                            onPressed: () {
                              toggleFavorite(entryIndex);
                              Navigator.pop(context);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              deleteEntry(entryIndex);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Journal entry deleted successfully'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFDEE3FF).withOpacity(0.5),
                          const Color(0xFFD8F6F7).withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xFF00568D),
                          width: 2.0,
                        ),
                      ),
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
                          entry.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00568D),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Mood: ${entry.mood} | Tag: ${(entry.tagName?.isEmpty ?? true) ? "Not specified" : entry.tagName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF00568D),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${entry.timestamp.day} ${_getMonthName(entry.timestamp.month)} ${entry.timestamp.year} | ${TimeOfDay.fromDateTime(entry.timestamp).format(context)}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
                          ),
                          child: Text(
                            content['text'] ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: content['isBold'] ?? false ? FontWeight.bold : FontWeight.normal,
                              fontStyle: content['isItalic'] ?? false ? FontStyle.italic : FontStyle.normal,
                              decoration: content['isUnderline'] ?? false ? TextDecoration.underline : TextDecoration.none,
                            ),
                            textAlign: textAlign,
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
    );
  }
}