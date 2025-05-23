import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'settings/settings.dart';

class TrainerProfile extends StatefulWidget {
  const TrainerProfile({super.key});

  @override
  State<TrainerProfile> createState() => _TrainerProfileState();
}

class _TrainerProfileState extends State<TrainerProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _userStreamSubscription;
  bool _isLoading = true;

  final Logger _logger = Logger();

  String? _firstName;
  String? _lastName;
  String? _email;
  String? _profilePicBase64;
  bool? _profilePicSkipped;

  int _selectedIndex = 1; // 0: Dashboard, 1: Profile

  @override
  void initState() {
    super.initState();
    _setupUserStream();
    _fetchEmail();
  }

  void _fetchEmail() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email;
      });
    }
  }

  void _setupUserStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _logger.i('Setting up stream for user UID: ${user.uid}');
      _userStreamSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
        (snapshot) {
          _logger.i('Received Firestore snapshot: ${snapshot.data}');
          if (snapshot.exists) {
            final data = snapshot.data() ?? {};
            setState(() {
              _firstName = data['firstName'];
              _lastName = data['lastName'];
              _profilePicBase64 = data['profilePicBase64'] as String?;
              _profilePicSkipped = data['profilePicSkipped'] as bool?;
              _isLoading = false;
            });
          } else {
            _logger.w('No Firestore document exists for UID: ${user.uid}');
            setState(() {
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          _logger.e('Error in Firestore stream: $error');
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error listening to user data: $error')),
          );
        },
      );
    } else {
      _logger.w('No authenticated user found');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in')),
      );
    }
  }

  void _showEditNameDialog() {
    TextEditingController firstNameController = TextEditingController(text: _firstName ?? '');
    TextEditingController lastNameController = TextEditingController(text: _lastName ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Name',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00568D),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your first name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00568D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00568D), width: 2),
                    ),
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your last name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00568D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00568D), width: 2),
                    ),
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 40,
                      width: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFF00568D), width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF00568D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      height: 40,
                      width: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFF00568D), width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (firstNameController.text.isNotEmpty && lastNameController.text.isNotEmpty) {
                            setState(() {
                              _firstName = firstNameController.text;
                              _lastName = lastNameController.text;
                            });
                            _saveNameToFirestore(firstNameController.text, lastNameController.text);
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Both fields are required')),
                            );
                          }
                        },
                        child: const Text(
                          'Save',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF00568D),
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
        );
      },
    );
  }

  Future<void> _saveNameToFirestore(String newFirstName, String newLastName) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _logger.i('Saving name to Firestore for UID: ${user.uid}');
        await _firestore.collection('users').doc(user.uid).update({
          'firstName': newFirstName,
          'lastName': newLastName,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updated your full name successfully'),
              duration: Duration(seconds: 3),
              backgroundColor: Color(0xFF00568D),
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error saving name: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving name: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadProfilePic() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _isLoading = true;
        });

        final user = _auth.currentUser;
        if (user != null) {
          final file = File(pickedFile.path);
          final imageBytes = await file.readAsBytes();
          final image = img.decodeImage(imageBytes)!;
          final resizedImage = img.copyResize(image, width: 200);
          final base64Image = img.encodePng(resizedImage);
          if (base64Image.length > 1000000) {
            _logger.e('Profile picture too large for Firestore (exceeds 1 MB)');
            throw Exception('Profile picture is too large to store in Firestore');
          }
          final profilePicBase64 = base64Encode(base64Image);

          await _firestore.collection('users').doc(user.uid).update({
            'profilePicBase64': profilePicBase64,
            'profilePicSkipped': false,
          });

          setState(() {
            _profilePicBase64 = profilePicBase64;
            _profilePicSkipped = false;
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
    _userStreamSubscription.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/trainer-dashboard');
        return;
      case 1:
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00568D)))
          : Column(
              children: [
                // Profile header
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2973B2), Color(0xFF618DB2)],
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: IconButton(
                                icon: const Icon(Icons.settings, color: Colors.white, size: 30),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => SettingsPage()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Color(0xFF9CA8C7), width: 4.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 70,
                                  backgroundImage: _profilePicBase64 != null
                                      ? MemoryImage(base64Decode(_profilePicBase64!)) as ImageProvider
                                      : null,
                                  backgroundColor: _profilePicBase64 == null && _profilePicSkipped == true
                                      ? null
                                      : Colors.grey[300],
                                  child: _profilePicBase64 == null && _profilePicSkipped == true
                                      ? Icon(Icons.person, size: 70, color: Colors.grey[600])
                                      : null,
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
                            Text(
                              _firstName != null && _lastName != null
                                  ? '$_firstName $_lastName'
                                  : 'Trainer',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                              onPressed: _showEditNameDialog,
                            ),
                          ],
                        ),
                        if (_email != null)
                          Text(
                            _email!,
                            style: const TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Expanded(child: Container()),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00568D),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}