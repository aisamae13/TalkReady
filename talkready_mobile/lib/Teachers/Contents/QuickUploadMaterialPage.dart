import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as p; // For p.extension

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
    DocumentReference docRef = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('materials')
        .add({
      ...materialData,
      'trainerId': trainerId,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    // Return the added data along with its ID
    return {
      'id': docRef.id,
      ...materialData
    };
  } catch (e) {
    // print("Error adding material metadata: $e");
    throw Exception("Failed to save material details: ${e.toString()}");
  }
}
// End of placeholder service functions

class QuickUploadMaterialPage extends StatefulWidget {
  const QuickUploadMaterialPage({Key? key}) : super(key: key);

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
      final classes = await getTrainerClasses(_currentUser!.uid);
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
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileNameDisplay = result.files.single.name;
        _uploadError = null;
        _uploadSuccessMessage = null;
      });
    } else {
      // User canceled the picker
      setState(() {
        _selectedFile = null;
        _fileNameDisplay = null;
      });
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

      final materialData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'downloadURL': fileUploadResult['downloadURL'],
        'filePath': fileUploadResult['filePath'],
        'fileName': fileUploadResult['fileName'],
        'fileType': fileUploadResult['fileType'],
      };

      final newMaterialDoc = await addClassMaterialMetadata(
        _currentUser!.uid,
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
    if (_loadingClasses) {
      return Scaffold(
        appBar: AppBar(title: const Text("Upload Material")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload New Material"),
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _currentUser == null
          ? _buildAuthError()
          : _buildBody(),
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
    if (_classesError != null && _trainerClasses.isEmpty) {
      return _buildErrorDisplay(
        _classesError!,
        FontAwesomeIcons.listUl,
        onRetry: _fetchClassesForSelection,
        showCreateClassButton: _classesError!.contains("create a class first"),
      );
    }
    if (_trainerClasses.isEmpty && _classesError == null) {
       return _buildErrorDisplay(
        "No classes available.",
        FontAwesomeIcons.chalkboardUser,
        showCreateClassButton: true,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: _uploadSuccessMessage != null
          ? _buildSuccessView()
          : _buildUploadForm(),
    );
  }

  Widget _buildErrorDisplay(String error, IconData icon, {VoidCallback? onRetry, bool showCreateClassButton = false}) {
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
            ],
            if (showCreateClassButton) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.plusCircle),
                label: const Text("Create a Class"),
                onPressed: () {
                  Navigator.pushNamed(context, '/trainer/classes/create'); // Adjust route if needed
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
              ),
            ]
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FontAwesomeIcons.checkCircle, color: Colors.green, size: 60),
            const SizedBox(height: 20),
            Text(
              "Upload Successful!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _uploadSuccessMessage ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(FontAwesomeIcons.fileUpload),
              label: const Text("Upload Another File"),
              onPressed: () => _resetFormForAnotherUpload(keepClass: true),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
            ),
            const SizedBox(height: 12),
            if (_selectedClassId != null)
              TextButton.icon(
                icon: const Icon(FontAwesomeIcons.eye),
                label: const Text("View Class Content"),
                onPressed: () {
                  // TODO: Navigate to view content page for _selectedClassId
                  // Example: Navigator.pushNamed(context, '/trainer/class/$_selectedClassId/content');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Navigate to content for class ID: $_selectedClassId (Not Implemented)")),
                  );
                },
              ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(FontAwesomeIcons.arrowLeft),
              label: const Text("Back to Dashboard"),
              onPressed: () => Navigator.of(context).popUntil((route) => route.settings.name == '/trainer-dashboard' || route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}