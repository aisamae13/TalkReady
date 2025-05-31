import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'ClassListItem.dart'; // Assuming ClassListItemWidget is in this file
// import 'CreateClassForm.dart'; // For navigation to create class page

// Assumed Firebase Service functions (implement these)
Future<List<Map<String, dynamic>>> getTrainerClassesFromService(String trainerId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('classes')
      .where('trainerId', isEqualTo: trainerId)
      .orderBy('createdAt', descending: true) // Query with filter and order
      .get();
  return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
}

Future<void> deleteClassFromService(String classId) async {
  // Add any related cleanup logic here (e.g., deleting associated materials, assessments, enrollments)
  // This can get complex and might be better handled by a Cloud Function for atomicity.
  await FirebaseFirestore.instance.collection('classes').doc(classId).delete();
}


class MyClassesPage extends StatefulWidget {
  const MyClassesPage({Key? key}) : super(key: key);

  @override
  _MyClassesPageState createState() => _MyClassesPageState();
}

class _MyClassesPageState extends State<MyClassesPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _filteredClasses = [];
  bool _loading = true;
  String? _error;
  // ThemeData? _theme; // Store theme

  @override
  void initState() {
    super.initState();
    // _theme = Theme.of(context); // Initialize theme in didChangeDependencies or build
    if (_currentUser != null) {
      _fetchClasses();
    } else {
      setState(() {
        _loading = false;
        _error = "Please log in to view your classes.";
      });
    }
    _searchController.addListener(_filterClasses);
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _theme ??= Theme.of(context); // Initialize theme here if not already
  // }

  Future<void> _fetchClasses() async {
    if (_currentUser == null) {
      setState(() {
        _error = "Authentication required. Please log in.";
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classesData = await getTrainerClassesFromService(_currentUser!.uid);
      setState(() {
        _classes = classesData;
        _filterClasses();
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load classes: ${e.toString()}";
        _classes = [];
        _filteredClasses = [];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _filterClasses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredClasses = List.from(_classes);
      } else {
        _filteredClasses = _classes.where((classItem) {
          final className = classItem['className']?.toString().toLowerCase() ?? '';
          final subject = classItem['subject']?.toString().toLowerCase() ?? '';
          // Add other searchable fields if necessary
          return className.contains(query) || subject.contains(query);
        }).toList();
      }
    });
  }

  // New method to clear the search field
  void _clearSearchField() {
    _searchController.clear(); // This will trigger the listener which calls _filterClasses
    // Call setState to rebuild the UI and update the suffixIcon
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleDeleteClass(String classId, String className) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the class "$className"? This action cannot be undone and may affect enrolled students and associated content.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _loading = true); // Show loading indicator during delete
      try {
        await deleteClassFromService(classId);
        // Refresh classes list
        await _fetchClasses();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Class "$className" deleted successfully.'), backgroundColor: Colors.green),
        );
      } catch (e) {
        setState(() => _error = "Failed to delete class: ${e.toString()}");
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete class "$className": ${e.toString()}'), backgroundColor: Colors.red),
        );
      } finally {
         if (mounted) {
           setState(() => _loading = false);
         }
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClasses);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme here for build method access

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Classes"),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text("My Classes"),
        actions: [
           IconButton(
            icon: const Icon(FontAwesomeIcons.arrowsRotate),
            onPressed: _loading ? null : _fetchClasses,
            tooltip: "Refresh Classes",
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search classes by name or subject...",
                prefixIcon: Icon(FontAwesomeIcons.magnifyingGlass, color: theme.colorScheme.onSurfaceVariant),
                // Add the clear button as a suffixIcon
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearchField,
                        tooltip: "Clear Search",
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
              ),
              style: TextStyle(color: theme.colorScheme.onSurface),
              onChanged: (_) {
                // _filterClasses(); // Listener already handles this.
                // Call setState if only to update the suffix icon visibility immediately on text change.
                // The listener will handle filtering, this setState is for the icon.
                if (mounted) {
                  setState(() {});
                }
              }
            ),
          ),
          if (_error != null)
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: $_error", style: TextStyle(color: Theme.of(context).colorScheme.error)))))
          else if (_classes.isEmpty)
             _buildEmptyState()
          else if (_filteredClasses.isEmpty && _searchController.text.isNotEmpty)
            _buildNoResultsState()
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchClasses,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  itemCount: _filteredClasses.length,
                  itemBuilder: (context, index) {
                    final classData = _filteredClasses[index];
                    // Assuming ClassListItemWidget is correctly defined and imported
                    return ClassListItemWidget(
                      classData: classData,
                      onDeleteClass: _handleDeleteClass,
                      // onNavigateToDashboard: (classId) {
                      //   Navigator.pushNamed(context, '/trainer/class/$classId/dashboard');
                      // },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(FontAwesomeIcons.plus),
        label: const Text('New Class'),
        onPressed: () {
          Navigator.pushNamed(context, '/trainer/create-class').then((_) {
            // Refresh classes if a new class might have been created
            _fetchClasses();
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const FaIcon(FontAwesomeIcons.chalkboardUser, size: 60, color: Colors.grey),
              const SizedBox(height: 20),
              Text(
                'No Classes Found',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "You haven't created any classes yet. Tap the '+' button to get started!",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.plusCircle),
                label: const Text('Create Your First Class'),
                onPressed: () {
                   Navigator.pushNamed(context, '/trainer/create-class').then((_) {
                      _fetchClasses();
                   });
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const FaIcon(FontAwesomeIcons.folderOpen, size: 60, color: Colors.grey),
              const SizedBox(height: 20),
              Text(
                'No Classes Match Your Search',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Try adjusting your search term or clear the search to see all your classes.",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
               const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.xmark),
                label: const Text('Clear Search'),
                onPressed: () {
                   _searchController.clear();
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(FontAwesomeIcons.triangleExclamation, size: 60, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                'Something Went Wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.refresh),
                label: const Text('Retry'),
                onPressed: _fetchClasses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}