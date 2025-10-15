// enhanced_mood_selection_page.dart
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class MoodSelectionPage extends StatefulWidget {
  final Function(String?, String?, String?) onMoodSelected;
  final Function(String, String)? onTagUpdated;
  final Function(String)? onTagDeleted;

  const MoodSelectionPage({
    super.key,
    required this.onMoodSelected,
    this.onTagUpdated,
    this.onTagDeleted,
  });

  @override
  State<MoodSelectionPage> createState() => _MoodSelectionPageState();
}

class _MoodSelectionPageState extends State<MoodSelectionPage> {
  final Logger logger = Logger();
  String? selectedMood;
  String? selectedTag;
  List<Map<String, dynamic>> tags = [];
  bool _isLoadingTags = true;
  bool _showTooltip = true;

  // --- ADD THIS STATIC CONST LIST HERE ---
  static const List<Map<String, dynamic>> _defaultTags = [
    {
      'id': 'default_personal',
      'name': 'Personal',
      'icon': Icons.person_outline,
      'isDefault': true,
    },
    {
      'id': 'default_work',
      'name': 'Work',
      'icon': Icons.work_outline,
      'isDefault': true,
    },
    {
      'id': 'default_travel',
      'name': 'Travel',
      'icon': Icons.flight_takeoff,
      'isDefault': true,
    },
    {
      'id': 'default_study',
      'name': 'Study',
      'icon': Icons.school_outlined,
      'isDefault': true,
    },
    {
      'id': 'default_food',
      'name': 'Food',
      'icon': Icons.restaurant_outlined,
      'isDefault': true,
    },
    {
      'id': 'default_plant',
      'name': 'Plant',
      'icon': Icons.eco_outlined,
      'isDefault': true,
    },
  ];
  // ---------------------------------------

  final List<Map<String, dynamic>> moods = [
    {
      'name': 'Rad',
      'emoji': '😎',
      'gradient': [Color(0xFF0078D4), Color(0xFF005A9E)],
    },
    {
      'name': 'Happy',
      'emoji': '😄',
      'gradient': [Color(0xFF50E6FF), Color(0xFF0099BC)],
    },
    {
      'name': 'Meh',
      'emoji': '😐',
      'gradient': [Color(0xFF8A8886), Color(0xFF605E5C)],
    },
    {
      'name': 'Sad',
      'emoji': '😢',
      'gradient': [Color(0xFF4F6BED), Color(0xFF3B5998)],
    },
    {
      'name': 'Angry',
      'emoji': '😠',
      'gradient': [Color(0xFFE74856), Color(0xFFC4314B)],
    },
  ];

  late Future<String> _userNameFuture;

IconData _getIconFromCodePoint(int codePoint) {
  // Map of all available icon codePoints to their IconData
  final iconMap = {
    Icons.favorite_outline.codePoint: Icons.favorite_outline,
    Icons.star_outline.codePoint: Icons.star_outline,
    Icons.wb_sunny_outlined.codePoint: Icons.wb_sunny_outlined,
    Icons.nightlight_outlined.codePoint: Icons.nightlight_outlined,
    Icons.fitness_center.codePoint: Icons.fitness_center,
    Icons.palette_outlined.codePoint: Icons.palette_outlined,
    Icons.music_note_outlined.codePoint: Icons.music_note_outlined,
    Icons.camera_alt_outlined.codePoint: Icons.camera_alt_outlined,
    Icons.label_outline.codePoint: Icons.label_outline,
  };
  return iconMap[codePoint] ?? Icons.label_outline;
}
  @override
  void initState() {
    super.initState();
    _userNameFuture = _fetchUserName();
    _loadTags();

    // Show tooltip for 5 seconds on first load
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showTooltip = false);
      }
    });
  }

  Future<void> _loadTags() async {
  setState(() => _isLoadingTags = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingTags = false);
      return;
    }

    final List<Map<String, dynamic>> defaultTags = _defaultTags;

    final snapshot = await FirebaseFirestore.instance
        .collection('tags')
        .where('userId', isEqualTo: user.uid)
        .get();

    final customTags = snapshot.docs.map((doc) {
      final data = doc.data();
      int codePoint;
      try {
        codePoint = int.parse(data['iconCodePoint'] as String);
      } catch (e) {
        codePoint = Icons.label_outline.codePoint;
      }

      // ✅ FIX: Use helper to get constant IconData
      IconData icon = _getIconFromCodePoint(codePoint);

      return {
        'id': doc.id,
        'name': data['name'] as String,
        'icon': icon,
        'isDefault': false,
      };
    }).toList();

    if (mounted) {
      setState(() {
        tags = [...defaultTags, ...customTags];
        _isLoadingTags = false;
      });
    }
  } catch (e) {
    logger.e('Error loading tags: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to load tags: ${e.toString()}')),
            ],
          ),
          backgroundColor: const Color(0xFFE74856),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> _addCustomTag(String name, IconData icon) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = await FirebaseFirestore.instance.collection('tags').add({
      'name': name,
      'iconCodePoint': icon.codePoint.toString(),
      'userId': user.uid,
    });

    if (mounted) {
      setState(() {
        // ✅ FIX: Convert to constant IconData
        final constantIcon = _getIconFromCodePoint(icon.codePoint);
        tags.add({
          'id': docRef.id,
          'name': name,
          'icon': constantIcon,
          'isDefault': false,
        });
        selectedTag = name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Tag "$name" created successfully')),
            ],
          ),
          backgroundColor: const Color(0xFF10893E),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    logger.e('Error adding custom tag: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to create tag: ${e.toString()}')),
            ],
          ),
          backgroundColor: const Color(0xFFE74856),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

 Future<void> _editCustomTag(
  String tagId,
  String oldName,
  String newName,
  IconData newIcon,
) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('tags').doc(tagId).update({
      'name': newName,
      'iconCodePoint': newIcon.codePoint.toString(),
    });

    if (mounted) {
      setState(() {
        final index = tags.indexWhere((t) => t['id'] == tagId);
        if (index != -1) {
          // ✅ FIX: Convert to constant IconData
          final constantIcon = _getIconFromCodePoint(newIcon.codePoint);
          tags[index]['name'] = newName;
          tags[index]['icon'] = constantIcon;
          if (selectedTag == oldName) {
            selectedTag = newName;
          }
        }
      });
    }

    // Update all journal entries with this tag
    if (widget.onTagUpdated != null) {
      await widget.onTagUpdated!(tagId, newName);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Tag updated successfully')),
            ],
          ),
          backgroundColor: const Color(0xFF10893E),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    logger.e('Error editing custom tag: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to update tag: ${e.toString()}')),
            ],
          ),
          backgroundColor: const Color(0xFFE74856),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

  Future<void> _deleteCustomTag(String tagId, String tagName) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Delete Tag',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete "$tagName"? Journal entries using this tag will be updated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF605E5C)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFE74856)),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      if (mounted) {
        setState(() {
          tags.removeWhere((t) => t['id'] == tagId);
          if (selectedTag == tagName) {
            selectedTag = null;
          }
        });
      }

      // Handle deletion in Firestore and update affected journals
      if (widget.onTagDeleted != null) {
        await widget.onTagDeleted!(tagId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Tag deleted successfully')),
              ],
            ),
            backgroundColor: const Color(0xFF10893E),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      logger.e('Error deleting custom tag: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to delete tag: ${e.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFE74856),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String> _fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'there';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final firstName = doc.data()?['firstName'] as String?;
      return firstName?.isNotEmpty == true ? firstName! : 'there';
    } catch (e) {
      logger.e('Error fetching user name: $e');
      return 'there';
    }
  }

  void _navigateToJournalWriting(String? mood, String? tagId, String? tagName) {
    widget.onMoodSelected(mood, tagId, tagName);
  }

  void _showAddTagDialog() {
    String? customTagName;
    IconData selectedIcon = Icons.label_outline;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final availableIcons = [
                Icons.favorite_outline,
                Icons.star_outline,
                Icons.wb_sunny_outlined,
                Icons.nightlight_outlined,
                Icons.fitness_center,
                Icons.palette_outlined,
                Icons.music_note_outlined,
                Icons.camera_alt_outlined,
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create new tag',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF252423),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                  onChanged: (value) => customTagName = value,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: 'Tag name',
                    labelStyle: const TextStyle(color: Color(0xFF605E5C)),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    counterText: '',
                  ),
                ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select icon',
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
                    children: availableIcons.map((icon) {
                      final isSelected = selectedIcon.codePoint == icon.codePoint;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0078D4)
                                : const Color(0xFFF3F2F1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0078D4)
                                  : const Color(0xFFEDEBE9),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF605E5C),
                            size: 20,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
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
                      const SizedBox(width: 8),
                      ElevatedButton(
                      onPressed: () {
                        final trimmedName = customTagName?.trim();

                        // Validation
                        if (trimmedName == null || trimmedName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.white),
                                  const SizedBox(width: 12),
                                  const Expanded(child: Text('Tag name cannot be empty')),
                                ],
                              ),
                              backgroundColor: const Color(0xFFE74856),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        // Check for duplicate names
                        final isDuplicate = tags.any(
                          (tag) => (tag['name'] as String).toLowerCase() ==
                                  trimmedName.toLowerCase()
                        );

                        if (isDuplicate) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.white),
                                  const SizedBox(width: 12),
                                  const Expanded(child: Text('A tag with this name already exists')),
                                ],
                              ),
                              backgroundColor: const Color(0xFFE74856),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        _addCustomTag(trimmedName, selectedIcon);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0078D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEditTagDialog(
    String tagId,
    String currentName,
    IconData currentIcon,
  ) {
    String? newTagName = currentName;
    IconData selectedIcon = currentIcon;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final availableIcons = [
                Icons.favorite_outline,
                Icons.star_outline,
                Icons.wb_sunny_outlined,
                Icons.nightlight_outlined,
                Icons.fitness_center,
                Icons.palette_outlined,
                Icons.music_note_outlined,
                Icons.camera_alt_outlined,
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit tag',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF252423),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                  controller: TextEditingController(text: currentName),
                  onChanged: (value) => newTagName = value,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: 'Tag name',
                    labelStyle: const TextStyle(color: Color(0xFF605E5C)),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    counterText: '',
                  ),
                ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select icon',
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
                    children: availableIcons.map((icon) {
                      final isSelected = selectedIcon.codePoint == icon.codePoint;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0078D4)
                                : const Color(0xFFF3F2F1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0078D4)
                                  : const Color(0xFFEDEBE9),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF605E5C),
                            size: 20,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
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
                      const SizedBox(width: 8),
                     ElevatedButton(
                      onPressed: () {
                        final trimmedName = newTagName?.trim();

                        // Validation
                        if (trimmedName == null || trimmedName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.white),
                                  const SizedBox(width: 12),
                                  const Expanded(child: Text('Tag name cannot be empty')),
                                ],
                              ),
                              backgroundColor: const Color(0xFFE74856),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        // Check for duplicate names (excluding current tag)
                        final isDuplicate = tags.any(
                          (tag) => tag['id'] != tagId &&
                                  (tag['name'] as String).toLowerCase() ==
                                  trimmedName.toLowerCase()
                        );

                        if (isDuplicate) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.white),
                                  const SizedBox(width: 12),
                                  const Expanded(child: Text('A tag with this name already exists')),
                                ],
                              ),
                              backgroundColor: const Color(0xFFE74856),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        _editCustomTag(tagId, currentName, trimmedName, selectedIcon);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0078D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarWithLogo() {
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0078D4),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Image.asset('images/TR Logo.png', height: 40, width: 40),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Journal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _navigateToJournalWriting(null, null, null),
            child: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTags) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0078D4)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBarWithLogo(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  FutureBuilder<String>(
                    future: _userNameFuture,
                    builder: (context, snapshot) {
                      final name = snapshot.data ?? 'there';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, $name',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF252423),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'How are you feeling today?',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF605E5C),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Mood Selection
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: moods.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final mood = moods[index];
                      final isSelected = selectedMood == mood['name'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedMood = isSelected
                                ? null
                                : mood['name'] as String;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 72,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: mood['gradient'] as List<Color>,
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  )
                                : null,
                            color: isSelected ? null : const Color(0xFFF3F2F1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : const Color(0xFFEDEBE9),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                mood['emoji'] as String,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  mood['name'] as String,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF252423),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),

                  // Category Selection
                  const Text(
                    'Select a category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF252423),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tooltip
                  if (_showTooltip)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0078D4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0078D4).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFF0078D4),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Long press custom tags to edit or delete',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0078D4),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _showTooltip = false),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFF0078D4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Tags List
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ...tags.map((tag) {
                        final isSelected = selectedTag == tag['name'];
                        final isDefault = tag['isDefault'] == true;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              selectedTag = isSelected
                                  ? null
                                  : tag['name'] as String;
                            });
                          },
                          onLongPress: !isDefault
                              ? () {
                                  HapticFeedback.mediumImpact();
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (context) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.edit,
                                              color: Color(0xFF0078D4),
                                            ),
                                            title: const Text('Edit Tag'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _showEditTagDialog(
                                                tag['id'] as String,
                                                tag['name'] as String,
                                                tag['icon'] as IconData,
                                              );
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.delete,
                                              color: Color(0xFFE74856),
                                            ),
                                            title: const Text('Delete Tag'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _deleteCustomTag(
                                                tag['id'] as String,
                                                tag['name'] as String,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0078D4)
                                  : const Color(0xFFF3F2F1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0078D4)
                                    : const Color(0xFFEDEBE9),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tag['icon'] as IconData,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF605E5C),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tag['name'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF252423),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      InkWell(
                        onTap: _showAddTagDialog,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF0078D4),
                              width: 1.5,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 18,
                                color: Color(0xFF0078D4),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add new',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0078D4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: const Color(0xFFEDEBE9), width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedMood != null && selectedTag != null
                    ? () {
                        String? selectedTagId;
                        if (selectedTag != null) {
                          final tag = tags.firstWhere(
                            (t) => t['name'] == selectedTag,
                          );
                          selectedTagId = tag['id'] as String;
                        }
                        _navigateToJournalWriting(
                          selectedMood!,
                          selectedTagId,
                          selectedTag!,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0078D4),
                  disabledBackgroundColor: const Color(0xFFF3F2F1),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF8A8886),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
