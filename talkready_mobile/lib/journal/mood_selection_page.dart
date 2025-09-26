import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MoodSelectionPage extends StatefulWidget {
 final Function(String?, String?, String?) onMoodSelected;

  const MoodSelectionPage({super.key, required this.onMoodSelected});

  @override
  State<MoodSelectionPage> createState() => _MoodSelectionPageState();
}

class _MoodSelectionPageState extends State<MoodSelectionPage> {
  final Logger logger = Logger();
  String? selectedMood;
  String? selectedTag;
  List<Map<String, dynamic>> tags = [
    {'name': 'Personal', 'iconCodePoint': '58944'}, // Icons.person
    {'name': 'Work', 'iconCodePoint': '59475'}, // Icons.work
    {'name': 'Travel', 'iconCodePoint': '59126'}, // Icons.flight
    {'name': 'Study', 'iconCodePoint': '58394'}, // Icons.book
    {'name': 'Food', 'iconCodePoint': '59522'}, // Icons.restaurant
    {'name': 'Plant', 'iconCodePoint': '59330'}, // Icons.local_florist
  ];
  bool _isLoadingTags = true;

  final List<Map<String, String>> moods = [
    {'name': 'Rad', 'emoji': '😊'},
    {'name': 'Happy', 'emoji': '😄'},
    {'name': 'Meh', 'emoji': '😐'},
    {'name': 'Sad', 'emoji': '😢'},
    {'name': 'Angry', 'emoji': '😠'},
  ];

  late Future<String> _userNameFuture;

  @override
  void initState() {
    super.initState();
    _userNameFuture = _fetchUserName();
    _loadTags();
  }

 Future<void> _loadTags() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.w('No authenticated user found for loading tags');
        setState(() {
          _isLoadingTags = false;
        });
        return;
      }

      // Default tags with proper IDs
      List<Map<String, dynamic>> defaultTags = [
        {'id': 'default_personal', 'name': 'Personal', 'iconCodePoint': '58944'},
        {'id': 'default_work', 'name': 'Work', 'iconCodePoint': '59475'},
        {'id': 'default_travel', 'name': 'Travel', 'iconCodePoint': '59126'},
        {'id': 'default_study', 'name': 'Study', 'iconCodePoint': '58394'},
        {'id': 'default_food', 'name': 'Food', 'iconCodePoint': '59522'},
        {'id': 'default_plant', 'name': 'Plant', 'iconCodePoint': '59330'},
      ];

      // Load custom tags from Firestore (consistent with journal_page.dart)
      final snapshot = await FirebaseFirestore.instance
          .collection('tags')
          .where('userId', isEqualTo: user.uid)
          .get();

      final customTags = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,  // Include document ID
          'name': data['name'] as String,
          'iconCodePoint': data['iconCodePoint'] as String,
        };
      }).toList();

      if (mounted) {
        setState(() {
          tags = [...defaultTags, ...customTags];
          _isLoadingTags = false;
        });
      }
      logger.i('Loaded ${customTags.length} custom tags from Firestore. Total tags: ${tags.length}');
    } catch (e) {
      logger.e('Error loading tags: $e');
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading tags')),
        );
      }
    }
  }

 Future<void> _addCustomTag(String name, IconData icon) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.w('No authenticated user found for adding custom tag');
        return;
      }

      final iconCodePoint = icon.codePoint.toString();

      // Store in the main tags collection (consistent with journal_page.dart)
      final docRef = await FirebaseFirestore.instance
          .collection('tags')
          .add({
        'name': name,
        'iconCodePoint': iconCodePoint,
        'userId': user.uid,
      });

      if (mounted) {
        setState(() {
          // Avoid adding duplicate tag if it somehow got added by another means
          if (!tags.any((tag) => tag['name'] == name)) {
            tags.add({
              'id': docRef.id,  // Store the document ID
              'name': name,
              'iconCodePoint': iconCodePoint,
            });
          }
          selectedTag = name; // Automatically select the newly added tag
        });
      }
      logger.i('Added custom tag: $name with ID: ${docRef.id} and iconCodePoint: $iconCodePoint');
    } catch (e) {
      logger.e('Error adding custom tag: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error adding custom tag')),
        );
      }
    }
  }

  Future<String> _fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.w('No authenticated user found');
        return 'User'; // Default name
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Corrected: Access firstName directly from the document data
      final firstName = doc.data()?['firstName'] as String?;

      if (firstName == null || firstName.isEmpty) {
        logger.w('First name not found in Firestore or is empty');
        return 'User'; // Default if not found or empty
      }

      logger.i('Fetched first name: $firstName');
      return firstName;
    } catch (e) {
      logger.e('Error fetching first name: $e');
      return 'User'; // Consistent default on error
    }
  }

 void _navigateToJournalWriting(String? mood, String? tagId, String? tagName) {
  logger.i('Navigating to JournalWritingPage with mood: $mood, tagId: $tagId, tagName: $tagName');
  widget.onMoodSelected(mood, tagId, tagName);
}

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTags) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00568D).withOpacity(0.1),
              Colors.white,
              const Color(0xFFE0FFD6).withOpacity(0.3),
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
                    mainAxisAlignment: MainAxisAlignment.end, // Align "Skip" to the right
                    children: [
                      Flexible(
                        child: SizedBox(
                          width: 80,
                          child: TextButton(
                            onPressed: () {
                              logger.i('Skip button pressed, navigating with no mood or tag');
                              _navigateToJournalWriting(null, null, null);
                            },
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF00568D),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF00568D),
                              ),
                            ),
                          ),
                        ),
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
                      border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
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
                        FutureBuilder<String>(
                          future: _userNameFuture,
                          builder: (context, snapshot) {
                            String greetingName = 'User'; // Default greeting name

                            if (snapshot.connectionState == ConnectionState.done) {
                              if (snapshot.hasError) {
                                logger.e('Error in FutureBuilder fetching user name: ${snapshot.error}');
                                // greetingName remains 'User' (or the default from _fetchUserName)
                              } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                greetingName = snapshot.data!;
                              }
                              // If data is null or empty, _fetchUserName should have returned 'User'
                            }
                            // While waiting, it will use the default 'User'

                            return Text(
                              'Hi, $greetingName! How are you feeling today?',
                              style: const TextStyle(
                                fontSize: 24,
                                color: Color(0xFF00568D),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: moods.map((mood) {
                            bool isSelected = selectedMood == mood['name'];
                            return ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(mood['emoji']!, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 5),
                                  Text(mood['name']!, style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF00568D).withOpacity(0.5),
                              backgroundColor: Colors.white.withOpacity(0.8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(color: const Color(0xFF00568D).withOpacity(0.2)),
                              ),
                              elevation: 2,
                              onSelected: (selected) {
                                setState(() {
                                  selectedMood = selected ? mood['name'] : null;
                                  logger.i('Selected mood: $selectedMood');
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE0FFD6).withOpacity(0.5),
                          const Color(0xFFFFF0C3).withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
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
                        const Text(
                          'Choose a tag for the entry!',
                          style: TextStyle(
                            fontSize: 24,
                            color: Color(0xFF00568D),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ...tags.map((tag) {
                              bool isSelected = selectedTag == tag['name'];
                              int? codePoint;
                              try {
                                codePoint = int.parse(tag['iconCodePoint']);
                              } catch (e) {
                                logger.e('Invalid iconCodePoint for tag ${tag['name']}: ${tag['iconCodePoint']}');
                                codePoint = Icons.tag.codePoint; // Default icon
                              }
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                     IconData(codePoint, fontFamily: 'MaterialIcons'),
                                      size: 20,
                                      color: isSelected ? const Color(0xFF00568D) : Colors.grey,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      tag['name']!,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFF00568D).withOpacity(0.5),
                                backgroundColor: Colors.white.withOpacity(0.8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(color: const Color(0xFF00568D).withOpacity(0.2)),
                                ),
                                elevation: 2,
                                onSelected: (selected) {
                                  setState(() {
                                    selectedTag = selected ? tag['name'] : null;
                                    logger.i('Selected tag: $selectedTag');
                                  });
                                },
                              );
                            }),
                            ActionChip(
                              label: const Text('Add your own tag!', style: TextStyle(fontSize: 16)),
                              backgroundColor: Colors.white.withOpacity(0.8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(color: const Color(0xFF00568D).withOpacity(0.2)),
                              ),
                              elevation: 2,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                   String? customTagName; // Renamed to avoid conflict
                                   IconData selectedIcon = Icons.tag;
                                    return Dialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      child: Container(
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
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFF00568D).withOpacity(0.2)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: StatefulBuilder(
                                          builder: (context, setDialogState) {
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Add Custom Tag',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    color: Color(0xFF00568D),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                TextField(
                                                  onChanged: (value) {
                                                    customTagName = value;
                                                  },
                                                  decoration: InputDecoration(
                                                    hintText: 'Enter tag name',
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: const BorderSide(color: Color(0xFF00568D)),
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                const Text(
                                                  'Choose an icon',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF00568D),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: [
                                                    Icons.tag,
                                                    Icons.star,
                                                    Icons.favorite,
                                                    Icons.bookmark,
                                                    Icons.music_note,
                                                    Icons.sports_soccer, // Example: changed from Icons.sports
                                                    Icons.restaurant, // Example: changed from Icons.local_dining
                                                    Icons.pets,
                                                  ].map((icon) {
                                                    bool isSelected = selectedIcon == icon;
                                                    return ChoiceChip(
                                                      label: Icon(
                                                        icon,
                                                        color: isSelected ? const Color(0xFF00568D) : Colors.grey,
                                                        size: 24,
                                                      ),
                                                      selected: isSelected,
                                                      selectedColor: const Color(0xFF00568D).withOpacity(0.5),
                                                      backgroundColor: Colors.white.withOpacity(0.8),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(15),
                                                        side: BorderSide(color: const Color(0xFF00568D).withOpacity(0.2)),
                                                      ),
                                                      elevation: 2,
                                                      onSelected: (selected) {
                                                        setDialogState(() {
                                                          selectedIcon = icon;
                                                        });
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                                const SizedBox(height: 20),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                      child: Container(
                                                        decoration: BoxDecoration(
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
                                                          onPressed: () => Navigator.pop(context),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.grey.shade300,
                                                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(15),
                                                            ),
                                                          ),
                                                          child: const Text(
                                                            'Cancel',
                                                            style: TextStyle(fontSize: 16, color: Colors.black),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 20),
                                                    Flexible(
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          gradient: const LinearGradient(
                                                            colors: [
                                                              Color(0xFF00568D),
                                                              Color(0xFF003F6A),
                                                            ],
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
                                                          onPressed: () {
                                                            if (customTagName != null && customTagName!.isNotEmpty) {
                                                              _addCustomTag(customTagName!, selectedIcon);
                                                              // No need to call setState here for selectedTag,
                                                              // _addCustomTag already handles it if mounted.
                                                            }
                                                            Navigator.pop(context);
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.transparent,
                                                            shadowColor: Colors.transparent,
                                                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(15),
                                                            ),
                                                          ),
                                                          child: const Text(
                                                            'Add',
                                                            style: TextStyle(fontSize: 16, color: Colors.white),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: (selectedMood != null && selectedTag != null)
                              ? [
                                  const Color(0xFF00568D),
                                  const Color(0xFF003F6A),
                                ]
                              : [
                                  Colors.grey.shade400,
                                  Colors.grey.shade600,
                                ],
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
                        onPressed: selectedMood != null && selectedTag != null
                            ? () {
                                logger.i('Continue button pressed with mood: $selectedMood, tag: $selectedTag');
                                // Find the selected tag's ID from the tags list
                                String? selectedTagId;
                                if (selectedTag != null) {
                                  final tag = tags.firstWhere((t) => t['name'] == selectedTag);
                                  selectedTagId = tag['id']; // Use the actual tag ID
                                }
                                _navigateToJournalWriting(selectedMood!, selectedTagId, selectedTag!);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          disabledForegroundColor: Colors.white.withOpacity(0.7),
                          disabledBackgroundColor: Colors.transparent, // Keep gradient for disabled state
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}