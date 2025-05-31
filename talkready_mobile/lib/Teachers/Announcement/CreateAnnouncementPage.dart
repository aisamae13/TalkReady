import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Placeholder for your actual service functions.
// You should move these to a separate services file (e.g., firebase_services.dart)
// and import them.

Future<List<Map<String, dynamic>>> getTrainerClasses(String trainerId) async {
  // In a real app, this would fetch from Firestore.
  // Ensure your 'classes' collection has a 'trainerId' field and
  // you have appropriate indexes if you order by other fields.
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('trainerId', isEqualTo: trainerId)
        // .orderBy('className') // Optional: if you want to sort by name
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  } catch (e) {
    // print("Error fetching trainer classes: $e");
    throw Exception("Failed to load classes: ${e.toString()}");
  }
}

Future<void> postClassAnnouncement({
  required String classId,
  required String title,
  required String content,
  required String trainerId,
  // String? trainerName, // You might want to store the trainer's name too
}) async {
  // In a real app, this would post to Firestore.
  // Example: creating a subcollection 'announcements' under the selected class.
  try {
    await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('announcements')
        .add({
      'title': title,
      'content': content,
      'trainerId': trainerId,
      // 'trainerName': trainerName ?? 'N/A',
      'createdAt': FieldValue.serverTimestamp(),
      // 'recipients': [], // Consider how you manage who sees the announcement
    });
  } catch (e) {
    // print("Error posting announcement: $e");
    throw Exception("Failed to post announcement: ${e.toString()}");
  }
}
// End of placeholder service functions

class CreateAnnouncementPage extends StatefulWidget {
  const CreateAnnouncementPage({Key? key}) : super(key: key);

  @override
  _CreateAnnouncementPageState createState() => _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState extends State<CreateAnnouncementPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _trainerClasses = [];
  String? _selectedClassId;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isPosting = false;
  String? _postError;
  String? _postSuccess;

  bool _loadingClasses = true;
  String? _classesError;

  // ThemeData? _theme;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _fetchTrainerClasses();
    } else {
      setState(() {
        _loadingClasses = false;
        _classesError = "User not logged in. Please log in to create announcements.";
      });
    }
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _theme = Theme.of(context);
  // }

  Future<void> _fetchTrainerClasses() async {
    if (_currentUser == null) return;
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    try {
      final classes = await getTrainerClasses(_currentUser!.uid);
      setState(() {
        _trainerClasses = classes;
        if (_trainerClasses.isNotEmpty) {
          // Optionally pre-select the first class
          // _selectedClassId = _trainerClasses.first['id'];
        } else {
           _classesError = "No classes found. You need to create a class first.";
        }
        _loadingClasses = false;
      });
    } catch (e) {
      setState(() {
        _classesError = e.toString();
        _loadingClasses = false;
      });
    }
  }

  Future<void> _handlePostAnnouncement() async {
    if (_currentUser == null) {
      setState(() {
        _postError = "User not logged in.";
      });
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedClassId == null) {
        setState(() {
          _postError = "Please select a class.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a class."), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() {
        _isPosting = true;
        _postError = null;
        _postSuccess = null;
      });

      try {
        await postClassAnnouncement(
          classId: _selectedClassId!,
          title: _titleController.text,
          content: _contentController.text,
          trainerId: _currentUser!.uid,
        );
        setState(() {
          _postSuccess = "Announcement posted successfully!";
          _titleController.clear();
          _contentController.clear();
          // _selectedClassId = null; // Optionally reset class selection
          // Consider navigating back or showing a success dialog
        });
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Announcement posted!"), backgroundColor: Colors.green),
        );
        // Example: Navigate back after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true); // Pass true to indicate success
          }
        });

      } catch (e) {
        setState(() {
          _postError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      } finally {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text("Create Announcement"),
        backgroundColor: theme.colorScheme.surfaceVariant,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.dividerColor,
            height: 1.0,
          ),
        ),
      ),
      body: _currentUser == null
          ? _buildAuthError()
          : _loadingClasses
              ? _buildLoadingIndicator("Loading classes...")
              : _classesError != null && _trainerClasses.isEmpty
                  ? _buildErrorDisplay(_classesError!, FontAwesomeIcons.listUl, onRetry: _fetchTrainerClasses)
                  : _buildForm(),
    );
  }

  Widget _buildAuthError() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.userLock, size: 54, color: theme.colorScheme.error),
            const SizedBox(height: 20),
            Text(
              "Authentication Required",
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onBackground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _classesError ?? "You must be logged in to create announcements.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            // Optionally add a login button if you have a way to trigger login
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)),
          const SizedBox(height: 20),
          Text(message, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String error, IconData icon, {VoidCallback? onRetry}) {
    final theme = Theme.of(context);
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: theme.colorScheme.error.withOpacity(0.8)),
            const SizedBox(height: 20),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.rotateRight, size: 16),
                label: const Text("Retry"),
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_trainerClasses.isEmpty && _classesError == null)
              _buildErrorDisplay("No classes available. Please create a class first.", FontAwesomeIcons.chalkboardUser),
            
            if (_trainerClasses.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Select Class",
                prefixIcon: Icon(FontAwesomeIcons.chalkboardUser, color: theme.colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              value: _selectedClassId,
              hint: Text("-- Choose a Class --", style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              isExpanded: true,
              items: _trainerClasses.map((Map<String, dynamic> cls) {
                return DropdownMenuItem<String>(
                  value: cls['id'] as String,
                  child: Text(cls['className'] as String? ?? 'Unnamed Class'),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedClassId = newValue;
                  // _selectedClassName = _trainerClasses.firstWhere((c) => c['id'] == newValue)['className'];
                });
              },
              validator: (value) => value == null ? 'Please select a class' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Announcement Title",
                prefixIcon: Icon(FontAwesomeIcons.heading, color: theme.colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: "Announcement Content",
                prefixIcon: Icon(FontAwesomeIcons.alignLeft, color: theme.colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                alignLabelWithHint: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              maxLines: 5,
              minLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter content for the announcement';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (_postError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(FontAwesomeIcons.exclamationTriangle, color: theme.colorScheme.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_postError!, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 14))),
                    ],
                  ),
                ),
              ),
            if (_postSuccess != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
                 child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100, // Consider a theme color
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(FontAwesomeIcons.checkCircle, color: Colors.green.shade700, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_postSuccess!, style: TextStyle(color: Colors.green.shade800, fontSize: 14))),
                    ],
                  ),
                ),
              ),
            ElevatedButton.icon(
              icon: _isPosting
                  ? Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(2.0),
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                    )
                  : const Icon(FontAwesomeIcons.paperPlane, size: 16),
              label: Text(_isPosting ? 'Posting...' : 'Post Announcement'),
              onPressed: _isPosting || _trainerClasses.isEmpty ? null : _handlePostAnnouncement,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}