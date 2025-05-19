import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'mood_selection_page.dart';
import 'journal_writing_page.dart';
import 'journal_entries.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

class JournalEntry {
  final String mood;
  final String tag;
  final String title;
  final String content;
  final DateTime timestamp;
  bool isFavorite;
  final String? id;

  JournalEntry({
    required this.mood,
    required this.tag,
    required this.title,
    required this.content,
    required this.timestamp,
    this.isFavorite = false,
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'mood': mood,
      'tag': tag,
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFavorite': isFavorite,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map, String id) {
    logger.i('Loading entry from Firestore: mood=${map['mood']}, tag=${map['tag']}');
    if (map['mood'] == null) logger.w('Mood is null in Firestore data for entry ID: $id');
    if (map['tag'] == null) logger.w('Tag is null in Firestore data for entry ID: $id');
    return JournalEntry(
      id: id,
      mood: map['mood'] ?? 'Not specified',
      tag: map['tag'] ?? 'Not specified',
      title: map['title'] ?? '',
      content: map['content'] ?? '{}',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isFavorite: map['isFavorite'] ?? false,
    );
  }
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final List<JournalEntry> _entries = [];
  final Logger logger = Logger();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.w('No authenticated user found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journal_entries')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _entries.clear();
        _entries.addAll(snapshot.docs.map((doc) => JournalEntry.fromMap(doc.data(), doc.id)));
        _isLoading = false;
      });
      logger.i('Loaded ${_entries.length} journal entries from Firestore');
    } catch (e) {
      logger.e('Error loading entries: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading journal entries')),
      );
    }
  }

  Future<void> _addEntry(JournalEntry entry) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.w('No authenticated user found');
        return;
      }

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journal_entries')
          .add(entry.toMap());

      setState(() {
        _entries.insert(0, JournalEntry(
          id: docRef.id,
          mood: entry.mood,
          tag: entry.tag,
          title: entry.title,
          content: entry.content,
          timestamp: entry.timestamp,
          isFavorite: entry.isFavorite,
        ));
      });
      logger.i('Added journal entry with ID: ${docRef.id}, mood: ${entry.mood}, tag: ${entry.tag}');
    } catch (e) {
      logger.e('Error adding entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving journal entry')),
      );
    }
  }

  Future<void> _updateEntry(int index, JournalEntry updatedEntry) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.w('No authenticated user found');
        return;
      }

      final entry = _entries[index];
      if (entry.id == null) {
        logger.w('Entry has no ID, cannot update');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journal_entries')
          .doc(entry.id)
          .update(updatedEntry.toMap());

      setState(() {
        _entries[index] = JournalEntry(
          id: entry.id,
          mood: updatedEntry.mood,
          tag: updatedEntry.tag,
          title: updatedEntry.title,
          content: updatedEntry.content,
          timestamp: updatedEntry.timestamp,
          isFavorite: updatedEntry.isFavorite,
        );
      });
      logger.i('Updated journal entry with ID: ${entry.id}');
    } catch (e) {
      logger.e('Error updating entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating journal entry')),
      );
    }
  }

  Future<void> _deleteEntry(int index) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.w('No authenticated user found');
        return;
      }

      final entry = _entries[index];
      if (entry.id == null) {
        logger.w('Entry has no ID, cannot delete');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journal_entries')
          .doc(entry.id)
          .delete();

      setState(() {
        _entries.removeAt(index);
      });
      logger.i('Deleted journal entry with ID: ${entry.id}');
    } catch (e) {
      logger.e('Error deleting entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting journal entry')),
      );
    }
  }

  void _toggleFavorite(int index) {
    setState(() {
      _entries[index].isFavorite = !_entries[index].isFavorite;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logger.w('No authenticated user found');
      return;
    }

    final entry = _entries[index];
    if (entry.id == null) {
      logger.w('Entry has no ID, cannot update favorite status');
      return;
    }

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('journal_entries')
        .doc(entry.id)
        .update({'isFavorite': _entries[index].isFavorite})
        .then((_) => logger.i('Updated favorite status for entry ID: ${entry.id}'))
        .catchError((e) => logger.e('Error updating favorite status: $e'));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
  return Scaffold(
    body: Center(
      child: CircularProgressIndicator(
        color: Color(0xFF00568D),
      ),
    ),
  );
}
    return Navigator(
      initialRoute: '/mood-selection',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/mood-selection':
            return MaterialPageRoute(
              builder: (context) => MoodSelectionPage(
                onMoodSelected: (mood, tag) {
                  logger.i('MoodSelectionPage callback - mood: $mood, tag: $tag');
                  Navigator.pushNamed(
                    context,
                    '/journal-writing',
                    arguments: {
                      'mood': mood,
                      'tag': tag,
                      'entries': _entries,
                      'addEntry': _addEntry,
                      'updateEntry': _updateEntry,
                      'deleteEntry': _deleteEntry,
                      'toggleFavorite': _toggleFavorite,
                    },
                  );
                },
              ),
            );

          case '/journal-writing':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args == null ||
                !args.containsKey('mood') ||
                !args.containsKey('tag') ||
                !args.containsKey('entries') ||
                !args.containsKey('addEntry') ||
                !args.containsKey('updateEntry') ||
                !args.containsKey('deleteEntry') ||
                !args.containsKey('toggleFavorite')) {
              logger.e('Missing arguments for JournalWritingPage: $args');
              return MaterialPageRoute(
                builder: (context) => const Scaffold(
                  body: Center(child: Text('Error: Missing arguments')),
                ),
              );
            }
            final mood = args['mood'] as String?;
            final tag = args['tag'] as String?;
            if (mood == null || tag == null) {
              logger.w('Navigating to JournalWritingPage with null mood or tag: mood=$mood, tag=$tag');
            } else {
              logger.i('Navigating to JournalWritingPage with args: mood=$mood, tag=$tag');
            }
            return MaterialPageRoute(
              builder: (context) => JournalWritingPage(
                mood: mood,
                tag: tag,
                entries: args['entries'] as List<JournalEntry>,
                addEntry: args['addEntry'] as Function(JournalEntry),
                updateEntry: args['updateEntry'] as Function(int, JournalEntry),
                deleteEntry: args['deleteEntry'] as Function(int),
                toggleFavorite: args['toggleFavorite'] as Function(int),
              ),
            );

          case '/journal-entries':
            return MaterialPageRoute(
              builder: (context) => JournalEntriesPage(
                entries: _entries,
                addEntry: _addEntry,
                updateEntry: _updateEntry,
                deleteEntry: _deleteEntry,
                toggleFavorite: _toggleFavorite,
              ),
            );

          default:
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(child: Text('Page not found')),
              ),
            );
        }
      },
    );
  }
}