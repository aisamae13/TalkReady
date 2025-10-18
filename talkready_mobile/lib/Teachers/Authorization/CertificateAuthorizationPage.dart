import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../firebase_service.dart';

class CertificateAuthorizationPage extends StatefulWidget {
  const CertificateAuthorizationPage({super.key});

  @override
  State<CertificateAuthorizationPage> createState() =>
      _CertificateAuthorizationPageState();
}

class _CertificateAuthorizationPageState
    extends State<CertificateAuthorizationPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  List<Map<String, dynamic>> _pendingStudents = [];
  Map<String, dynamic>? _trainerProfile;

  String _filterType = 'all'; // all, new, upgrade

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (_currentUser == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      // Fetch trainer profile (to get signature)
      final profile = await _firebaseService.getUserProfileById(
        _currentUser!.uid,
      );

      // Fetch pending students
      final pending = await _firebaseService.getAuthorizationPendingStudents(
        _currentUser!.uid,
      );

      setState(() {
        _trainerProfile = profile;
        _pendingStudents = pending;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_filterType == 'all') return _pendingStudents;
    if (_filterType == 'new') {
      return _pendingStudents
          .where((s) => s['certificateType'] == 'new')
          .toList();
    }
    if (_filterType == 'upgrade') {
      return _pendingStudents
          .where((s) => s['certificateType'] == 'upgrade')
          .toList();
    }
    return _pendingStudents;
  }

  Future<void> _showAuthorizationDialog(Map<String, dynamic> student) async {
    // Check if trainer has uploaded signature
    if (_trainerProfile?['trainerSignature'] == null) {
      _showNoSignatureDialog();
      return;
    }

    final TextEditingController commentController = TextEditingController();
    bool authorizing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.certificate,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Authorize Certificate',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Info
                    _buildInfoRow('Student', student['studentName'] ?? 'N/A'),
                    _buildInfoRow('Email', student['studentEmail'] ?? 'N/A'),
                    _buildInfoRow('Course', student['courseName'] ?? 'N/A'),
                    _buildInfoRow('Class', student['className'] ?? 'N/A'),

                    const Divider(height: 24),

                    // Performance Data
                    if (student['performanceData'] != null) ...[
                      const Text(
                        'Performance Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPerformanceCard(student['performanceData']),
                      const SizedBox(height: 16),
                    ],

                    // Certificate Type Badge
                    if (student['certificateType'] == 'upgrade') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.upgrade,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This is an upgrade from system-authorized certificate',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Comment Field
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Comment (Optional)',
                        hintText: 'Add a note about this authorization...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Signature Preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Signature',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Image.network(
                              _trainerProfile!['trainerSignature'],
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Text('Failed to load signature');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: authorizing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: authorizing
                      ? null
                      : () async {
                          setState(() => authorizing = true);

                          try {
                            await _firebaseService.authorizeCertificate(
                              student['certificateId'],
                              {
                                'trainerId': _currentUser!.uid,
                                'trainerName':
                                    _trainerProfile?['displayName'] ??
                                    '${_trainerProfile?['firstName']} ${_trainerProfile?['lastName']}'
                                        .trim(),
                                'trainerEmail': _trainerProfile?['email'] ?? '',
                                'trainerSignature':
                                    _trainerProfile!['trainerSignature'],
                                'classId': student['classId'],
                                'className': student['className'],
                                'comment': commentController.text.trim(),
                              },
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Certificate authorized for ${student['studentName']}',
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );

                              // Refresh list
                              _fetchData();
                            }
                          } catch (e) {
                            setState(() => authorizing = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  icon: authorizing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(FontAwesomeIcons.signature, size: 16),
                  label: Text(authorizing ? 'Authorizing...' : 'Authorize'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNoSignatureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Signature Required'),
          ],
        ),
        content: const Text(
          'You need to upload your signature before you can authorize certificates.\n\n'
          'Go to Settings → Upload Signature to add your e-signature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/trainer/settings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(Map<String, dynamic> performance) {
    final double average = (performance['overallAverage'] ?? 0).toDouble();
    final String tier = performance['certificateTier'] ?? 'completion';

    Color tierColor;
    IconData tierIcon;
    String tierLabel;

    switch (tier) {
      case 'excellence':
        tierColor = const Color(0xFF10B981);
        tierIcon = FontAwesomeIcons.trophy;
        tierLabel = 'Excellence';
        break;
      case 'proficiency':
        tierColor = const Color(0xFF3B82F6);
        tierIcon = FontAwesomeIcons.medal;
        tierLabel = 'Proficiency';
        break;
      default:
        tierColor = const Color(0xFF8B5CF6);
        tierIcon = FontAwesomeIcons.certificate;
        tierLabel = 'Completion';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withOpacity(0.1), tierColor.withOpacity(0.05)],
        ),
        border: Border.all(color: tierColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Row 1: Overall Average (centered)
          Column(
            children: [
              Text(
                'Overall Average',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                '${average.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: tierColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Tier Badge (centered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tierColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(tierIcon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  tierLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Row 3: Stats (Lessons & Assessments)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildStatChip(
                  'Lessons',
                  performance['totalLessonsCompleted']?.toString() ?? '0',
                  Icons.book,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  'Assessments',
                  performance['totalAssessmentsCompleted']?.toString() ?? '0',
                  Icons.assignment,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Certificate Authorization',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: Column(
                children: [
                  // Filter Chips
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all', _pendingStudents.length),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'New',
                          'new',
                          _pendingStudents
                              .where((s) => s['certificateType'] == 'new')
                              .length,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Upgrades',
                          'upgrade',
                          _pendingStudents
                              .where((s) => s['certificateType'] == 'upgrade')
                              .length,
                        ),
                      ],
                    ),
                  ),

                  // Student List
                  Expanded(
                    child: _filteredStudents.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              return _buildStudentCard(student);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filterType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final bool isUpgrade = student['certificateType'] == 'upgrade';
    final performance = student['performanceData'] as Map<String, dynamic>?;
    final double average = (performance?['overallAverage'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAuthorizationDialog(student),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                      child: Text(
                        student['studentName']?[0]?.toUpperCase() ?? 'S',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['studentName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student['className'] ?? 'Unknown Class',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUpgrade)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.upgrade,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Upgrade',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Average Score',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${average.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAuthorizationDialog(student),
                      icon: const FaIcon(FontAwesomeIcons.signature, size: 14),
                      label: const Text('Authorize'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.certificate,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Pending Authorizations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All certificates have been authorized',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
