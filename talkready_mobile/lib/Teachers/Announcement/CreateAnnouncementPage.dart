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
  // String? _selectedClassName; // Not strictly needed if only ID is used for posting

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isPosting = false;
  String? _postError;
  String? _postSuccess;

  bool _loadingClasses = true;
  String? _classesError;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Announcement"),
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FontAwesomeIcons.userLock, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              "Authentication Required",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _classesError ?? "You must be logged in to create announcements.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            // Optionally add a login button if you have a way to trigger login
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String error, IconData icon, {VoidCallback? onRetry}) {
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.rotateRight),
                label: const Text("Retry"),
                onPressed: onRetry,
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
                prefixIcon: const Icon(FontAwesomeIcons.chalkboardUser),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              value: _selectedClassId,
              hint: const Text("-- Choose a Class --"),
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
                prefixIcon: const Icon(FontAwesomeIcons.heading),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                prefixIcon: const Icon(FontAwesomeIcons.alignLeft),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                alignLabelWithHint: true,
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
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    const Icon(FontAwesomeIcons.exclamationTriangle, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_postError!, style: const TextStyle(color: Colors.red, fontSize: 14))),
                  ],
                ),
              ),
            if (_postSuccess != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                 child: Row(
                  children: [
                    const Icon(FontAwesomeIcons.checkCircle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_postSuccess!, style: const TextStyle(color: Colors.green, fontSize: 14))),
                  ],
                ),
              ),
            ElevatedButton.icon(
              icon: _isPosting
                  ? Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(FontAwesomeIcons.paperPlane, size: 16),
              label: Text(_isPosting ? 'Posting...' : 'Post Announcement'),
              onPressed: _isPosting || _trainerClasses.isEmpty ? null : _handlePostAnnouncement,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}