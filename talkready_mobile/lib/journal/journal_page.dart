import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'mood_selection_page.dart';
import 'journal_writing_page.dart';
import 'journal_entries.dart';
import 'journal_models.dart';
import 'package:talkready_mobile/custom_animated_bottom_bar.dart';
import '../homepage.dart';
import '../courses_page.dart';
import '../progress_page.dart';
import '../profile.dart';
import 'package:talkready_mobile/MyEnrolledClasses.dart';

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

// Helper function for creating a slide page route
Route _createSlidingPageRoute({
  required Widget page,
  required int newIndex,
  required int oldIndex,
  required Duration duration,
}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

// Updated Tag class
class Tag {
  final String id;
  final String name;
  final String iconCodePoint;
  final String userId;

  Tag({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconCodePoint': iconCodePoint,
      'userId': userId,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map, String id) {
    return Tag(
      id: id,
      name: map['name'] ?? '',
      iconCodePoint: map['iconCodePoint'] ?? '58944',
      userId: map['userId'] ?? '',
    );
  }
}

// Tag Service class
class TagService {
  static Future<List<Tag>> loadUserTags(String userId) async {
    try {
      List<Tag> defaultTags = [
        Tag(id: 'default_personal', name: 'Personal', iconCodePoint: '58944', userId: userId),
        Tag(id: 'default_work', name: 'Work', iconCodePoint: '59475', userId: userId),
        Tag(id: 'default_travel', name: 'Travel', iconCodePoint: '59126', userId: userId),
        Tag(id: 'default_study', name: 'Study', iconCodePoint: '58394', userId: userId),
        Tag(id: 'default_food', name: 'Food', iconCodePoint: '59522', userId: userId),
        Tag(id: 'default_plant', name: 'Plant', iconCodePoint: '59330', userId: userId),
      ];

      final snapshot = await FirebaseFirestore.instance
          .collection('tags')
          .where('userId', isEqualTo: userId)
          .get();

      final customTags = snapshot.docs.map((doc) => Tag.fromMap(doc.data(), doc.id)).toList();

      return [...defaultTags, ...customTags];
    } catch (e) {
      logger.e('Error loading tags: $e');
      return [];
    }
  }

  static Future<String?> addCustomTag(String name, IconData icon, String userId) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('tags')
          .add({
        'name': name,
        'iconCodePoint': icon.codePoint.toString(),
        'userId': userId,
      });

      logger.i('Added custom tag: $name with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      logger.e('Error adding custom tag: $e');
      return null;
    }
  }

  static Future<Tag?> getTagById(String tagId) async {
    try {
      if (tagId.startsWith('default_')) {
        Map<String, Map<String, String>> defaultTags = {
          'default_personal': {'name': 'Personal', 'iconCodePoint': '58944'},
          'default_work': {'name': 'Work', 'iconCodePoint': '59475'},
          'default_travel': {'name': 'Travel', 'iconCodePoint': '59126'},
          'default_study': {'name': 'Study', 'iconCodePoint': '58394'},
          'default_food': {'name': 'Food', 'iconCodePoint': '59522'},
          'default_plant': {'name': 'Plant', 'iconCodePoint': '59330'},
        };

        if (defaultTags.containsKey(tagId)) {
          return Tag(
            id: tagId,
            name: defaultTags[tagId]!['name']!,
            iconCodePoint: defaultTags[tagId]!['iconCodePoint']!,
            userId: '',
          );
        }
        return null;
      }

      final doc = await FirebaseFirestore.instance
          .collection('tags')
          .doc(tagId)
          .get();

      if (doc.exists) {
        return Tag.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      logger.e('Error getting tag by ID: $e');
      return null;
    }
  }
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final List<JournalEntry> _entries = [];
  bool _isLoading = true;
  int _selectedIndex = 3;

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
          .collection('journals')
          .where('userId', isEqualTo: user.uid)
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
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading journal entries')),
        );
      }
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
          .collection('journals')
          .add({
            'userId': user.uid,
            ...entry.toMap(),
          });

      setState(() {
        _entries.insert(0, JournalEntry(
          id: docRef.id,
          mood: entry.mood,
          tagId: entry.tagId,
          tagName: entry.tagName,
          title: entry.title,
          content: entry.content,
          timestamp: entry.timestamp,
          isFavorite: entry.isFavorite,
          isDraft: entry.isDraft,
          lastModified: entry.lastModified,
          templateId: entry.templateId,
        ));
      });
      logger.i('Added journal entry with ID: ${docRef.id}, mood: ${entry.mood}, tagId: ${entry.tagId}, tagName: ${entry.tagName}');
    } catch (e) {
      logger.e('Error adding entry: $e');
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving journal entry')),
        );
      }
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
          .collection('journals')
          .doc(entry.id)
          .update({
            'userId': user.uid,
            ...updatedEntry.toMap(),
          });

      setState(() {
        _entries[index] = JournalEntry(
          id: entry.id,
          mood: updatedEntry.mood,
          tagId: updatedEntry.tagId,
          tagName: updatedEntry.tagName,
          title: updatedEntry.title,
          content: updatedEntry.content,
          timestamp: updatedEntry.timestamp,
          isFavorite: updatedEntry.isFavorite,
          isDraft: entry.isDraft,
          lastModified: entry.lastModified,
          templateId: entry.templateId,
        );
      });
      logger.i('Updated journal entry with ID: ${entry.id}');
    } catch (e) {
      logger.e('Error updating entry: $e');
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating journal entry')),
        );
      }
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
          .collection('journals')
          .doc(entry.id)
          .delete();

      setState(() {
        _entries.removeAt(index);
      });
      logger.i('Deleted journal entry with ID: ${entry.id}');
    } catch (e) {
      logger.e('Error deleting entry: $e');
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting journal entry')),
        );
      }
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
        .collection('journals')
        .doc(entry.id)
        .update({'isFavorite': _entries[index].isFavorite})
        .then((_) => logger.i('Updated favorite status for entry ID: ${entry.id}'))
        .catchError((e) => logger.e('Error updating favorite status: $e'));
  }

  Future<void> _updateTagInAllJournals(String tagId, String newTagName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();

      final journalsSnapshot = await FirebaseFirestore.instance
          .collection('journals')
          .where('userId', isEqualTo: user.uid)
          .where('tagId', isEqualTo: tagId)
          .get();

      for (var doc in journalsSnapshot.docs) {
        batch.update(doc.reference, {'tagName': newTagName});
      }

      await batch.commit();
      logger.i('Updated tag name in ${journalsSnapshot.docs.length} journal entries');
    } catch (e) {
      logger.e('Error updating tag in journals: $e');
    }
  }

  Future<void> _handleTagDeletion(String tagId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();

      final journalsSnapshot = await FirebaseFirestore.instance
          .collection('journals')
          .where('userId', isEqualTo: user.uid)
          .where('tagId', isEqualTo: tagId)
          .get();

      for (var doc in journalsSnapshot.docs) {
        batch.update(doc.reference, {
          'tagId': null,
          'tagName': 'Not specified'
        });
      }

      await batch.commit();

      await FirebaseFirestore.instance.collection('tags').doc(tagId).delete();

      logger.i('Deleted tag and updated ${journalsSnapshot.docs.length} journal entries');
    } catch (e) {
      logger.e('Error handling tag deletion: $e');
    }
  }



  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    final int oldNavIndex = _selectedIndex;
    setState(() {
      _selectedIndex = index;
    });

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const HomePage();
        break;
      case 1:
        nextPage = const CoursesPage();
        break;
      case 2:
        nextPage = const MyEnrolledClasses();
        break;
      case 3:
        return;
      case 4:
        nextPage = const ProgressTrackerPage();
        break;
      case 5:
        nextPage = const ProfilePage();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      _createSlidingPageRoute(
        page: nextPage,
        newIndex: index,
        oldIndex: oldNavIndex,
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0078D4),
              ),
            )
          : Navigator(
              initialRoute: '/mood-selection',
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/mood-selection':
                  return MaterialPageRoute(
                    builder: (context) => MoodSelectionPage(
                      onMoodSelected: (mood, tagId, tagName) {
                        logger.i('MoodSelectionPage callback - mood: $mood, tagId: $tagId, tagName: $tagName');
                        Navigator.of(context).pushNamed(
                          '/journal-writing',
                          arguments: {
                            'mood': mood,
                            'tagId': tagId,
                            'tagName': tagName,
                            'entries': _entries,
                            'addEntry': _addEntry,
                            'updateEntry': _updateEntry,
                            'deleteEntry': _deleteEntry,
                            'toggleFavorite': _toggleFavorite,
                          },
                        );
                      },
                      onTagUpdated: _updateTagInAllJournals,
                      onTagDeleted: _handleTagDeletion,
                    ),
                  );

                  case '/journal-writing':
                  final args = settings.arguments as Map<String, dynamic>?;
                  if (args == null ||
                      !args.containsKey('mood') ||
                      !args.containsKey('tagId') ||
                      !args.containsKey('tagName') ||
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
                  final tagId = args['tagId'] as String?;
                  final tagName = args['tagName'] as String?;
                  if (mood == null || (tagId == null && tagName == null)) {
                    logger.w('Navigating to JournalWritingPage with null mood or tag: mood=$mood, tagId=$tagId, tagName=$tagName');
                  } else {
                    logger.i('Navigating to JournalWritingPage with args: mood=$mood, tagId=$tagId, tagName=$tagName');
                  }
                  return MaterialPageRoute(
                    builder: (context) => JournalWritingPage(
                      mood: mood,
                      tagId: tagId,
                      tagName: tagName,
                      entries: args['entries'] as List<JournalEntry>,
                      addEntry: (entry) => (args['addEntry'] as Function(JournalEntry))(entry),
                      updateEntry: (index, entry) => (args['updateEntry'] as Function(int, JournalEntry))(index, entry),
                      deleteEntry: (index) => (args['deleteEntry'] as Function(int))(index),
                      toggleFavorite: (index) => (args['toggleFavorite'] as Function(int))(index),
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
                        onUpdateEntry: _updateEntry,
                      ),
                    );

                  default:
                    return MaterialPageRoute(
                      builder: (context) => const Scaffold(
                        body: Center(child: Text('Page not found within Journal')),
                      ),
                    );
                }
              },
            ),
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          CustomBottomNavItem(icon: Icons.home, label: 'Home'),
          CustomBottomNavItem(icon: Icons.book, label: 'Courses'),
          CustomBottomNavItem(icon: Icons.school, label: 'My Classes'),
          CustomBottomNavItem(icon: Icons.library_books, label: 'Journal'),
          CustomBottomNavItem(icon: Icons.trending_up, label: 'Progress'),
          CustomBottomNavItem(icon: Icons.person, label: 'Profile'),
        ],
        activeColor: Colors.white,
        inactiveColor: Colors.grey[600]!,
        notchColor: Colors.blue,
        backgroundColor: Colors.white,
        selectedIconSize: 28.0,
        iconSize: 25.0,
        barHeight: 55,
        selectedIconPadding: 10,
        animationDuration: const Duration(milliseconds: 300),
        customNotchWidthFactor: 1.8,
      ),
    );
  }
}