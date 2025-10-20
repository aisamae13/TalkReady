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
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';


void main() {
  runApp(const MyApp());
}

const Color primaryColor = Color(0xFF00568D);
const Color secondaryBlue = Color(0xFF2973B2);
const Color lightBlue = Color(0xFFE3F2FD);
const Color accentBlue = Color(0xFF1E88E5);

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

@override
  void initState() {
    super.initState();
    // Load any saved progress when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedProgress();
    });
  }
  // 1. UTILITY: Function to calculate age from birthdate
  int _calculateAge(DateTime birthDate) {
    DateTime now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _showErrorDialog(String title, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'OK',
            style: TextStyle(
              color: Color(0xFF00568D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

void _navigateToNextPage() {
  setState(() {
    _currentPage++;
  });
  // Auto-save progress when moving forward
  _savePartialProgress();
}
Future<void> _savePartialProgress() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final Map<String, dynamic> partialData = {
      'onboardingStage': _currentPage,
      'onboardingStarted': true,
      'onboardingCompleted': false,
      'partialData': {
        if (_firstNameController.text.isNotEmpty)
          'firstName': _firstNameController.text.trim(),
        if (_lastNameController.text.isNotEmpty)
          'lastName': _lastNameController.text.trim(),
        if (_ageController.text.isNotEmpty)
          'age': _ageController.text.trim(),
        if (_birthdate != null)
          'birthdate': Timestamp.fromDate(_birthdate!),
        if (_selectedGender != null)
          'gender': _selectedGender,
        if (_provinceController.text.isNotEmpty)
          'province': _provinceController.text.trim(),
        if (_municipalityController.text.isNotEmpty)
          'municipality': _municipalityController.text.trim(),
        if (_barangayController.text.isNotEmpty)
          'barangay': _barangayController.text.trim(),
      },
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(partialData, SetOptions(merge: true));

    _logger.i('Partial onboarding progress saved');
  } catch (e) {
    _logger.e('Error saving partial progress: $e');
  }
}

// 2. Add a method to load saved progress
Future<void> _loadSavedProgress() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data();
    if (data == null || data['onboardingStarted'] != true) return;

    // Restore stage
    if (data['onboardingStage'] != null) {
      setState(() {
        _currentPage = data['onboardingStage'] as int;
      });
    }

    // Restore partial data
    final partialData = data['partialData'] as Map<String, dynamic>?;
    if (partialData != null) {
      setState(() {
        if (partialData['firstName'] != null) {
          _firstNameController.text = partialData['firstName'];
        }
        if (partialData['lastName'] != null) {
          _lastNameController.text = partialData['lastName'];
        }
        if (partialData['age'] != null) {
          _ageController.text = partialData['age'];
        }
        if (partialData['birthdate'] != null) {
          _birthdate = (partialData['birthdate'] as Timestamp).toDate();
        }
        if (partialData['gender'] != null) {
          _selectedGender = partialData['gender'];
        }
        if (partialData['province'] != null) {
          _provinceController.text = partialData['province'];
        }
        if (partialData['municipality'] != null) {
          _municipalityController.text = partialData['municipality'];
        }
        if (partialData['barangay'] != null) {
          _barangayController.text = partialData['barangay'];
        }
      });

      _logger.i('Restored onboarding progress from stage $_currentPage');

      // Show snackbar to inform user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.restore, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Welcome back! Your progress has been restored.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2973B2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  } catch (e) {
    _logger.e('Error loading saved progress: $e');
  }
}

// 3. Show themed exit confirmation dialog
Future<bool> _showExitConfirmationDialog() async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              lightBlue.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with gradient background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade100,
                    Colors.orange.shade50,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.exit_to_app_rounded,
                size: 48,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [primaryColor, accentBlue],
              ).createShader(bounds),
              child: const Text(
                'Exit Onboarding?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentBlue.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Your progress will be saved and you can resume later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: accentBlue,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'You\'ll return to this step when you log in again',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Stay',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: Colors.orange.withOpacity(0.4),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.exit_to_app, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Exit',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
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
  ) ?? false;
}

// 4. Handle back button press
Future<bool> _onWillPop() async {
  // If on first page, show exit dialog
  if (_currentPage == 0) {
    final shouldExit = await _showExitConfirmationDialog();
    if (shouldExit) {
      await _savePartialProgress();
      // Sign out if they want to exit
      await FirebaseAuth.instance.signOut();
      return true;
    }
    return false;
  }

  // If on later pages, go back one step
  setState(() {
    _currentPage--;
  });
  return false;
}
Future<bool> _showUploadGuidelinesDialog() async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2973B2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2973B2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Profile Picture Guidelines',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00568D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildGuidelineItem(
                Icons.photo_size_select_actual,
                'Recommended Size',
                '500x500 pixels (square)',
              ),
              const SizedBox(height: 12),
              _buildGuidelineItem(
                Icons.file_present,
                'Maximum File Size',
                '5 MB',
              ),
              const SizedBox(height: 12),
              _buildGuidelineItem(
                Icons.image,
                'Supported Formats',
                'JPG, JPEG, PNG',
              ),
              const SizedBox(height: 12),
              _buildGuidelineItem(
                Icons.crop,
                'Cropping',
                'You can crop your image after selection',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tip: Use a clear, well-lit photo for best results',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF00568D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF00568D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2973B2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Choose Photo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ) ?? false;
}

Widget _buildGuidelineItem(IconData icon, String title, String description) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        color: const Color(0xFF2973B2),
        size: 20,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Future<File?> _cropImage(File imageFile) async {
  try {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Picture',
          toolbarColor: const Color(0xFF2973B2),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
          hideBottomControls: false,
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: 'Crop Profile Picture',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
        ),
      ],
      compressQuality: 90,
      maxWidth: 1000,
      maxHeight: 1000,
    );

    return croppedFile != null ? File(croppedFile.path) : null;
  } catch (e) {
    _logger.e('Error cropping image: $e');
    return null;
  }
}

 Future<void> _pickProfilePic() async {
  try {
    // Show upload guidelines dialog first
    final shouldProceed = await _showUploadGuidelinesDialog();
    if (!shouldProceed) return;

    _logger.i('Attempting to pick profile picture from gallery');

    // Pick image with file size validation
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;

    // Validate file size (5MB limit)
    const maxSizeInBytes = 5 * 1024 * 1024; // 5MB
    if (pickedFile.size > maxSizeInBytes) {
      if (mounted) {
        _showErrorDialog(
          'File Too Large',
          'Please select an image smaller than 5MB. Current size: ${(pickedFile.size / (1024 * 1024)).toStringAsFixed(2)}MB',
        );
      }
      return;
    }

    // Validate file format
    final extension = pickedFile.extension?.toLowerCase();
    if (extension == null || !['jpg', 'jpeg', 'png'].contains(extension)) {
      if (mounted) {
        _showErrorDialog(
          'Invalid Format',
          'Please select a JPG or PNG image.',
        );
      }
      return;
    }

    // Show preview and crop dialog
    final file = File(pickedFile.path!);
    final croppedFile = await _cropImage(file);

    if (croppedFile == null) {
      _logger.w('Image cropping cancelled by user');
      return; // User cancelled cropping
    }

    setState(() {
      _profilePic = croppedFile;
    });
    _logger.i('Profile picture selected and cropped successfully: ${croppedFile.path}');

  } on PlatformException catch (e) {
    _logger.e('Error picking profile picture: $e');
    if (e.code == 'permission_denied' || e.code == 'permission_denied_never_ask') {
      _logger.w('Storage permission denied, showing snackbar');
      if (mounted) {
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
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking profile picture: $e')),
        );
      }
    }
  } catch (e) {
    _logger.e('Unexpected error picking profile picture: $e');
    if (mounted) {
      _showErrorDialog(
        'Upload Failed',
        'An error occurred while selecting your profile picture. Please try again.',
      );
    }
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
      'onboardingCompleted': true,
    };

   if (_profilePic != null) {
  _logger.i('Encoding profile picture to base64: ${_profilePic!.path}');
  final imageBytes = await _profilePic!.readAsBytes();
  final image = img.decodeImage(imageBytes);

  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Resize to recommended size (500x500)
  final resizedImage = img.copyResize(
    image,
    width: 500,
    height: 500,
    interpolation: img.Interpolation.average,
  );

  // Encode as PNG for better quality
  final encodedImage = img.encodePng(resizedImage, level: 6);

  // Final size check after processing
  if (encodedImage.length > 1000000) {
    _logger.e('Profile picture too large after encoding');
    throw Exception('The processed image is still too large. Please try a different image.');
  }

  final profilePicBase64 = base64Encode(encodedImage);

  // Clean base64 string (remove data URI prefix if present)
  final cleanBase64 = profilePicBase64.contains(',')
      ? profilePicBase64.split(',').last
      : profilePicBase64;

  userInfo['profilePicBase64'] = cleanBase64;
  userInfo['profilePicSkipped'] = false;
  userInfo['profilePicUpdatedAt'] = FieldValue.serverTimestamp();
  _logger.i('Profile picture encoded successfully as base64');
} else {
      _logger.w('No profile picture selected, skipping upload');
      userInfo['profilePicBase64'] = null;
      userInfo['profilePicSkipped'] = true;
    }

    // Save user info to 'users' collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(userInfo, SetOptions(merge: true));

    // 🆕 NEW: Initialize userProgress with streak freezes for students
    if (widget.userType?.trim().toLowerCase() == 'student') {
      _logger.i('Initializing userProgress with streak freezes for new student');

      await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(user.uid)
          .set({
            'streakFreezes': 3,              // Start with 3 freezes
            'currentStreak': 0,              // No streak yet
            'longestStreak': 0,              // No longest streak yet
            'lastActiveDate': null,          // No activity yet
            'lessonAttempts': {},            // Empty lesson attempts
            'moduleAssessmentAttempts': {},  // Empty assessment attempts
            'preAssessmentsCompleted': {},   // Empty pre-assessments
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _logger.i('Successfully initialized userProgress with 3 streak freezes');
    }

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

  } catch (e) {
    _logger.e('Error saving user information: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving user information: $e')),
    );
  }
}

  // 2. VALIDATION: Check for age consistency
 bool _isStage1Valid() {
  // Simplified validation - age is auto-calculated, no need to validate it
  return _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _birthdate != null &&
      _selectedGender != null &&
      _ageController.text.trim().isNotEmpty;
}

  bool _isStage2Valid() {
    return _provinceController.text.trim().isNotEmpty &&
        _municipalityController.text.trim().isNotEmpty &&
        _barangayController.text.trim().isNotEmpty;
  }

 Future<void> _selectBirthdate(BuildContext context) async {
    final now = DateTime.now();

    // Define the custom color scheme
    final customColorScheme = ColorScheme.light(
      primary: primaryColor, // Blue color for header background, selected day circle
      onPrimary: Colors.white, // White color for text/icons on the primary color
      surface: Colors.white, // White color for the main calendar surface
      onSurface: Colors.black, // Black for day numbers
      onBackground: primaryColor, // Hint for text fields (sometimes)
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          // Apply the custom color scheme to the date picker
          data: ThemeData.light().copyWith(
            colorScheme: customColorScheme,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor, // Blue color for 'CANCEL' and 'OK' buttons
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
  setState(() {
    _birthdate = picked;
    // Automatically calculate and set age
    final calculatedAge = _calculateAge(picked);
    _ageController.text = calculatedAge.toString();
  });
}
  }

Widget _buildProgressIndicator() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, lightBlue.withOpacity(0.3)],
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = _currentPage == index;
        final isCompleted = _currentPage > index;

        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: isActive ? 48 : 40,
              height: isActive ? 48 : 40,
              decoration: BoxDecoration(
                gradient: isActive || isCompleted
                    ? LinearGradient(
                        colors: [accentBlue, secondaryBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isActive || isCompleted ? null : Colors.grey[300],
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: accentBlue.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            if (index < 2)
              Container(
                width: 40,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: isCompleted
                      ? LinearGradient(
                          colors: [accentBlue, secondaryBlue],
                        )
                      : null,
                  color: isCompleted ? null : Colors.grey[300],
                ),
              ),
          ],
        );
      }),
    ),
  );
}

 Widget _buildCard({required Widget child}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          lightBlue.withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.9),
          blurRadius: 6,
          offset: const Offset(-4, -4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: child,
    ),
  );
}

 Widget _buildStage1() {
  return _buildCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 3,
                color: accentBlue,
              ),
            ),
          ),
          child: Text(
            "Tell us about yourself",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [primaryColor, accentBlue],
                ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: "First Name",
            labelStyle: TextStyle(color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentBlue, width: 2),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue.withOpacity(0.1), secondaryBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_outline, color: primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: "Last Name",
            labelStyle: TextStyle(color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentBlue, width: 2),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue.withOpacity(0.1), secondaryBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person, color: primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _ageController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: "Age",
            labelStyle: TextStyle(color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentBlue, width: 2),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue.withOpacity(0.1), secondaryBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.cake_outlined, color: primaryColor),
            ),
            filled: true,
            fillColor: lightBlue.withOpacity(0.1),
            hintText: _birthdate == null ? "Select birthdate first" : null,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            suffixIcon: _birthdate != null
                ? Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: InputDecoration(
            labelText: "Gender",
            labelStyle: TextStyle(color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentBlue, width: 2),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue.withOpacity(0.1), secondaryBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.wc, color: primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
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
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _selectBirthdate(context),
          child: AbsorbPointer(
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Birthdate",
                labelStyle: TextStyle(color: primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accentBlue, width: 2),
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentBlue.withOpacity(0.1), secondaryBlue.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today, color: primaryColor),
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: _birthdate == null
                    ? "Select your birthdate"
                    : "${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2, '0')}-${_birthdate!.day.toString().padLeft(2, '0')}",
                hintStyle: TextStyle(color: Colors.grey[400]),
              ),
              controller: TextEditingController(
                text: _birthdate == null
                    ? ""
                    : "${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2, '0')}-${_birthdate!.day.toString().padLeft(2, '0')}",
              ),
              onTap: () => setState(() {}),
            ),
          ),
        ),
        const SizedBox(height: 36),
        AnimatedOpacity(
          opacity: _isStage1Valid() ? 1 : 0.5,
          duration: const Duration(milliseconds: 300),
          child: ElevatedButton(
          onPressed: _isStage1Valid() ? _navigateToNextPage : null,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 0,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: _isStage1Valid()
                  ? LinearGradient(
                      colors: [accentBlue, secondaryBlue],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: _isStage1Valid() ? null : Colors.grey[300],
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 18.0),
              alignment: Alignment.center,
              child: Text(
                'Continue',
                style: TextStyle(
                  fontSize: 18,
                  color: _isStage1Valid() ? Colors.white : Colors.grey[500],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
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
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 3,
                color: accentBlue,
              ),
            ),
          ),
          child: Text(
            "Where do you live?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [primaryColor, accentBlue],
                ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _provinceController,
          decoration: InputDecoration(
            labelText: "Province",
            labelStyle: TextStyle(color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentBlue, width: 2),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue.withOpacity(0.1), secondaryBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.location_city, color: primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _municipalityController,
          decoration: InputDecoration(
            labelText: "Municipality",
            labelStyle: TextStyle(color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentBlue, width: 2),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue.withOpacity(0.1), secondaryBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.location_on, color: primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _barangayController,
          decoration: InputDecoration(
            labelText: "Barangay",
            labelStyle: TextStyle(color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentBlue, width: 2),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentBlue.withOpacity(0.1), secondaryBlue.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.home_work_outlined, color: primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded( // <-- WRAP 1: Expanded for the "Back" button
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentPage--;
                  });
                },
                icon: Icon(Icons.arrow_back_rounded, color: primaryColor, size: 20),
                label: Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 16,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16), // Reduced horizontal padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12), // <-- Add a small separator
           Expanded( // <-- WRAP 2: Expanded for the "Continue" button
              child: AnimatedOpacity(
                opacity: _isStage2Valid() ? 1 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton.icon(
                  onPressed: _isStage2Valid() ? _navigateToNextPage : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: _isStage2Valid() ? 8 : 0,
                    shadowColor: accentBlue.withOpacity(0.4),
                  ),
                  icon: const SizedBox.shrink(),
                  label: Ink(
                    decoration: BoxDecoration(
                      gradient: _isStage2Valid()
                          ? LinearGradient(
                              colors: [accentBlue, secondaryBlue],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: _isStage2Valid() ? null : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0), // Reduced horizontal padding
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: _isStage2Valid() ? Colors.white : Colors.grey[500],
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: _isStage2Valid() ? Colors.white : Colors.grey[500],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
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
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes
        final avatarRadius = constraints.maxWidth > 400 ? 70.0 : 60.0;
        final buttonPadding = constraints.maxWidth > 400
            ? const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0)
            : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 3,
                    color: accentBlue,
                  ),
                ),
              ),
              child: Text(
                "Upload your profile picture",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: constraints.maxWidth > 400 ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = LinearGradient(
                      colors: [primaryColor, accentBlue],
                    ).createShader(Rect.fromLTWH(0.0, 0.0, 300.0, 70.0)),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _profilePic != null
                  ? Container(
                      key: ValueKey(_profilePic),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentBlue.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: [accentBlue.withOpacity(0.2), secondaryBlue.withOpacity(0.2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundImage: FileImage(_profilePic!),
                      ),
                    )
                  : Container(
                      key: ValueKey('empty'),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [lightBlue.withOpacity(0.3), Colors.grey[200]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Icon(
                            Icons.person,
                            size: avatarRadius * 0.8,
                            color: primaryColor.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickProfilePic,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: accentBlue.withOpacity(0.4),
                  ),
                  icon: const SizedBox.shrink(),
                  label: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentBlue, secondaryBlue],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      padding: buttonPadding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.upload_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Upload Photo',
                            style: TextStyle(
                              fontSize: constraints.maxWidth > 400 ? 16 : 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() {
                      _profilePic = null;
                    });
                    await _saveToFirestoreAndNavigate();
                  },
                  icon: Icon(Icons.skip_next_rounded, color: primaryColor, size: 20),
                  label: Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: constraints.maxWidth > 400 ? 16 : 14,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryColor, width: 2),
                    padding: buttonPadding,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: accentBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Use a clear, well-lit photo for best results',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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
                  icon: Icon(Icons.arrow_back_rounded, color: primaryColor, size: 20),
                  label: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: constraints.maxWidth > 400 ? 16 : 14,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _saveToFirestoreAndNavigate();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 8,
                    shadowColor: accentBlue.withOpacity(0.4),
                  ),
                  icon: const SizedBox.shrink(),
                  label: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Finish',
                            style: TextStyle(
                              fontSize: constraints.maxWidth > 400 ? 16 : 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
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
  );
}

 @override
Widget build(BuildContext context) {
  final stages = [
    _buildStage1(),
    _buildStage2(),
    _buildStage3(),
  ];

  return WillPopScope(
    onWillPop: _onWillPop,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [primaryColor, accentBlue],
          ).createShader(bounds),
          child: const Text(
            'Before We Start',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        leading: _currentPage > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _currentPage--;
                  });
                },
              )
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accentBlue.withOpacity(0.3),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildProgressIndicator(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) =>
                    FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                child: stages[_currentPage],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}