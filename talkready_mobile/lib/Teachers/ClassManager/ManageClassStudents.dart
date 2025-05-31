import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

// --- Data Models (Simplified) ---
class ClassDetails {
  final String id;
  final String className;
  final String trainerId;
  final int studentCount;

  ClassDetails({required this.id, required this.className, required this.trainerId, required this.studentCount});

  factory ClassDetails.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ClassDetails(
      id: doc.id,
      className: data['className'] ?? 'Unnamed Class',
      trainerId: data['trainerId'] ?? '',
      studentCount: data['studentCount'] ?? 0,
    );
  }
}

class EnrolledStudent {
  final String id; // Enrollment document ID
  final String studentId; // User UID
  final String studentName;
  final String studentEmail;
  final Timestamp enrolledAt;

  EnrolledStudent({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.enrolledAt,
  });

  factory EnrolledStudent.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return EnrolledStudent(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'N/A',
      studentEmail: data['studentEmail'] ?? 'N/A',
      enrolledAt: data['enrolledAt'] ?? Timestamp.now(),
    );
  }
}

class UserSearchResult {
  final String uid;
  final String? displayName;
  final String? email;
  // Add other fields like firstName, lastName if available and needed

  UserSearchResult({required this.uid, this.displayName, this.email});

  factory UserSearchResult.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserSearchResult(
      uid: doc.id,
      displayName: data['displayName'] ?? data['firstName'] ?? 'Unnamed User', // Adapt as per your user structure
      email: data['email'] ?? '',
    );
  }
}


// --- Assumed Firebase Service Functions (Implement these) ---
Future<ClassDetails> fetchClassDetailsFromService(String classId) async {
  final doc = await FirebaseFirestore.instance.collection('classes').doc(classId).get();
  if (!doc.exists) throw Exception("Class not found");
  return ClassDetails.fromFirestore(doc);
}

Future<List<EnrolledStudent>> fetchEnrolledStudentsFromService(String classId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('enrollments') // Assuming 'enrollments' collection
      .where('classId', isEqualTo: classId)
      .get();
  return snapshot.docs.map((doc) => EnrolledStudent.fromFirestore(doc)).toList();
}

Future<List<UserSearchResult>> searchUsersByEmailFromService(String email) async {
  // This is a simplified search. Firestore doesn't support partial string matches directly for security reasons.
  // You might need a more sophisticated backend search (e.g., Algolia, or a Cloud Function).
  // For direct client-side, exact match is more feasible or searching by a known field.
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email.trim())
      .where('userType', isEqualTo: 'student') // Assuming userType field
      .get();
  return snapshot.docs.map((doc) => UserSearchResult.fromFirestore(doc)).toList();
}

Future<DocumentReference> enrollStudentInClassService(String classId, String studentId, String studentName, String studentEmail, String trainerId) async {
  // This should also update the studentCount in the 'classes' collection, ideally via a transaction or Cloud Function.
  final enrollmentRef = await FirebaseFirestore.instance.collection('enrollments').add({
    'classId': classId,
    'studentId': studentId,
    'studentName': studentName,
    'studentEmail': studentEmail,
    'trainerId': trainerId,
    'enrolledAt': FieldValue.serverTimestamp(),
  });
  // Increment student count
  await FirebaseFirestore.instance.collection('classes').doc(classId).update({
    'studentCount': FieldValue.increment(1),
  });
  return enrollmentRef;
}

Future<void> removeStudentFromClassService(String enrollmentId, String classId) async {
  // This should also decrement the studentCount in the 'classes' collection.
  await FirebaseFirestore.instance.collection('enrollments').doc(enrollmentId).delete();
  // Decrement student count
  await FirebaseFirestore.instance.collection('classes').doc(classId).update({
    'studentCount': FieldValue.increment(-1),
  });
}


class ManageClassStudentsPage extends StatefulWidget {
  final String classId;

  const ManageClassStudentsPage({Key? key, required this.classId}) : super(key: key);

  @override
  _ManageClassStudentsPageState createState() => _ManageClassStudentsPageState();
}

class _ManageClassStudentsPageState extends State<ManageClassStudentsPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();

  ClassDetails? _classDetails;
  List<EnrolledStudent> _enrolledStudents = [];
  List<UserSearchResult> _searchResults = [];

  bool _isLoading = true;
  String? _error;
  String? _actionError; // For add/remove/search actions
  bool _isSearching = false;
  String? _enrollingStudentId;
  String? _removingEnrollmentId;

  @override
  void initState() {
    super.initState();
    _fetchClassAndStudentData();
    // Add listener to rebuild suffix icon if text changes (optional, direct check in build is also fine)
    // _searchController.addListener(() {
    //   if (mounted) setState(() {});
    // });
  }

  Future<void> _fetchClassAndStudentData({bool showLoading = true}) async {
    if (_currentUser == null) {
      setState(() {
        _error = "Authentication required.";
        _isLoading = false;
      });
      return;
    }
    if (showLoading) setState(() => _isLoading = true);
    _error = null;
    _actionError = null;

    try {
      final details = await fetchClassDetailsFromService(widget.classId);
      if (details.trainerId != _currentUser!.uid) {
        setState(() {
          _error = "You are not authorized to manage students for this class.";
          _classDetails = null;
          _enrolledStudents = [];
          _isLoading = false;
        });
        return;
      }
      final students = await fetchEnrolledStudentsFromService(widget.classId);
      students.sort((a, b) => a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));

      setState(() {
        _classDetails = details;
        _enrolledStudents = students;
      });
    } catch (e) {
      setState(() => _error = "Failed to load data: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSearchStudents() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      setState(() {
        _searchResults = [];
        _actionError = "Please enter an email to search.";
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _actionError = null;
      _searchResults = [];
    });
    try {
      final users = await searchUsersByEmailFromService(searchTerm);
      final enrolledStudentUids = _enrolledStudents.map((s) => s.studentId).toSet();
      // Assuming UserSearchResult has a userType field or similar to filter only students
      final filteredResults = users.where((user) => !enrolledStudentUids.contains(user.uid)).toList();

      setState(() {
        _searchResults = filteredResults;
        if (filteredResults.isEmpty) {
          _actionError = 'No new students found for "$searchTerm". Ensure email is correct and user is registered as a student.';
        }
      });
    } catch (e) {
      setState(() {
        _actionError = "Search failed: ${e.toString()}";
        _searchResults = [];
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _handleEnrollStudent(UserSearchResult studentToEnroll) async {
    if (_classDetails == null || _currentUser == null) {
      setState(() => _actionError = "Cannot enroll: Class/trainer info missing.");
      return;
    }
    if (_enrollingStudentId == studentToEnroll.uid) return;

    setState(() => _enrollingStudentId = studentToEnroll.uid);
    _actionError = null;

    try {
      final newEnrollmentRef = await enrollStudentInClassService(
        widget.classId,
        studentToEnroll.uid,
        studentToEnroll.displayName ?? "Student",
        studentToEnroll.email ?? "",
        _currentUser!.uid,
      );

      // Optimistically update UI or re-fetch
      // For simplicity, re-fetching all data to ensure consistency
      await _fetchClassAndStudentData(showLoading: false);
      setState(() {
         _searchResults.removeWhere((s) => s.uid == studentToEnroll.uid);
         _searchController.clear(); // Optionally clear search
      });

    } catch (e) {
      setState(() => _actionError = "Enrollment failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _enrollingStudentId = null);
    }
  }

  Future<void> _handleRemoveStudent(EnrolledStudent enrollment) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Are you sure you want to remove ${enrollment.studentName} from the class?'),
        actions: <Widget>[
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(child: const Text('Remove'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    if (_removingEnrollmentId == enrollment.id) return;

    setState(() => _removingEnrollmentId = enrollment.id);
    _actionError = null;

    try {
      await removeStudentFromClassService(enrollment.id, widget.classId);
      // Optimistically update UI or re-fetch
      await _fetchClassAndStudentData(showLoading: false);
    } catch (e) {
      setState(() => _actionError = "Removal failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _removingEnrollmentId = null);
    }
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
  }

  // New method to clear search field and results
  void _clearSearchFieldAndResults() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _actionError = null; // Clear previous search errors
      _isSearching = false; // Ensure searching state is reset
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_classDetails?.className ?? "Manage Students"),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.arrowsRotate),
            onPressed: _isLoading ? null : () => _fetchClassAndStudentData(),
            tooltip: "Refresh Data",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: $_error", style: TextStyle(color: Theme.of(context).colorScheme.error))))
              : _classDetails == null
                  ? const Center(child: Text("Class details not available."))
                  : RefreshIndicator(
                      onRefresh: () => _fetchClassAndStudentData(showLoading: false),
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          // Add Students Section
                          _buildAddStudentSection(),
                          const SizedBox(height: 24),
                          // Enrolled Students Section
                          _buildEnrolledStudentsSection(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildAddStudentSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Add New Student", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_actionError != null && !_actionError!.toLowerCase().contains("removal failed"))
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(_actionError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: "Student Email",
                      prefixIcon: const Icon(FontAwesomeIcons.envelope),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearchFieldAndResults,
                              tooltip: "Clear Search",
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isSearching,
                    onChanged: (_) {
                      // Trigger rebuild to show/hide clear button if not using a listener
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: _isSearching ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FontAwesomeIcons.magnifyingGlass),
                  label: const Text("Search"),
                  onPressed: _isSearching ? null : _handleSearchStudents,
                ),
              ],
            ),
            if (_isSearching) const Padding(padding: EdgeInsets.all(8.0), child: Center(child: Text("Searching..."))),
            if (!_isSearching && _searchResults.isNotEmpty)
              _buildSearchResultsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text("Search Results:", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final user = _searchResults[index];
            final bool isCurrentlyEnrolling = _enrollingStudentId == user.uid;
            return ListTile(
              leading: const Icon(FontAwesomeIcons.userGraduate),
              title: Text(user.displayName ?? "N/A"),
              subtitle: Text(user.email ?? "N/A"),
              trailing: ElevatedButton.icon(
                icon: isCurrentlyEnrolling ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(FontAwesomeIcons.userPlus, size: 16),
                label: const Text("Enroll"),
                onPressed: isCurrentlyEnrolling ? null : () => _handleEnrollStudent(user),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnrolledStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Enrolled Students (${_classDetails?.studentCount ?? _enrolledStudents.length})", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
         if (_actionError != null && _actionError!.toLowerCase().contains("removal failed")) // Show removal errors here
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(_actionError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),
        _enrolledStudents.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No students enrolled yet.")))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _enrolledStudents.length,
                itemBuilder: (context, index) {
                  final student = _enrolledStudents[index];
                  final bool isCurrentlyRemoving = _removingEnrollmentId == student.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(student.studentName.isNotEmpty ? student.studentName[0].toUpperCase() : "?")),
                      title: Text(student.studentName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(student.studentEmail),
                           Text("Enrolled: ${_formatTimestamp(student.enrolledAt)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: isCurrentlyRemoving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(FontAwesomeIcons.userMinus, color: Colors.red, size: 20),
                        onPressed: isCurrentlyRemoving ? null : () => _handleRemoveStudent(student),
                        tooltip: "Remove Student",
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}