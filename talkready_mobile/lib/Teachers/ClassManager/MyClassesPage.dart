//Trainer

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:talkready_mobile/firebase_service.dart';
import 'ClassListItem.dart';
import 'CreateClassForm.dart';
import 'ManageClassContent.dart';
import '../TrainerClassDashboardPage.dart';

// Keep your existing Firebase service functions unchanged as fallback
Future<List<Map<String, dynamic>>> getTrainerClassesFromService(
  String trainerId,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('trainerClass')
      .where('trainerId', isEqualTo: trainerId)
      .orderBy('createdAt', descending: true)
      .get();
  final list = snapshot.docs
      .map((doc) => {'id': doc.id, ...doc.data()})
      .toList();
  // Ensure we have a robust client-side sort fallback in case createdAt is missing or not comparable
  list.sort((a, b) {
    DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
    DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
    final ca = a['createdAt'];
    final cb = b['createdAt'];
    try {
      if (ca is Timestamp)
        dateA = ca.toDate();
      else if (ca is DateTime)
        dateA = ca;
    } catch (_) {}
    try {
      if (cb is Timestamp)
        dateB = cb.toDate();
      else if (cb is DateTime)
        dateB = cb;
    } catch (_) {}
    // newest first
    return dateB.compareTo(dateA);
  });
  return list;
}

Future<void> deleteClassFromService(String classId) async {
  await FirebaseFirestore.instance
      .collection('trainerClass')
      .doc(classId)
      .delete();
}

class MyClassesPage extends StatefulWidget {
  const MyClassesPage({super.key});

  @override
  _MyClassesPageState createState() => _MyClassesPageState();
}

class _MyClassesPageState extends State<MyClassesPage>
    with TickerProviderStateMixin {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();

  // Use one shared FirebaseService instance for this page
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription<List<Map<String, dynamic>>>? _classesSub;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _filteredClasses = [];
  bool _loading = true;
  String? _error;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Use realtime sync as primary source for logged-in trainers.
    if (_currentUser != null) {
      try {
        // start realtime sync and subscribe to classes stream
        _firebaseService.startRealtimeSync(trainerId: _currentUser!.uid);
        _classesSub = _firebaseService.classesStream.listen(
          (data) {
            if (!mounted) return;
            // robust client-side sort fallback (newest first)
            data.sort((a, b) {
              DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
              DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
              final ca = a['createdAt'];
              final cb = b['createdAt'];
              try {
                if (ca is Timestamp)
                  dateA = ca.toDate();
                else if (ca is DateTime)
                  dateA = ca;
              } catch (_) {}
              try {
                if (cb is Timestamp)
                  dateB = cb.toDate();
                else if (cb is DateTime)
                  dateB = cb;
              } catch (_) {}
              return dateB.compareTo(dateA);
            });

            setState(() {
              _classes = List.from(data);
              _filteredClasses = List.from(_classes);
              _fadeController.forward();
              _slideController.forward();
              _error = null;
              _loading = false;
            });
          },
          onError: (e) {
            if (mounted) setState(() => _error = "Failed to sync classes: $e");
          },
        );
      } catch (e) {
        // If realtime setup fails, fall back to one-shot fetch
        if (mounted) {
          setState(() {
            _error = null;
            _loading = true;
          });
          _fetchClasses();
        }
      }
    } else {
      setState(() {
        _loading = false;
        _error = "Please log in to view your classes.";
      });
    }

    _searchController.addListener(_filterClasses);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.removeListener(_filterClasses);
    _searchController.dispose();
    // cancel realtime subscription and stop sync when leaving page
    _classesSub?.cancel();
    _firebaseService.stopRealtimeSync();
    super.dispose();
  }

  // one-shot fetch (fallback) - still useful for refresh or when realtime fails
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
      final classesData = await getTrainerClassesFromService(_currentUser.uid);
      if (!mounted) return;
      setState(() {
        _classes = classesData;
        _filteredClasses = List.from(_classes);
        _fadeController.forward();
        _slideController.forward();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load classes: ${e.toString()}";
        _classes = [];
        _filteredClasses = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterClasses() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      _filteredClasses = List.from(_classes);
    } else {
      _filteredClasses = _classes.where((classItem) {
        final className =
            classItem['className']?.toString().toLowerCase() ?? '';
        final subject = classItem['subject']?.toString().toLowerCase() ?? '';
        final description =
            classItem['description']?.toString().toLowerCase() ?? '';
        return className.contains(query) ||
            subject.contains(query) ||
            description.contains(query);
      }).toList();
    }

    if (mounted) setState(() {});
  }

  void _clearSearchField() {
    _searchController.clear();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleDeleteClass(String classId, String className) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FontAwesomeIcons.triangleExclamation,
                  color: const Color(0xFFFF6B6B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Confirm Deletion'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete the class "$className"? This action cannot be undone and may affect enrolled students and associated content.',
            style: TextStyle(height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [const Color(0xFFFF6B6B), const Color(0xFFFF5252)],
                ),
              ),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: const Text('Delete'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await deleteClassFromService(classId);
        // Do NOT call _fetchClasses() here — the realtime listener will update the list automatically.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(FontAwesomeIcons.checkCircle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Class "$className" deleted successfully.'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted)
          setState(() => _error = "Failed to delete class: ${e.toString()}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(FontAwesomeIcons.xmark, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to delete class "$className": ${e.toString()}',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFFF6B6B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildModernAppBar(),
        body: Container(
          decoration: _buildBackgroundGradient(),
          child: SafeArea(child: _buildLoadingScreen()),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(),
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 16),
              if (_error != null)
                Expanded(child: _buildErrorWidget(_error!))
              else if (_classes.isEmpty)
                Expanded(child: _buildEmptyState())
              else if (_filteredClasses.isEmpty &&
                  _searchController.text.isNotEmpty)
                Expanded(child: _buildNoResultsState())
              else
                Expanded(child: _buildClassesList()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      title: Text(
        "My Classes",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(FontAwesomeIcons.arrowLeft, size: 16),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(FontAwesomeIcons.arrowsRotate, size: 16),
            onPressed: _loading ? null : _fetchClasses,
            tooltip: "Refresh Classes",
          ),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF8FAFC), Color(0xFFE3F0FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 0),
            spreadRadius: -5,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search classes by name, subject, or description...",
          hintStyle: TextStyle(color: const Color(0xFF64748B), fontSize: 15),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.2),
                  const Color(0xFF6366F1).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              FontAwesomeIcons.magnifyingGlass,
              size: 16,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(FontAwesomeIcons.xmark, size: 14),
                    onPressed: _clearSearchField,
                    tooltip: "Clear Search",
                    color: const Color(0xFF64748B),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.1),
                    const Color(0xFF6366F1).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF8B5CF6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Loading your classes...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(0.1),
                        const Color(0xFF6366F1).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    FontAwesomeIcons.chalkboardUser,
                    size: 64,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'No Classes Found',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "You haven't created any classes yet.\nTap the '+' button to get started!",
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B5CF6),
                        const Color(0xFF6366F1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(FontAwesomeIcons.plus, size: 16),
                    ),
                    label: const Text(
                      'Create Your First Class',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateClassForm(),
                        ),
                      );
                      // No .then(_fetchClasses) -- let the realtime stream update the UI!
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withOpacity(0.1),
                    const Color(0xFFEAB308).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                FontAwesomeIcons.folderOpen,
                size: 48,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Classes Match Your Search',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Try adjusting your search term or clear the search to see all your classes.",
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [const Color(0xFF64748B), const Color(0xFF475569)],
                ),
              ),
              child: ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.xmark, size: 16),
                label: const Text(
                  'Clear Search',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: _clearSearchField,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withOpacity(0.1),
                    const Color(0xFFFF5252).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                FontAwesomeIcons.triangleExclamation,
                size: 48,
                color: const Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something Went Wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                ),
              ),
              child: ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.arrowsRotate, size: 16),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: _fetchClasses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          onRefresh: _fetchClasses,
          color: const Color(0xFF8B5CF6),
          backgroundColor: Colors.white,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            itemCount: _filteredClasses.length,
            itemBuilder: (context, index) {
              final classData = _filteredClasses[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 200 + (index * 50)),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TrainerClassDashboardPage(classId: classData['id']),
                      ),
                    );
                  },
                  child: ClassListItemWidget(
                    classData: classData,
                    onDeleteClass: _handleDeleteClass,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateClassForm()),
          );
          // No .then(_fetchClasses) -- let the realtime stream update the UI!
        },
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(FontAwesomeIcons.plus, size: 16),
        ),
        label: const Text(
          'New Class',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
