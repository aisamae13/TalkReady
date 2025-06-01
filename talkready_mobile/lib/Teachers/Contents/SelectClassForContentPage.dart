import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Add the getTrainerClasses function definition here:
Future<List<Map<String, dynamic>>> getTrainerClasses(String trainerId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('createdAt', descending: true) // Changed to createdAt, descending
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  } catch (e) {
    // print("Error fetching trainer classes: $e");
    // Consider logging the error to a proper logging service
    throw Exception("Failed to load classes: ${e.toString()}");
  }
}


class SelectClassForContentPage extends StatefulWidget {
  const SelectClassForContentPage({super.key});

  @override
  _SelectClassForContentPageState createState() =>
      _SelectClassForContentPageState();
}

class _SelectClassForContentPageState extends State<SelectClassForContentPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _trainerClasses = [];
  bool _loadingClasses = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _fetchClasses();
    } else {
      setState(() {
        _loadingClasses = false;
        _error = "Please log in to manage content.";
      });
    }
  }

  Future<void> _fetchClasses() async {
    if (_currentUser == null) return;
    setState(() {
      _loadingClasses = true;
      _error = null;
    });
    try {
      // Assuming getTrainerClasses is accessible here
      final classes = await getTrainerClasses(_currentUser.uid);
      if (mounted) {
        // Sort classes by name
        classes.sort((a, b) =>
            (a['className']?.toString() ?? '')
                .compareTo(b['className']?.toString() ?? ''));
        setState(() {
          _trainerClasses = classes;
          if (classes.isEmpty) {
            _error = "You haven't created any classes yet. Create a class to manage its content.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load your classes: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingClasses = false;
        });
      }
    }
  }

  void _handleClassSelect(String classId, String className) {
    // TODO: Navigate to the specific class content management page
    // Example: Navigator.pushNamed(context, '/trainer/class/$classId/content/manage', arguments: {'className': className});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Navigate to manage content for: $className (ID: $classId) - Not Implemented Yet")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Manage Content"),
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D5DF6), Color(0xFF46C2CB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFF), Color(0xFFE3F0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);

    if (_currentUser == null) {
      return _buildErrorWidget(_error ?? "Authentication required.", FontAwesomeIcons.userLock);
    }
    if (_loadingClasses) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _trainerClasses.isEmpty) {
      return _buildErrorWidget(
        _error!,
        FontAwesomeIcons.exclamationTriangle,
        showCreateClassButton: _error!.contains("Create a class"),
        onRetry: _fetchClasses,
      );
    }
    if (_trainerClasses.isEmpty) {
      return _buildErrorWidget(
        "No classes found.",
        FontAwesomeIcons.bookOpen,
        showCreateClassButton: true,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24.0),
      itemCount: _trainerClasses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final cls = _trainerClasses[index];
        final className = cls['className'] as String? ?? 'Unnamed Class';
        final studentCount = cls['studentCount'] ?? 0;

        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.white.withOpacity(0.90),
          shadowColor: theme.colorScheme.primary.withOpacity(0.10),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _handleClassSelect(cls['id'] as String, className),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.13),
                    child: FaIcon(FontAwesomeIcons.chalkboardUser, color: theme.colorScheme.primary, size: 26),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          className,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "$studentCount student${studentCount != 1 ? 's' : ''}",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String message, IconData icon, {bool showCreateClassButton = false, VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FaIcon(icon, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.rotateRight),
                label: const Text("Retry"),
                onPressed: onRetry,
              )
            ],
            if (showCreateClassButton) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.plusCircle),
                label: const Text("Create a Class"),
                onPressed: () {
                  Navigator.pushNamed(context, '/trainer/classes/create'); // Adjust if your route is different
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}