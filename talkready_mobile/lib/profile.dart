import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:talkready_mobile/custom_animated_bottom_bar.dart';
import 'homepage.dart';
import 'courses_page.dart';
import 'journal/journal_page.dart';
import 'progress_page.dart';
import 'package:talkready_mobile/settings/about_us.dart';
import 'package:talkready_mobile/settings/comm_guide.dart';
import 'package:talkready_mobile/settings/faq_support.dart';
import 'package:talkready_mobile/settings/terms_of_service.dart';
import 'package:animations/animations.dart';
import '../session/device_session_manager.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'MyEnrolledClasses.dart';

// Helper function for creating a slide page route for bottom navigation
Route _createSlidingPageRoute({
  required Widget page,
  required int newIndex,
  required int oldIndex,
  required Duration duration, // duration will be ignored
}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return child; // Return child directly for no animation
    },
    transitionDuration: Duration.zero, // Instant transition
    reverseTransitionDuration: Duration.zero, // Instant reverse transition
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// Helper function to extract pure base64 data from data URI
  String _cleanBase64String(String base64String) {
    // Remove data URI prefix if present (e.g., "data:image/jpeg;base64,")
    if (base64String.contains(',')) {
      return base64String.split(',').last;
    }
    return base64String;
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
  _userStreamSubscription;
  bool _isLoading = true;

  final Logger _logger = Logger();

  String? _firstName;
  String? _lastName;
  String? _email;
  String? _profilePicBase64;
  bool? _profilePicSkipped;

  String? _age;
  String? _gender;
  String? _birthdate;
  String? _province;
  String? _municipality;
  String? _barangay;

  int _selectedIndex = 5;

  @override
  void initState() {
    super.initState();
    _setupUserStream();
    _fetchEmail();
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
          Text(
            title,
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
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
                  _age = data['age']?.toString();
                  _gender = data['gender'];
                  _birthdate = _formatBirthdate(data['birthdate']);
                  _province = data['province'];
                  _municipality = data['municipality'];
                  _barangay = data['barangay'];
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error listening to user data: $error'),
                  ),
                );
              }
            },
          );
    } else {
      _logger.w('No authenticated user found');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No user logged in')));
      }
    }
  }

  String? _formatBirthdate(dynamic birthdate) {
    if (birthdate == null) return null;
    if (birthdate is Timestamp) {
      final date = birthdate.toDate();
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    }
    if (birthdate is String) return birthdate;
    return birthdate.toString();
  }

  void _showEditNameDialog() {
    TextEditingController firstNameController = TextEditingController(
      text: _firstName ?? '',
    );
    TextEditingController lastNameController = TextEditingController(
      text: _lastName ?? '',
    );
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
                colors: [Colors.blue.shade50, Colors.white],
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
                      borderSide: const BorderSide(
                        color: Color(0xFF00568D),
                        width: 2,
                      ),
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
                      borderSide: const BorderSide(
                        color: Color(0xFF00568D),
                        width: 2,
                      ),
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
                        border: Border.all(
                          color: const Color(0xFF00568D),
                          width: 1,
                        ),
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
                        border: Border.all(
                          color: const Color(0xFF00568D),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (firstNameController.text.isNotEmpty &&
                              lastNameController.text.isNotEmpty) {
                            setState(() {
                              _firstName = firstNameController.text;
                              _lastName = lastNameController.text;
                            });
                            _saveNameToFirestore(
                              firstNameController.text,
                              lastNameController.text,
                            );
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Both fields are required'),
                              ),
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

  Future<void> _saveNameToFirestore(
    String newFirstName,
    String newLastName,
  ) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving name: $e')));
      }
    }
  }

 Future<void> _pickAndUploadProfilePic() async {
  try {
    // Show upload guidelines dialog first
    final shouldProceed = await _showUploadGuidelinesDialog();
    if (!shouldProceed) return;

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

    if (croppedFile == null) return; // User cancelled cropping

    // Show loading
    setState(() {
      _isLoading = true;
    });

    final user = _auth.currentUser;
    if (user != null) {
      // Read and process the cropped image
      final imageBytes = await croppedFile.readAsBytes();
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
        if (mounted) {
          _showErrorDialog(
            'Processing Error',
            'The processed image is still too large. Please try a different image.',
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final profilePicBase64 = base64Encode(encodedImage);

      // Clean base64 string (remove data URI prefix if present)
      final cleanBase64 = profilePicBase64.contains(',')
          ? profilePicBase64.split(',').last
          : profilePicBase64;

      // Upload to Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profilePicBase64': cleanBase64,
        'profilePicSkipped': false,
        'profilePicUpdatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _profilePicBase64 = cleanBase64;
        _profilePicSkipped = false;
        _isLoading = false;
      });

      _logger.i('Profile picture saved successfully for UID: ${user.uid}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile picture updated successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF00568D),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() => _isLoading = false);
    }
  } catch (e) {
    _logger.e('Error uploading profile picture: $e');
    setState(() {
      _isLoading = false;
    });
    if (mounted) {
      _showErrorDialog(
        'Upload Failed',
        'An error occurred while uploading your profile picture. Please try again.',
      );
    }
  }
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

// 5. Add the upload guidelines dialog:

Future<bool> _showUploadGuidelinesDialog() async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
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
                      fontSize: 20,
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
                      horizontal: 24,
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
  ) ?? false;
}
 Future<void> _signOut(BuildContext context) async {
  try {
    _logger.i('Attempting to sign out user');

    final user = FirebaseAuth.instance.currentUser;

    // End device session
    if (user != null) {
      await DeviceSessionManager().endSession(user.uid);
      _logger.i('Device session ended for user: ${user.uid}');
    }

    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();
    _logger.i('User signed out successfully');

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

      // Show logout confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Logged out successfully'),
            ],
          ),
          backgroundColor: Color(0xFF00568D),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    _logger.e('Error signing out: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
}

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final initialConfirmation = await showDialog<bool>(
          context: context,
          builder: (context) => _buildCustomDialog(
            context: context,
            title: 'Delete Account',
            content:
                'Are you sure you want to permanently delete your account? This action cannot be undone.',
            cancelText: 'Cancel',
            confirmText: 'Continue',
            onConfirm: () => Navigator.pop(context, true),
          ),
        );

        if (initialConfirmation == true) {
          final finalConfirmation = await showDialog<bool>(
            context: context,
            builder: (context) {
              String inputText = '';
              return StatefulBuilder(
                builder: (context, setStateDialog) {
                  return Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Final Confirmation',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00568D),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'To confirm account deletion, please type "confirm" below. This action cannot be undone.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            onChanged: (value) {
                              setStateDialog(() {
                                inputText = value;
                              });
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Type "confirm"',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.grey[800],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: inputText.toLowerCase() == 'confirm'
                                    ? () => Navigator.pop(context, true)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      inputText.toLowerCase() == 'confirm'
                                      ? Colors
                                            .red
                                            .shade700 // Changed to Colors.red.shade700
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
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
            },
          );

          if (finalConfirmation == true) {
            _logger.i('Attempting to delete account for UID: ${user.uid}');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .delete();
            _logger.i('Firestore data deleted for UID: ${user.uid}');
            await user.delete();
            _logger.i('User account deleted successfully');

            await DeviceSessionManager().endSession(user.uid);
            _logger.i('Device session ended after account deletion');

            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            }
          }
        }
      }
    } catch (e) {
      _logger.e('Error deleting account: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      }
    }
  }

  Widget _buildCustomDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String cancelText,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    cancelText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: title == 'Sign Out'
                        ? const Color(0xFF00568D)
                        : Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userStreamSubscription.cancel();
    super.dispose();
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
      nextPage = const MyEnrolledClasses(); // ADD THIS
      break;
    case 3:
      nextPage = const JournalPage();
      break;
    case 4:
      nextPage = const ProgressTrackerPage(); // This was case 3, now case 4
      break;
    case 5:
      // Already on ProfilePage
      return;
    default:
      return;
  }

  Navigator.pushReplacement(
    context,
    _createSlidingPageRoute(
      page: nextPage,
      newIndex: index,
      oldIndex: oldNavIndex,
      duration: const Duration(
        milliseconds: 300,
      ),
    ),
  );
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
  Widget _buildInfoTile(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00568D),
              ),
            ),
            Expanded(
              child: Text(
                value ?? '-',
                style: const TextStyle(fontSize: 16, color: Color(0xFF2973B2)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final bool isDeleteAccount = title == 'Delete Account';
    final Color tileColor = isDeleteAccount
        ? Colors.red.shade700
        : const Color(0xFF00568D);
    final Color iconColor = isDeleteAccount
        ? Colors.red.shade700
        : const Color(0xFF00568D);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: tileColor,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: tileColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenContainerSettingsItem({
    required String title,
    required IconData icon,
    required Widget Function(BuildContext) openPageBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 450),
        openBuilder: (BuildContext context, VoidCallback _) {
          return openPageBuilder(context);
        },
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        closedElevation: 0,
        closedColor: Colors.white,
        openColor: Theme.of(context).cardColor,
        middleColor: Colors.white,
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF00568D), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF00568D),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF00568D),
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2973B2),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00568D)),
            )
          : ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(overscroll: false),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
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
                      top: false,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF9CA8C7),
                                    width: 4.0,
                                  ),
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
                                      ? (() {
                                          try {
                                            final cleanBase64 =
                                                _cleanBase64String(
                                                  _profilePicBase64!,
                                                );
                                            return MemoryImage(
                                                  base64Decode(cleanBase64),
                                                )
                                                as ImageProvider;
                                          } catch (e) {
                                            _logger.e(
                                              'Error decoding profile picture: $e',
                                            );
                                            return null;
                                          }
                                        })()
                                      : null,
                                  backgroundColor:
                                      _profilePicBase64 == null &&
                                          _profilePicSkipped == true
                                      ? null
                                      : Colors.grey[300],
                                  child:
                                      _profilePicBase64 == null &&
                                          _profilePicSkipped == true
                                      ? Icon(
                                          Icons.person,
                                          size: 70,
                                          color: Colors.grey[600],
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2973B2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _pickAndUploadProfilePic,
                                    borderRadius: BorderRadius.circular(50),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _firstName != null && _lastName != null
                                    ? '$_firstName $_lastName'
                                    : 'User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: _showEditNameDialog,
                              ),
                            ],
                          ),
                          if (_email != null)
                            Text(
                              _email!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Settings tiles in a modern list
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ), // Add vertical padding for shadow visibility
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildOpenContainerSettingsItem(
                          title: 'My Information',
                          icon: Icons.info_outline,
                          openPageBuilder: (context) {
                            return Scaffold(
                              backgroundColor: const Color(0xFFF4F8FE),
                              appBar: PreferredSize(
                                preferredSize: const Size.fromHeight(60),
                                child: AppBar(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.95,
                                  ),
                                  elevation: 4,
                                  centerTitle: true,
                                  title: const Text(
                                    'My Information',
                                    style: TextStyle(
                                      color: Color(0xFF00568D),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  leading: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      color: Color(0xFF00568D),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  actions: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Color(0xFF00568D),
                                      ),
                                      tooltip: 'Edit',
                                      onPressed: () {
                                        showGeneralDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          barrierLabel: "Edit Info",
                                          transitionDuration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          pageBuilder: (context, anim1, anim2) {
                                            return const SizedBox.shrink();
                                          },
                                          transitionBuilder: (context, anim1, anim2, child) {
                                            final firstNameController =
                                                TextEditingController(
                                                  text: _firstName ?? '',
                                                );
                                            final lastNameController =
                                                TextEditingController(
                                                  text: _lastName ?? '',
                                                );
                                            final ageController =
                                                TextEditingController(
                                                  text: _age ?? '',
                                                );
                                            final genderController =
                                                TextEditingController(
                                                  text: _gender ?? '',
                                                );
                                            final birthdateController =
                                                TextEditingController(
                                                  text: _birthdate ?? '',
                                                );
                                            final provinceController =
                                                TextEditingController(
                                                  text: _province ?? '',
                                                );
                                            final municipalityController =
                                                TextEditingController(
                                                  text: _municipality ?? '',
                                                );
                                            final barangayController =
                                                TextEditingController(
                                                  text: _barangay ?? '',
                                                );

                                            return Transform.scale(
                                              scale: anim1.value,
                                              child: Opacity(
                                                opacity: anim1.value,
                                                child: Center(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          28,
                                                        ),
                                                    child: BackdropFilter(
                                                      filter: ImageFilter.blur(
                                                        sigmaX: 8,
                                                        sigmaY: 8,
                                                      ),
                                                      child: Container(
                                                        width:
                                                            MediaQuery.of(
                                                              context,
                                                            ).size.width *
                                                            0.92,
                                                        padding:
                                                            const EdgeInsets.all(
                                                              24,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                0.92,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                28,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                    0.08,
                                                                  ),
                                                              blurRadius: 24,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    8,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Material(
                                                          color: Colors
                                                              .transparent,
                                                          child: SingleChildScrollView(
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                const Text(
                                                                  'Edit My Information',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        22,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Color(
                                                                      0xFF00568D,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 18,
                                                                ),
                                                                _modernTextField(
                                                                  'First Name',
                                                                  firstNameController,
                                                                ),
                                                                _modernTextField(
                                                                  'Last Name',
                                                                  lastNameController,
                                                                ),
                                                                _modernTextField(
                                                                  'Age',
                                                                  ageController,
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .number,
                                                                ),
                                                                _modernTextField(
                                                                  'Gender',
                                                                  genderController,
                                                                ),
                                                                _modernTextField(
                                                                  'Birthdate (YYYY-MM-DD)',
                                                                  birthdateController,
                                                                ),
                                                                _modernTextField(
                                                                  'Province',
                                                                  provinceController,
                                                                ),
                                                                _modernTextField(
                                                                  'Municipality',
                                                                  municipalityController,
                                                                ),
                                                                _modernTextField(
                                                                  'Barangay',
                                                                  barangayController,
                                                                ),
                                                                const SizedBox(
                                                                  height: 18,
                                                                ),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .end,
                                                                  children: [
                                                                    TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            context,
                                                                          ),
                                                                      style: TextButton.styleFrom(
                                                                        foregroundColor:
                                                                            const Color(
                                                                              0xFF00568D,
                                                                            ),
                                                                      ),
                                                                      child: const Text(
                                                                        'Cancel',
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            const Color(
                                                                              0xFF00568D,
                                                                            ),
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                        ),
                                                                        elevation:
                                                                            0,
                                                                      ),
                                                                      onPressed: () async {
                                                                        final user = FirebaseAuth
                                                                            .instance
                                                                            .currentUser;
                                                                        if (user !=
                                                                            null) {
                                                                          await FirebaseFirestore
                                                                              .instance
                                                                              .collection(
                                                                                'users',
                                                                              )
                                                                              .doc(
                                                                                user.uid,
                                                                              )
                                                                              .update({
                                                                                'firstName': firstNameController.text.trim(),
                                                                                'lastName': lastNameController.text.trim(),
                                                                                'age': int.tryParse(
                                                                                  ageController.text.trim(),
                                                                                ),
                                                                                'gender': genderController.text.trim(),
                                                                                'birthdate': birthdateController.text.trim(),
                                                                                'province': provinceController.text.trim(),
                                                                                'municipality': municipalityController.text.trim(),
                                                                                'barangay': barangayController.text.trim(),
                                                                              });
                                                                        }
                                                                        if (context
                                                                            .mounted)
                                                                          Navigator.pop(
                                                                            context,
                                                                          );
                                                                      },
                                                                      child: const Text(
                                                                        'Save',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              body: ListView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                children: [
                                  _buildInfoTile('First Name', _firstName),
                                  _buildInfoTile('Last Name', _lastName),
                                  _buildInfoTile('Age', _age),
                                  _buildInfoTile('Gender', _gender),
                                  _buildInfoTile('Birthdate', _birthdate),
                                  _buildInfoTile('Province', _province),
                                  _buildInfoTile('Municipality', _municipality),
                                  _buildInfoTile('Barangay', _barangay),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10), // <-- Add this gap
                        _buildOpenContainerSettingsItem(
                          title: 'FAQ & Support',
                          icon: Icons.quiz_outlined,
                          openPageBuilder: (context) => const FaqAndSupport(),
                        ),
                        const SizedBox(height: 10), // <-- Add this gap
                        _buildOpenContainerSettingsItem(
                          title: 'Community Guidelines',
                          icon: Icons.group_outlined,
                          openPageBuilder: (context) =>
                              const CommunityGuidelines(),
                        ),
                        const SizedBox(height: 10), // <-- Add this gap
                        _buildOpenContainerSettingsItem(
                          title: 'About Us',
                          icon: Icons.info_outline,
                          openPageBuilder: (context) => const AboutUs(),
                        ),
                        const SizedBox(height: 10), // <-- Add this gap
                        _buildOpenContainerSettingsItem(
                          title: 'Terms of Service',
                          icon: Icons.description_outlined,
                          openPageBuilder: (context) => const TermsOfService(),
                        ),
                        const SizedBox(height: 10), // <-- Add this gap
                        _buildSettingsTile(
                          title: 'Sign Out',
                          icon: Icons.logout,
                          onTap: () async {
                            final shouldSignOut = await showDialog<bool>(
                              context: context,
                              builder: (context) => _buildCustomDialog(
                                context: context,
                                title: 'Sign Out',
                                content: 'Are you sure you want to sign out?',
                                cancelText: 'Cancel',
                                confirmText: 'Sign Out',
                                onConfirm: () => Navigator.pop(context, true),
                              ),
                            );
                            if (shouldSignOut == true && mounted) {
                              await _signOut(context);
                            }
                          },
                        ),
                        const SizedBox(height: 10), // <-- Add this gap
                        _buildSettingsTile(
                          title: 'Delete Account',
                          icon: Icons.delete_forever_outlined,
                          onTap: () async {
                            await _deleteAccount(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          bottomNavigationBar: AnimatedBottomNavBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: [
              CustomBottomNavItem(icon: Icons.home, label: 'Home'),
              CustomBottomNavItem(icon: Icons.book, label: 'Courses'),
              CustomBottomNavItem(icon: Icons.school, label: 'My Classes'), // ADD THIS LINE
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

  Widget _modernTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF00568D),
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Color(0xFFF4F8FE),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFBFD7ED)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF00568D), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
