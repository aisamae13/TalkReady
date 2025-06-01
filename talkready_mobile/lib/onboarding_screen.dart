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
import 'package:talkready_mobile/Teachers/TrainerDashboard.dart';
// Add this to pubspec.yaml

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

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isActive = _currentPage == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: isActive ? 28 : 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive ? primaryColor : Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
              boxShadow: isActive
                  ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8)]
                  : [],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: child,
      ),
    );
  }

  Widget _buildStage1() {
    return _buildCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Tell us about yourself",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: "First Name",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.person_outline),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: "Last Name",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Age",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.cake_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // Gender selection
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: "Gender",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.wc),
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
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _selectBirthdate(context),
            child: AbsorbPointer(
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Birthdate",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.calendar_today),
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
          const SizedBox(height: 32),
          AnimatedOpacity(
            opacity: _isStage1Valid() ? 1 : 0.5,
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: _isStage1Valid()
                  ? () {
                      setState(() {
                        _currentPage++;
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage2() {
    return _buildCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Where do you live?",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _provinceController,
            decoration: InputDecoration(
              labelText: "Province",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.location_city),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _municipalityController,
            decoration: InputDecoration(
              labelText: "Municipality",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.location_on),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _barangayController,
            decoration: InputDecoration(
              labelText: "Barangay",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.home_work_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentPage--;
                  });
                },
                icon: Icon(Icons.arrow_back, color: primaryColor),
                label: Text('Back', style: TextStyle(fontSize: 16, color: primaryColor)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              AnimatedOpacity(
                opacity: _isStage2Valid() ? 1 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton.icon(
                  onPressed: _isStage2Valid()
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                        }
                      : null,
                  icon: Icon(Icons.arrow_forward, color: Colors.white),
                  label: Text('Continue', style: TextStyle(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStage3() {
    return _buildCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Upload your profile picture",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _profilePic != null
                ? CircleAvatar(
                    key: ValueKey(_profilePic),
                    radius: 56,
                    backgroundImage: FileImage(_profilePic!),
                  )
                : CircleAvatar(
                    key: ValueKey('empty'),
                    radius: 56,
                    backgroundColor: Colors.grey[200],
                    child: Icon(Icons.person, size: 56, color: Colors.grey[400]),
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickProfilePic,
                icon: Icon(Icons.upload, color: Colors.white),
                label: Text('Upload', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () async {
                  setState(() {
                    _profilePic = null;
                  });
                  await _saveToFirestoreAndNavigate();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Skip', style: TextStyle(fontSize: 16, color: primaryColor)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentPage--;
                  });
                },
                icon: Icon(Icons.arrow_back, color: primaryColor),
                label: Text('Back', style: TextStyle(fontSize: 16, color: primaryColor)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _saveToFirestoreAndNavigate();
                },
                icon: Icon(Icons.check_circle, color: Colors.white),
                label: Text('Finish', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stages = [
      _buildStage1(),
      _buildStage2(),
      _buildStage3(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Before We Start',
          style: TextStyle(fontSize: 22, color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      resizeToAvoidBottomInset: true, // <-- Add this line
      body: SafeArea(
        child: SingleChildScrollView( // <-- Wrap with this
          child: Column(
            children: [
              _buildProgressIndicator(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    )),
                child: stages[_currentPage],
              ),
            ],
          ),
        ),
      ),
    );
  }
}