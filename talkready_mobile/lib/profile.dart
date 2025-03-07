import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For user authentication
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore database
import 'package:image/image.dart' as img; // For base64 decoding
import 'package:image_picker/image_picker.dart'; // For compatibility (not used here, but kept for consistency)
import 'package:logger/logger.dart'; // For logging
import 'courses_page.dart';
import 'journal_page.dart';
import 'homepage.dart'; // Assume this exists
import 'ai_bot.dart'; // Assume this exists

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker =
      ImagePicker(); // For image picking (optional, kept for consistency)
  late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
      _userStreamSubscription; // Use Subscription for explicit control
  bool _isLoading = true; // Loading state for Firebase data

  final Logger _logger = Logger(); // Initialize Logger

  String? _name; // Will be fetched dynamically (userName from onboarding)
  String? _email; // Will be fetched from FirebaseAuth if available
  String? _englishLevel;
  String? _dailyPracticeGoal;
  String? _currentGoal;
  String? _learningPreference;
  String? _desiredAccent;
  String? _profilePicBase64; // Store base64 string from Firestore
  bool? _profilePicSkipped;

  int _selectedIndex =
      4; // Default to Profile (index 4) since this is ProfilePage

  @override
  void initState() {
    super.initState();
    _setupUserStream(); // Set up real-time listener for user data
    _fetchEmail(); // Fetch email from FirebaseAuth
  }

  void _fetchEmail() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email; // Fetch email from Firebase Authentication
      });
    }
  }

  void _setupUserStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _logger.i('Setting up stream for user UID: ${user.uid}'); // Info log
      _userStreamSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots() // Fetch the users document directly
          .listen(
        (snapshot) {
          _logger
              .i('Received Firestore snapshot: ${snapshot.data}'); // Info log
          if (snapshot.exists) {
            final data = snapshot.data() ?? {}; // Handle null data
            final onboardingData =
                data['onboarding'] as Map<String, dynamic>? ??
                    {}; // Extract onboarding data
            _logger.d(
                'Parsed Firestore onboarding data: $onboardingData'); // Debug log for detailed data inspection
            setState(() {
              _name = onboardingData['userName'];
              _englishLevel = onboardingData['englishLevel'];
              _dailyPracticeGoal = onboardingData['dailyPracticeGoal'];
              _currentGoal = onboardingData['currentGoal'];
              _learningPreference = onboardingData['learningPreference'];
              _desiredAccent = onboardingData['desiredAccent'];
              _profilePicBase64 = onboardingData['profilePicBase64']
                  as String?; // Fetch base64 string
              _profilePicSkipped = onboardingData['profilePicSkipped'] as bool?;
              _isLoading = false;
            });
          } else {
            _logger.w(
                'No Firestore document exists for UID: ${user.uid}'); // Warning log
            setState(() {
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          _logger.e('Error in Firestore stream: $error'); // Error log
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error listening to user data: $error')),
          );
        },
      );
    } else {
      _logger.w('No authenticated user found'); // Warning log
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in')),
      );
    }
  }

  void _showEditNameDialog() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController =
            TextEditingController(text: _name ?? '');
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter your name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    _name = nameController.text;
                  });
                  _saveNameToFirestore(
                      nameController.text); // Save updated name to Firestore
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveNameToFirestore(String newName) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _logger.i('Saving name to Firestore for UID: ${user.uid}'); // Info log
        await _firestore.collection('users').doc(user.uid).update({
          'onboarding.userName':
              newName, // Update the userName within the onboarding map
        });
      }
    } catch (e) {
      _logger.e('Error saving name: $e'); // Error log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving name: $e')),
      );
    }
  }

  void _showDropdownDialog(
      String title,
      List<String> items,
      String? currentValue,
      void Function(String?) onChanged,
      String firestoreField) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(items[index]), // Handle null values
                  onTap: () {
                    onChanged(items[index]);
                    _saveProfileOptionToFirestore(firestoreField,
                        items[index]); // Save updated value to Firestore
                    Navigator.pop(context);
                  },
                  selected: currentValue == items[index],
                  selectedTileColor: Colors.lightBlue[100]?.withOpacity(0.2),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfileOptionToFirestore(String field, String value) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _logger
            .i('Saving $field to Firestore for UID: ${user.uid}'); // Info log
        await _firestore.collection('users').doc(user.uid).update({
          'onboarding.$field':
              value, // Update the field within the onboarding map
        });
      }
    } catch (e) {
      _logger.e('Error saving $field: $e'); // Error log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving $field: $e')),
      );
    }
  }

  Future<void> _pickAndUploadProfilePic() async {
    try {
      final pickedFile = await _picker.pickImage(
          source: ImageSource
              .gallery); // Pick image from gallery (or use camera: ImageSource.camera)
      if (pickedFile != null) {
        setState(() {
          _isLoading = true;
        });

        final user = _auth.currentUser;
        if (user != null) {
          final file = File(pickedFile.path);
          final imageBytes = await file.readAsBytes();
          final image = img.decodeImage(imageBytes)!;
          final resizedImage = img.copyResize(image,
              width: 200); // Resize to reduce size (optional)
          final base64Image = img.encodePng(
              resizedImage); // Encode as PNG (or JPEG for smaller size)
          if (base64Image.length > 1000000) {
            // 1 MB limit
            _logger.e('Profile picture too large for Firestore (exceeds 1 MB)');
            throw Exception(
                'Profile picture is too large to store in Firestore');
          }
          final profilePicBase64 = base64Encode(base64Image);

          await _firestore.collection('users').doc(user.uid).update({
            'onboarding.profilePicBase64':
                profilePicBase64, // Save the base64 string in Firestore
            'onboarding.profilePicSkipped':
                false, // Indicate a profile picture was uploaded
          });

          setState(() {
            _profilePicBase64 = profilePicBase64;
            _profilePicSkipped = false;
            _isLoading = false;
          });

          setState(() {
            _profilePicBase64 = profilePicBase64;
            _isLoading = false;
          });

          _logger.i('Profile picture saved as base64 for UID: ${user.uid}');
        }
      }
    } catch (e) {
      _logger.e('Error picking or uploading profile picture: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading profile picture: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Clean up the stream subscription to prevent memory leaks
    _userStreamSubscription.cancel(); // Explicitly cancel the subscription
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Prevent duplicate navigation

    setState(() {
      _selectedIndex = index;
    });

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const HomePage();
        break;
      case 1:
        nextPage = const AIBotScreen();
        break;
      case 2:
        nextPage = const CoursesPage();
        break;
      case 3:
        nextPage = const ProgressTrackerPage();
        break;
      case 4:
        return; // Already on Profile, do nothing
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00568D)))
          : Column(
              children: [
                // Combine AppBar and Profile Header into a single Container for seamless blue background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2973B2),
                        Color(0xFF618DB2)
                      ], // Gradient colors
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // AppBar-like section with settings icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: IconButton(
                                icon: const Icon(Icons.settings,
                                    color: Colors.white, size: 35),
                                onPressed: () {
                                  // Add settings action here
                                },
                              ),
                            ),
                          ],
                        ),
                        // Profile Picture and Name Section
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape
                                      .circle, // Ensure the container is circular
                                  border: Border.all(
                                    color: Color(0xFF9CA8C7),
                                    width: 4.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                          0.3), // Shadow color with opacity
                                      spreadRadius:
                                          2, // How far the shadow spreads
                                      blurRadius: 5, // How blurry the shadow is
                                      offset: const Offset(0,
                                          3), // Shadow position (horizontal, vertical)
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius:
                                      70, // Kept at 70 for larger avatar size
                                  backgroundImage: _profilePicBase64 != null
                                      ? MemoryImage(
                                              base64Decode(_profilePicBase64!))
                                          as ImageProvider
                                      : null, // Display base64-decoded image if available
                                  backgroundColor: _profilePicBase64 == null &&
                                          _profilePicSkipped == true
                                      ? null // No background color if skipped (person icon will handle this)
                                      : Colors.grey[
                                          300], // Grey placeholder if no image and not skipped
                                  child: _profilePicBase64 == null &&
                                          _profilePicSkipped == true
                                      ? Icon(Icons.person,
                                          size: 70,
                                          color: Colors.grey[
                                              600]) // Person icon if skipped
                                      : null, // No child if image exists or placeholder is used
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 10,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.blue.shade100,
                                child: IconButton(
                                  icon: Icon(Icons.add, color: Colors.blue),
                                  onPressed: _pickAndUploadProfilePic,
                                  padding: EdgeInsets.zero,
                                  iconSize: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_name != null) // Only show if name exists
                              Text(
                                _name!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            else
                              Text(
                                "User", // Fallback to "User" if _name is null
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.white, size: 20),
                              onPressed:
                                  _name != null ? _showEditNameDialog : null,
                            ),
                          ],
                        ),
                        if (_email !=
                            null) // Conditionally show email if available
                          Text(
                            _email!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        const SizedBox(
                            height: 20), // Space before the profile options
                      ],
                    ),
                  ),
                ),
                // Profile Options
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    children: [
                      _buildProfileOption(
                        title: 'Active Level',
                        value: _englishLevel,
                        onChanged: (value) {
                          setState(() {
                            _englishLevel = value;
                          });
                        },
                        items: const [
                          'Beginner A1',
                          'Lower Intermediate A2',
                          'Intermediate B1',
                          'Upper Intermediate B2',
                          'Advanced C'
                        ], // Matches onboarding options
                        firestoreField: 'englishLevel',
                      ),
                      _buildProfileOption(
                        title: 'Daily Practice Goal',
                        value: _dailyPracticeGoal,
                        onChanged: (value) {
                          setState(() {
                            _dailyPracticeGoal = value;
                          });
                        },
                        items: const [
                          '5 min/day',
                          '10 min/day',
                          '15 min/day',
                          '30 min/day',
                          '60 min/day'
                        ], // Matches onboarding options
                        firestoreField: 'dailyPracticeGoal',
                      ),
                      _buildProfileOption(
                        title: 'Current Goal',
                        value: _currentGoal,
                        onChanged: (value) {
                          setState(() {
                            _currentGoal = value;
                          });
                        },
                        items: const [
                          'Get ready for a job interview',
                          'Test my English Level',
                          'Improve my conversational English',
                          'Improve my English for Work'
                        ], // Matches onboarding options
                        firestoreField: 'currentGoal',
                      ),
                      _buildProfileOption(
                        title: 'Learning Preference',
                        value: _learningPreference,
                        onChanged: (value) {
                          setState(() {
                            _learningPreference = value;
                          });
                        },
                        items: const [
                          'Watching videos',
                          'Practicing with conversations',
                          'Reading and writing exercises',
                          'A mix of all'
                        ], // Matches onboarding options
                        firestoreField: 'learningPreference',
                      ),
                      _buildProfileOption(
                        title: 'Desired Accent',
                        value: _desiredAccent,
                        onChanged:
                            null, // Pass null for Desired Accent to make it non-clickable
                        items: const [
                          'Neutral',
                          'American 🇺🇸',
                          'British 🇬🇧',
                          'Australian 🇮🇦'
                        ], // Matches onboarding options
                        firestoreField: 'desiredAccent',
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00568D),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex, // Bind the selected index
        onTap: _onItemTapped, // Handle tab taps
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chatbot'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Courses'),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_books), label: 'Journal'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required String title,
    required String? value,
    required void Function(String?)? onChanged,
    required List<String> items,
    required String firestoreField,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.lightBlue[100]?.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title section with emoji
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_getEmojiForTitle(title)} ',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF00568D),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF00568D),
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),

            // Value section with arrow
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (value != null)
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (title != 'Desired Accent') const SizedBox(width: 8),

                  // Clickable Arrow
                  if (title != 'Desired Accent')
                    InkWell(
                      onTap: onChanged != null && value != null
                          ? () {
                              _showDropdownDialog(title, items, value,
                                  onChanged, firestoreField);
                            }
                          : null,
                      child: IconTheme(
                        data: IconThemeData(
                            size: 22), // Increase size slightly for bold effect
                        child: const Icon(Icons.arrow_forward_ios,
                            color: Color(0xFF2973B2)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmojiForTitle(String title) {
    switch (title) {
      case 'Active Level':
        return '🚀'; // Rocket for progress/level
      case 'Daily Practice Goal':
        return '⏱️'; // Timer for practice time
      case 'Current Goal':
        return '🎯'; // Target for goals
      case 'Learning Preference':
        return '🧠'; // Brain for learning style
      case 'Desired Accent':
        return '🎤'; // Microphone for accent
      default:
        return ''; // Default empty string if title doesn't match
    }
  }
}
