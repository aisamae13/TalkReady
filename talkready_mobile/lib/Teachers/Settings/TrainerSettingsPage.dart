import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../firebase_service.dart';
import 'TrainerSignatureUpload.dart';

class TrainerSettingsPage extends StatefulWidget {
  const TrainerSettingsPage({super.key});

  @override
  State<TrainerSettingsPage> createState() => _TrainerSettingsPageState();
}

class _TrainerSettingsPageState extends State<TrainerSettingsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  Map<String, dynamic>? _trainerProfile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (_currentUser == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final profile = await _firebaseService.getUserProfileById(
        _currentUser!.uid,
      );
      setState(() {
        _trainerProfile = profile;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading profile: $e");
      setState(() => _loading = false);
    }
  }

  void _handleSignatureUpdate(String? signatureUrl, String? signaturePath) {
    setState(() {
      if (_trainerProfile != null) {
        _trainerProfile!['trainerSignature'] = signatureUrl;
        _trainerProfile!['trainerSignaturePath'] = signaturePath;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Trainer Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const FaIcon(
                            FontAwesomeIcons.userGear,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _trainerProfile?['displayName'] ??
                                    '${_trainerProfile?['firstName'] ?? ''} ${_trainerProfile?['lastName'] ?? ''}'
                                        .trim(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _trainerProfile?['email'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Signature Upload Section
                  TrainerSignatureUpload(
                    currentSignature: _trainerProfile?['trainerSignature'],
                    currentSignaturePath:
                        _trainerProfile?['trainerSignaturePath'],
                    onSignatureUpdate: _handleSignatureUpdate,
                    trainerId: _currentUser!.uid,
                  ),

                  const SizedBox(height: 24),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade50, Colors.blue.shade50],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.purple.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About Your Signature',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your signature will appear on all certificates you authorize for your students. '
                                'This adds a professional and personal touch to their achievements.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.purple.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ],
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
}
