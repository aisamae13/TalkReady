import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'about_us.dart';
import 'comm_guide.dart';
import 'faq_support.dart';
import 'terms_of_service.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final Logger _logger = Logger();

  // Sign out function
  Future<void> _signOut(BuildContext context) async {
    try {
      _logger.i('Attempting to sign out user');
      await FirebaseAuth.instance.signOut();
      _logger.i('User signed out successfully');
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/landing',
          (route) => false,
        );
      }
    } catch (e) {
      _logger.e('Error signing out: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  // Delete account function
  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
            '/landing',
            (route) => false,
          );
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
    return Scaffold(
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
              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (context) => _buildCustomDialog(
                  context: context,
                  title: 'Delete Account',
                  content:
                      'Are you sure you want to permanently delete your account? This action cannot be undone.',
                  cancelText: 'Cancel',
                  confirmText: 'Delete',
                  onConfirm: () => Navigator.pop(context, true),
                ),
              );

              if (shouldDelete == true && context.mounted) {
                await _deleteAccount(context);
              }
            },
          ),
        ],
      ),
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