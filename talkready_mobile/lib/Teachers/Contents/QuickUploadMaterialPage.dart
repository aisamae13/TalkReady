import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as p;

// Placeholder for your actual service functions.
// You should move these to a separate services file (e.g., firebase_services.dart)

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
    throw Exception("Failed to load classes: ${e.toString()}");
  }
}

Future<Map<String, dynamic>> uploadClassMaterialFile(
  String classId,
  File file,
  String fileName,
  Function(double) onProgress,
) async {
  try {
    final String fileExtension = p.extension(file.path);
    final String uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final Reference storageRef = FirebaseStorage.instance
        .ref()
        .child('class_materials')
        .child(classId)
        .child(uniqueFileName);

    UploadTask uploadTask = storageRef.putFile(file);

    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      double progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress(progress);
    });

    TaskSnapshot taskSnapshot = await uploadTask;
    String downloadURL = await taskSnapshot.ref.getDownloadURL();

    return {
      'downloadURL': downloadURL,
      'filePath': storageRef.fullPath,
      'fileName': fileName, // Original file name
      'fileType': fileExtension,
    };
  } catch (e) {
    // print("Error uploading file: $e");
    throw Exception("File upload failed: ${e.toString()}");
  }
}

Future<Map<String, dynamic>> addClassMaterialMetadata(
  String trainerId,
  String classId,
  Map<String, dynamic> materialData,
) async {
  try {
    // Create a new document in the classMaterials collection
    DocumentReference materialDocRef = FirebaseFirestore.instance
        .collection('classMaterials')
        .doc();

    final Map<String, dynamic> newMaterialEntry = {
      ...materialData, // Contains title, description, downloadURL, filePath, fileName, fileType
      'classId': classId, // Reference to the class
      'trainerId': trainerId, // Ensure trainerId is part of the material entry
      'createdAt': FieldValue.serverTimestamp(),
      'subjectCode': materialData['subjectCode'] ?? '', // Include subjectCode if provided
    };

    // Add the new material document to the classMaterials collection
    await materialDocRef.set(newMaterialEntry);

    // Return the data that was added with the document ID
    return {
      ...newMaterialEntry,
      'id': materialDocRef.id, // Using the auto-generated document ID
      // 'createdAt' will be resolved on the server.
    };

  } catch (e) {
    throw Exception("Failed to save material details: ${e.toString()}");
  }
}
// End of placeholder service functions

class QuickUploadMaterialPage extends StatefulWidget {
  const QuickUploadMaterialPage({super.key});

  @override
  _QuickUploadMaterialPageState createState() =>
      _QuickUploadMaterialPageState();
}

class _QuickUploadMaterialPageState extends State<QuickUploadMaterialPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _trainerClasses = [];
  String? _selectedClassId;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedFile;
  String? _fileNameDisplay;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  String? _uploadSuccessMessage;

  bool _loadingClasses = true;
  String? _classesError;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _fetchClassesForSelection();
    } else {
      setState(() {
        _loadingClasses = false;
        _classesError = "User not logged in. Please log in to upload materials.";
      });
    }
  }

  Future<void> _fetchClassesForSelection() async {
    if (_currentUser == null) return;
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    try {
      final classes = await getTrainerClasses(_currentUser.uid);
      if (mounted) {
        setState(() {
          _trainerClasses = classes;
          if (_trainerClasses.isEmpty) {
            _classesError = "You don't have any classes. Please create a class first to upload materials.";
          }
          _loadingClasses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _classesError = e.toString();
          _trainerClasses = [];
          _loadingClasses = false;
        });
      }
    }
  }

  Future<void> _handleFilePick() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileNameDisplay = result.files.single.name;
          _uploadError = null;
          _uploadSuccessMessage = null;
        });
      }
    } catch (e) {
      // Handle the error gracefully
      setState(() {
        _uploadError = "Unable to select file. Please try again or choose a different file.";
        _selectedFile = null;
        _fileNameDisplay = null;
      });
      
      // Optional: Show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("File selection failed: Please try again"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetFormForAnotherUpload({bool keepClass = true}) {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedFile = null;
      _fileNameDisplay = null;
      _uploadProgress = 0;
      _uploadError = null;
      _uploadSuccessMessage = null; // This will hide the success view
      if (!keepClass) {
        _selectedClassId = null;
      }
    });
  }

  Future<void> _handleSubmitUpload() async {
    if (_currentUser == null) {
      setState(() => _uploadError = "Authentication error. Please log in again.");
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedClassId == null) {
      setState(() => _uploadError = "Please select a class.");
      return;
    }
    if (_selectedFile == null) {
      setState(() => _uploadError = "Please select a file to upload.");
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadError = null;
      _uploadSuccessMessage = null;
    });

    try {
      final fileUploadResult = await uploadClassMaterialFile(
        _selectedClassId!,
        _selectedFile!,
        _fileNameDisplay!, // Original file name
        (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );

      // Auto-generate subject code from title
      String autoSubjectCode = _generateSubjectCodeFromTitle(_titleController.text.trim());

      final materialData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'subjectCode': autoSubjectCode, // Auto-generated from title
        'downloadURL': fileUploadResult['downloadURL'],
        'filePath': fileUploadResult['filePath'],
        'fileName': fileUploadResult['fileName'],
        'fileType': fileUploadResult['fileType'],
      };

      final newMaterialDoc = await addClassMaterialMetadata(
        _currentUser.uid,
        _selectedClassId!,
        materialData,
      );

      if (mounted) {
        final selectedClass = _trainerClasses.firstWhere((c) => c['id'] == _selectedClassId, orElse: () => {});
        final className = selectedClass['className'] ?? 'the selected class';
        setState(() {
          _uploadSuccessMessage = 'Material "${newMaterialDoc['title']}" uploaded successfully to "$className"!';
          _selectedFile = null; // Clear file for next upload
          _fileNameDisplay = null;
          // Title and description are kept if "Upload Another to This Class" is intended
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          // _uploadProgress = 0; // Keep progress at 100% on success, or reset if preferred
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingClasses) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            "Upload Material",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFE3F0FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Upload New Material",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _currentUser == null
          ? _buildAuthError()
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFE3F0FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                            spreadRadius: -5,
                          ),
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 0),
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildBody(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
              _classesError ?? "You must be logged in to upload materials.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBody() {
    if (_uploadSuccessMessage != null) {
      return _buildSuccessView();
    }

    if (_classesError != null && _trainerClasses.isEmpty) {
      return _buildErrorDisplay(
        _classesError!,
        FontAwesomeIcons.listUl,
        onRetry: _fetchClassesForSelection,
        showCreateClassButton: _classesError!.contains("create a class first"),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact Header section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withOpacity(0.1), // Changed to teal
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    FontAwesomeIcons.cloudArrowUp,
                    color: const Color(0xFF14B8A6), // Changed to teal
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Upload Learning Material",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Share educational content with your students",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Error message (compact)
          if (_uploadError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.triangleExclamation, 
                       color: const Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _uploadError!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Class selection dropdown (compact)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Select Class *",
                labelStyle: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withOpacity(0.1), // Changed to teal
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    FontAwesomeIcons.chalkboardUser,
                    color: const Color(0xFF14B8A6), // Changed to teal
                    size: 18,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              value: _selectedClassId,
              hint: const Text("-- Choose a class --"),
              isExpanded: true,
              items: _trainerClasses.map((Map<String, dynamic> cls) {
                return DropdownMenuItem<String>(
                  value: cls['id'] as String,
                  child: Text(cls['className'] as String? ?? 'Unnamed Class',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                );
              }).toList(),
              onChanged: _isUploading ? null : (String? newValue) {
                setState(() {
                  _selectedClassId = newValue;
                  _uploadError = null;
                  _uploadSuccessMessage = null;
                });
              },
              validator: (value) => value == null ? 'Please select a class' : null,
            ),
          ),
          const SizedBox(height: 16),

          // Material title field (compact)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextFormField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                labelText: "Material Title *",
                labelStyle: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withOpacity(0.1), // Changed to teal
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    FontAwesomeIcons.book,
                    color: const Color(0xFF14B8A6), // Changed to teal
                    size: 18,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
              enabled: !_isUploading,
            ),
          ),
          const SizedBox(height: 16),

          // Description field (compact)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextFormField(
              controller: _descriptionController,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                labelText: "Description (Optional)",
                labelStyle: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withOpacity(0.1), // Changed to teal
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    FontAwesomeIcons.solidFileLines,
                    color: const Color(0xFF14B8A6), // Changed to teal
                    size: 18,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              maxLines: 2,
              enabled: !_isUploading,
            ),
          ),
          const SizedBox(height: 16),

          // File picker button (compact)
          OutlinedButton.icon(
            icon: Icon(
              FontAwesomeIcons.paperclip,
              size: 16,
              color: _selectedFile != null ? const Color(0xFF14B8A6) : const Color(0xFF64748B), // Changed to teal
            ),
            label: Text(
              _fileNameDisplay ?? "Select File *",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: _selectedFile != null ? const Color(0xFF14B8A6) : const Color(0xFF64748B), // Changed to teal
              ),
            ),
            onPressed: _isUploading ? null : _handleFilePick,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              side: BorderSide(
                color: _selectedFile != null ? const Color(0xFF14B8A6) : const Color(0xFFE2E8F0), // Changed to teal
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: _selectedFile != null 
                  ? const Color(0xFF14B8A6).withOpacity(0.05) // Changed to teal
                  : const Color(0xFFF8FAFC),
            ),
          ),

          if (_selectedFile != null && _fileNameDisplay != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Icon(FontAwesomeIcons.checkCircle, 
                         color: const Color(0xFF16A34A), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Selected: $_fileNameDisplay",
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Upload progress (compact)
          if (_isUploading)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.cloudArrowUp, 
                           color: const Color(0xFF14B8A6), size: 14), // Changed to teal
                      const SizedBox(width: 6),
                      Text(
                        "Uploading your file...",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF14B8A6)), // Changed to teal
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${(_uploadProgress * 100).toStringAsFixed(0)}% Complete",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Upload button (compact)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14B8A6).withOpacity(0.3), // Changed to teal
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: _isUploading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(FontAwesomeIcons.save, size: 16),
              label: Text(
                _isUploading ? 'Uploading...' : 'Upload & Save Material',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: (_isUploading || _selectedFile == null || _selectedClassId == null)
                  ? null
                  : _handleSubmitUpload,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isUploading 
                    ? const Color(0xFF94A3B8) 
                    : const Color(0xFF14B8A6), // Changed to teal
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 20), // Add more space before the help text

          // Subtle help text with modern styling
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  FontAwesomeIcons.lightbulb,
                  size: 14,
                  color: const Color(0xFF14B8A6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Create a class to upload materials",
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildErrorDisplay(String error, IconData icon, {VoidCallback? onRetry, bool showCreateClassButton = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Modern animated container with gradient background
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withOpacity(0.1),
                    const Color(0xFFFF8E8E).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF6B6B).withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Modern icon with animated glow
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6B6B).withOpacity(0.15),
                          const Color(0xFFFF8E8E).withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 40,
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Modern typography with better hierarchy
                  Text(
                    "No Classes Available",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Modern action button with enhanced styling
                  if (showCreateClassButton)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF14B8A6), // Changed to teal
                            const Color(0xFF0D9488), // Changed to darker teal
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.4), // Changed to teal
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.2), // Changed to teal
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                            spreadRadius: -6,
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
                          child: const Icon(
                            FontAwesomeIcons.plus,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        label: const Text(
                          "Create Your First Class",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/trainer/classes/create');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          // Additional decorative elements
          const SizedBox(height: 20),
          
          // Subtle help text with modern styling
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  FontAwesomeIcons.lightbulb,
                  size: 14,
                  color: const Color(0xFF14B8A6), // Changed to teal
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Create a class to upload materials",
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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

  Widget _buildUploadForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_uploadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(_uploadError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: "Select Class *",
              prefixIcon: const Icon(FontAwesomeIcons.listUl),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            value: _selectedClassId,
            hint: const Text("-- Choose a class --"),
            isExpanded: true,
            items: _trainerClasses.map((Map<String, dynamic> cls) {
              return DropdownMenuItem<String>(
                value: cls['id'] as String,
                child: Text(cls['className'] as String? ?? 'Unnamed Class'),
              );
            }).toList(),
            onChanged: _isUploading ? null : (String? newValue) {
              setState(() {
                _selectedClassId = newValue;
                _uploadError = null;
                _uploadSuccessMessage = null;
              });
            },
            validator: (value) => value == null ? 'Please select a class' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: "Material Title *",
              prefixIcon: const Icon(FontAwesomeIcons.book),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
            enabled: !_isUploading,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: "Description (Optional)",
              prefixIcon: const Icon(FontAwesomeIcons.solidFileLines), // Changed icon
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            enabled: !_isUploading,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(FontAwesomeIcons.paperclip),
            label: Text(_fileNameDisplay ?? "Select File *"),
            onPressed: _isUploading ? null : _handleFilePick,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
              side: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
          if (_selectedFile != null && _fileNameDisplay != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("Selected: $_fileNameDisplay", style: TextStyle(color: Colors.grey[700])),
            ),
          if (_selectedFile == null)
             Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("No file selected.", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ),

          const SizedBox(height: 20),
          if (_isUploading)
            Column(
              children: [
                LinearProgressIndicator(value: _uploadProgress, minHeight: 6),
                const SizedBox(height: 4),
                Text("${(_uploadProgress * 100).toStringAsFixed(0)}% Uploaded"),
              ],
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: _isUploading
                ? Container(
                    width: 20,
                    height: 20,
                    padding: const EdgeInsets.all(2.0),
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(FontAwesomeIcons.save, size: 16),
            label: Text(_isUploading ? 'Uploading...' : 'Upload & Save Material'),
            onPressed: (_isUploading || _selectedFile == null || _selectedClassId == null)
                ? null
                : _handleSubmitUpload,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                FontAwesomeIcons.checkCircle,
                color: Color(0xFF16A34A),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Upload Successful!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _uploadSuccessMessage ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            // Enhanced buttons with shadows
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.fileUpload),
                label: const Text("Upload Another File"),
                onPressed: () => _resetFormForAnotherUpload(keepClass: true),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(FontAwesomeIcons.arrowLeft),
              label: const Text("Back to Dashboard"),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateSubjectCodeFromTitle(String title) {
    if (title.isEmpty) {
      // Fallback to timestamp-based code if no title
      return 'MAT${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }

    // Clean the title and extract meaningful parts
    String cleanTitle = title
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .trim();

    List<String> words = cleanTitle.split(RegExp(r'\s+'));

    // Extract first word (subject)
    String firstWord = words.isNotEmpty ? words[0] : 'MAT';

    // Extract all numbers from the title
    String numbers = title.replaceAll(RegExp(r'[^0-9]'), '');

    // If no numbers found, use timestamp suffix
    if (numbers.isEmpty) {
      numbers = DateTime.now().millisecondsSinceEpoch.toString().substring(10);
    }

    // Take only first 4 characters of the word and first 3 digits
    String subjectPart = firstWord.length > 4 ? firstWord.substring(0, 4) : firstWord;
    String numberPart = numbers.length > 3 ? numbers.substring(0, 3) : numbers;

    // Ensure we have at least 3 digits
    if (numberPart.length < 3) {
      numberPart = numberPart.padRight(3, '0');
    }

    return '${subjectPart.toUpperCase()}$numberPart';
  }
}