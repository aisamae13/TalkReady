import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:talkready_mobile/next_screen.dart';
import 'package:talkready_mobile/TrainerDashboard.dart';
import 'package:talkready_mobile/homepage.dart';

void main() {
  runApp(const MyApp());
}

const Color primaryColor = Color(0xFF00568D);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Onboarding Demo',
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: Firebase.initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Change 'trainer' to 'student' to test as student
            return const OnboardingScreen(userType: 'trainer');
            // return const OnboardingScreen(userType: 'student');
          }
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00568D)));
        },
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final String? userType;

  const OnboardingScreen({super.key, this.userType});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Stage 1 fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  DateTime? _birthdate;
  String? _selectedGender;

  // Stage 2 fields
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _municipalityController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();

  // Stage 3: Profile Pic
  File? _profilePic;
  final ImagePicker _picker = ImagePicker();
  final Logger _logger = Logger();

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _provinceController.dispose();
    _municipalityController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePic() async {
    try {
      _logger.i('Attempting to pick profile picture from gallery');
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profilePic = File(pickedFile.path);
        });
        _logger.i('Profile picture selected successfully: ${pickedFile.path}');
      } else {
        _logger.w('No image selected by user');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected')),
        );
      }
    } on PlatformException catch (e) {
      _logger.e('Error picking profile picture: $e');
      if (e.code == 'permission_denied' || e.code == 'permission_denied_never_ask') {
        _logger.w('Storage permission denied, showing snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Storage permission is required to pick images. Please enable it in app settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking profile picture: $e')),
        );
      }
    } catch (e) {
      _logger.e('Unexpected error picking profile picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error picking profile picture: $e')),
      );
    }
  }

  Future<void> _saveToFirestoreAndNavigate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final Map<String, dynamic> userInfo = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'age': _ageController.text.trim(),
        'birthdate': _birthdate != null ? Timestamp.fromDate(_birthdate!) : null,
        'gender': _selectedGender,
        'province': _provinceController.text.trim(),
        'municipality': _municipalityController.text.trim(),
        'barangay': _barangayController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_profilePic != null) {
        _logger.i('Encoding profile picture to base64: ${_profilePic!.path}');
        final imageBytes = await _profilePic!.readAsBytes();
        final image = img.decodeImage(imageBytes)!;
        final resizedImage = img.copyResize(image, width: 200);
        final base64Image = img.encodePng(resizedImage);
        if (base64Image.length > 1000000) {
          _logger.e('Profile picture too large for Firestore (exceeds 1 MB)');
          throw Exception('Profile picture is too large to store in Firestore');
        }
        userInfo['profilePicBase64'] = base64Encode(base64Image);
        userInfo['profilePicSkipped'] = false;
        _logger.i('Profile picture encoded successfully as base64');
      } else {
        _logger.w('No profile picture selected, skipping upload');
        userInfo['profilePicBase64'] = null;
        userInfo['profilePicSkipped'] = true;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userInfo, SetOptions(merge: true));

      if (!mounted) return;

      print('DEBUG: userType is "${widget.userType}"');
      if (widget.userType?.trim().toLowerCase() == 'trainer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TrainerDashboard()),
        );
        return;
      }
      if (widget.userType?.trim().toLowerCase() == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NextScreen(responses: userInfo)),
        );
        return;
      }
      // Optionally handle other user types or fallback here

    } catch (e) {
      _logger.e('Error saving user information: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving user information: $e')),
      );
    }
  }

  bool _isStage1Valid() {
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _ageController.text.trim().isNotEmpty &&
        _birthdate != null &&
        _selectedGender != null;
  }

  bool _isStage2Valid() {
    return _provinceController.text.trim().isNotEmpty &&
        _municipalityController.text.trim().isNotEmpty &&
        _barangayController.text.trim().isNotEmpty;
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthdate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Before We Start',
          style: TextStyle(fontSize: 20, color: primaryColor),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00568D).withOpacity(0.1),
              Colors.grey[50]!,
            ],
          ),
        ),
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Stage 1: Name, Age, Birthdate, Gender
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Tell us about yourself",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: "First Name",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: "Last Name",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Age",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 15),
                      // Gender selection
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: "Gender",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: () => _selectBirthdate(context),
                        child: AbsorbPointer(
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: "Birthdate",
                              border: const OutlineInputBorder(),
                              hintText: _birthdate == null
                                  ? "Select your birthdate"
                                  : "${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2, '0')}-${_birthdate!.day.toString().padLeft(2, '0')}",
                            ),
                            controller: TextEditingController(
                              text: _birthdate == null
                                  ? ""
                                  : "${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2, '0')}-${_birthdate!.day.toString().padLeft(2, '0')}",
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isStage1Valid()
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Stage 2: Province, Municipality, Barangay
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Where do you live?",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _provinceController,
                        decoration: const InputDecoration(
                          labelText: "Province",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _municipalityController,
                        decoration: const InputDecoration(
                          labelText: "Municipality",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _barangayController,
                        decoration: const InputDecoration(
                          labelText: "Barangay",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text(
                              'Back',
                              style: TextStyle(fontSize: 16, color: primaryColor),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isStage2Valid()
                                ? () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Stage 3: Profile Pic
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Upload your profile picture",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _profilePic != null ? FileImage(_profilePic!) as ImageProvider : null,
                        backgroundColor: _profilePic == null ? Colors.grey[300] : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _pickProfilePic,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            child: const Text(
                              'Upload Profile Picture',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _profilePic = null;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile picture skipped')),
                              );
                            },
                            child: const Text(
                              'Skip',
                              style: TextStyle(fontSize: 16, color: primaryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text(
                              'Back',
                              style: TextStyle(fontSize: 16, color: primaryColor),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await _saveToFirestoreAndNavigate();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                            child: const Text(
                              'Finish',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}