import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:talkready_mobile/settings/about_us.dart';
import 'package:talkready_mobile/settings/comm_guide.dart';
import 'package:talkready_mobile/settings/faq_support.dart';
import 'package:talkready_mobile/settings/terms_of_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Logger _logger = Logger();
  bool _isLoading = false; // Para sa loading indicator

  // Sign out function
  Future<void> _signOut(BuildContext context) async {
  try {
    _logger.i('Attempting to sign out user');
    await FirebaseAuth.instance.signOut();
    _logger.i('User signed out successfully');
    if (Navigator.canPop(context)) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } else {
      _logger.w('Unable to navigate to landing page: Navigator stack is empty');
    }
  } catch (e) {
    _logger.e('Error signing out: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error signing out: $e')),
    );
  }
}

  // Re-authenticate user
Future<bool> _reauthenticateUser(BuildContext context) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  String password = '';
  bool? result;
  if (mounted) {
    result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
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
                      'Re-authenticate',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00568D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Please enter your password to proceed with account deletion.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      autofocus: true,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF00568D), width: 2.0),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          password = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.grey[800],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                          onPressed: password.isNotEmpty ? () => Navigator.pop(dialogContext, true) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00568D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: const Text(
                            'Confirm',
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
  }

  if (result != true) return false;

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger.w('No user found for re-authentication');
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('No user found for re-authentication')),
      );
      return false;
    }

    // I-check ang provider ng user
    bool isGoogleUser = false;
    for (var provider in user.providerData) {
      if (provider.providerId == 'google.com') {
        isGoogleUser = true;
        break;
      }
    }

    if (isGoogleUser) {
      // Re-authenticate gamit ang Google Sign-In
      _logger.i('Re-authenticating user with Google Sign-In');
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the Google Sign-In
        _logger.w('Google Sign-In cancelled by user');
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Google Sign-In cancelled')),
        );
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      _logger.i('User re-authenticated successfully with Google');
      return true;
    } else {
      // Re-authenticate gamit ang email/password
      if (user.email == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('User email not found')),
        );
        return false;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      _logger.i('User re-authenticated successfully with email/password');
      return true;
    }
  } catch (e) {
    _logger.e('Error re-authenticating: $e');
    String errorMessage = 'Error re-authenticating: $e';

    if (e.toString().contains('invalid-credential')) {
      errorMessage = 'The credentials provided are incorrect. Please try again.';
    } else if (e.toString().contains('user-mismatch')) {
      errorMessage = 'User mismatch error. Please sign in again.';
    } else if (e.toString().contains('user-not-found')) {
      errorMessage = 'User not found. Please sign in again.';
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
    return false;
  }
}

   Future<void> _deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // First confirmation dialog
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
          // Second confirmation dialog with text input
          final finalConfirmation = await showDialog<bool>(
            context: context,
            builder: (context) {
              String inputText = '';
              return StatefulBuilder(
                builder: (context, setState) {
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
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            onChanged: (value) {
                              setState(() {
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
                                      horizontal: 20, vertical: 10),
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
                                  backgroundColor: inputText.toLowerCase() == 'confirm'
                                      ? const Color(0xFF00568D)
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
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
            // Delete Firestore data
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .delete();
            _logger.i('Firestore data deleted for UID: ${user.uid}');
            // Delete Firebase Auth account
            await user.delete();
            _logger.i('User account deleted successfully');
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            }
          }
        }
      }
    } catch (e) {
      _logger.e('Error deleting account: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
  }


  // Custom AlertDialog widget
  Widget _buildCustomDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String cancelText,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
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
                        horizontal: 20, vertical: 10),
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
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00568D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF00568D)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00568D),
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
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFF2973B2),
            title: const Text(
              'Settings',
              style: TextStyle(color: Colors.white),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              _buildSettingsOption(
                context,
                title: 'Terms of Service',
                icon: Icons.description,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TermsOfService()),
                  );
                },
              ),
              _buildSettingsOption(
                context,
                title: 'Community Guidelines',
                icon: Icons.group,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CommunityGuidelines()),
                  );
                },
              ),
              _buildSettingsOption(
                context,
                title: 'FAQ & Support',
                icon: Icons.help,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FaqAndSupport()),
                  );
                },
              ),
              _buildSettingsOption(
                context,
                title: 'About Us',
                icon: Icons.info,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutUs()),
                  );
                },
              ),
              _buildSettingsOption(
                context,
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

                  if (shouldSignOut == true && context.mounted) {
                    await _signOut(context);
                  }
                },
              ),
              _buildSettingsOption(
                context,
                title: 'Delete Account',
                icon: Icons.delete_forever,
                onTap: () async {
                  await _deleteAccount(context);
                },
              ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.lightBlue[100]?.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF00568D)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF00568D),
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Color(0xFF2973B2), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
