import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart'; // Using file_picker for broader file type support
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'ManageClassStudents.dart';
// import 'package:url_launcher/url_launcher.dart'; // For opening files

// --- Data Models (Simplified) ---
class ClassMaterial {
  final String id;
  final String title;
  final String? description;
  final String downloadURL;
  final String filePath; // Storage path
  final String fileName;
  final String? fileType; // MIME type
  final Timestamp createdAt;

  ClassMaterial({
    required this.id,
    required this.title,
    this.description,
    required this.downloadURL,
    required this.filePath,
    required this.fileName,
    this.fileType,
    required this.createdAt,
  });

  factory ClassMaterial.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ClassMaterial(
      id: doc.id,
      title: data['title'] ?? 'Untitled Material',
      description: data['description'],
      downloadURL: data['downloadURL'] ?? '',
      filePath: data['filePath'] ?? '',
      fileName: data['fileName'] ?? 'unknown_file',
      fileType: data['fileType'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}

// --- Assumed Firebase Service Functions (Implement these) ---
// fetchClassDetailsFromService is already defined in manage_class_students_page.dart, ensure it's accessible or redefine.
// For simplicity, assuming it's available or you'll manage imports.

Future<List<ClassMaterial>> fetchClassMaterialsFromService(String classId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('materials') // Assuming subcollection 'materials'
      .orderBy('createdAt', descending: true)
      .get();
  return snapshot.docs.map((doc) => ClassMaterial.fromFirestore(doc)).toList();
}

Future<Map<String, dynamic>> uploadClassMaterialFileToStorage(String classId, File file, String fileName, Function(double) onProgress) async {
  final storageRef = FirebaseStorage.instance.ref().child('class_materials/$classId/$fileName');
  UploadTask uploadTask = storageRef.putFile(file);

  uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
    double progress = snapshot.bytesTransferred / snapshot.totalBytes;
    onProgress(progress);
  });

  TaskSnapshot taskSnapshot = await uploadTask;
  String downloadURL = await taskSnapshot.ref.getDownloadURL();
  return {
    'downloadURL': downloadURL,
    'filePath': taskSnapshot.ref.fullPath,
    'fileName': fileName,
    'fileType': file.path.split('.').last, // Basic type, consider using mime package for accuracy
  };
}

Future<DocumentReference> addClassMaterialMetadataToFirestore(String classId, Map<String, dynamic> materialData) async {
  return FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('materials')
      .add({
        ...materialData,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

Future<void> deleteClassMaterialFileFromStorage(String filePath) async {
  await FirebaseStorage.instance.ref(filePath).delete();
}

Future<void> deleteClassMaterialMetadataFromFirestore(String classId, String materialId) async {
  await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('materials')
      .doc(materialId)
      .delete();
}


class ManageClassContentPage extends StatefulWidget {
  final String classId;

  const ManageClassContentPage({Key? key, required this.classId}) : super(key: key);

  @override
  _ManageClassContentPageState createState() => _ManageClassContentPageState();
}

class _ManageClassContentPageState extends State<ManageClassContentPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  ClassDetails? _classDetails; // Assuming ClassDetails model from manage_class_students_page.dart
  List<ClassMaterial> _materials = [];

  bool _isLoading = true;
  String? _error;
  File? _selectedFile;
  String? _selectedFileName;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _fetchClassData();
  }

  Future<void> _fetchClassData({bool showLoading = true}) async {
    if (_currentUser == null) {
      setState(() {
        _error = "Authentication required.";
        _isLoading = false;
      });
      return;
    }
    if (showLoading) setState(() => _isLoading = true);
    _error = null;

    try {
      // Re-using fetchClassDetailsFromService from manage_class_students_page.dart (ensure accessible)
      final details = await fetchClassDetailsFromService(widget.classId);
      if (details.trainerId != _currentUser!.uid) {
        setState(() {
          _error = "You are not authorized to manage content for this class.";
          _isLoading = false;
        });
        return;
      }
      final materials = await fetchClassMaterialsFromService(widget.classId);
      setState(() {
        _classDetails = details;
        _materials = materials;
      });
    } catch (e) {
      setState(() => _error = "Failed to load data: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _selectedFileName = result.files.single.name;
        _uploadError = null;
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null) {
      setState(() => _uploadError = "Please select a file.");
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      setState(() => _uploadError = "Please enter a title for the material.");
      return;
    }
    if (_currentUser == null) {
      setState(() => _uploadError = "Authentication error.");
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      final uploadData = await uploadClassMaterialFileToStorage(
        widget.classId,
        _selectedFile!,
        _selectedFileName ?? _selectedFile!.path.split('/').last,
        (progress) => setState(() => _uploadProgress = progress),
      );

      final materialMetadata = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'downloadURL': uploadData['downloadURL'],
        'filePath': uploadData['filePath'],
        'fileName': uploadData['fileName'],
        'fileType': uploadData['fileType'], // Or use mime package for better type detection
        'trainerId': _currentUser!.uid,
      };

      await addClassMaterialMetadataToFirestore(widget.classId, materialMetadata);

      // Reset form and re-fetch materials
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
      });
      await _fetchClassData(showLoading: false); // Refresh list

    } catch (e) {
      setState(() => _uploadError = "Upload failed: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _handleDeleteMaterial(ClassMaterial material) async {
     bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${material.title}"? This action cannot be undone.'),
        actions: <Widget>[
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(child: const Text('Delete'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true); // Show loading indicator for delete operation
    _error = null;
    try {
      await deleteClassMaterialFileFromStorage(material.filePath);
      await deleteClassMaterialMetadataFromFirestore(widget.classId, material.id);
      await _fetchClassData(showLoading: false); // Refresh list
    } catch (e) {
      setState(() => _error = "Deletion failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getFileIcon(String? fileTypeOrName) {
    if (fileTypeOrName == null) return FontAwesomeIcons.file;
    String ext = fileTypeOrName.contains('.') ? fileTypeOrName.split('.').last.toLowerCase() : fileTypeOrName.toLowerCase();
    if (ext == 'pdf') return FontAwesomeIcons.filePdf;
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) return FontAwesomeIcons.fileVideo;
    if (['mp3', 'wav', 'aac'].contains(ext)) return FontAwesomeIcons.fileAudio;
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return FontAwesomeIcons.fileImage;
    if (['doc', 'docx'].contains(ext)) return FontAwesomeIcons.fileWord;
    if (['ppt', 'pptx'].contains(ext)) return FontAwesomeIcons.filePowerpoint;
    if (['xls', 'xlsx'].contains(ext)) return FontAwesomeIcons.fileExcel;
    if (ext == 'txt') return FontAwesomeIcons.fileLines;
    return FontAwesomeIcons.file;
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
  }

  // Future<void> _launchURL(String url) async {
  //   if (await canLaunchUrl(Uri.parse(url))) {
  //     await launchUrl(Uri.parse(url));
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $url')));
  //   }
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_classDetails?.className ?? "Manage Content"),
         actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.arrowsRotate),
            onPressed: _isLoading ? null : () => _fetchClassData(),
            tooltip: "Refresh Content",
          )
        ],
      ),
      body: _isLoading && _materials.isEmpty // Show full page loader only on initial load
          ? const Center(child: CircularProgressIndicator())
          : _error != null && !_error!.toLowerCase().contains("deletion failed") // Show general errors not related to delete action
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: $_error", style: TextStyle(color: Theme.of(context).colorScheme.error))))
              : _classDetails == null
                  ? const Center(child: Text("Class details not available."))
                  : RefreshIndicator(
                      onRefresh: () => _fetchClassData(showLoading: false),
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildUploadSection(),
                          const SizedBox(height: 24),
                          _buildMaterialsList(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Upload New Material", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(_uploadError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Title*", border: OutlineInputBorder()),
              enabled: !_isUploading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: "Description (Optional)", border: OutlineInputBorder()),
              maxLines: 2,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(FontAwesomeIcons.paperclip),
                    label: Text(_selectedFileName ?? "Select File*"),
                    onPressed: _isUploading ? null : _pickFile,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: _isUploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FontAwesomeIcons.upload),
                  label: const Text("Upload"),
                  onPressed: (_isUploading || _selectedFile == null || _titleController.text.trim().isEmpty) ? null : _handleUpload,
                ),
              ],
            ),
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(value: _uploadProgress),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Uploaded Materials (${_materials.length})", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_error != null && _error!.toLowerCase().contains("deletion failed")) // Show delete-specific errors here
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text("Error: $_error", style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),
        _isLoading && _materials.isNotEmpty // Show small loader when refreshing list
            ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
            : _materials.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No materials uploaded yet.")))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _materials.length,
                    itemBuilder: (context, index) {
                      final material = _materials[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: FaIcon(_getFileIcon(material.fileName), size: 30, color: Theme.of(context).primaryColor),
                          title: Text(material.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (material.description != null && material.description!.isNotEmpty)
                                Text(material.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(material.fileName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text("Uploaded: ${_formatTimestamp(material.createdAt)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // IconButton(
                              //   icon: const Icon(FontAwesomeIcons.download, color: Colors.blue),
                              //   onPressed: () => _launchURL(material.downloadURL),
                              //   tooltip: "Download/View",
                              // ),
                              IconButton(
                                icon: const Icon(FontAwesomeIcons.trashAlt, color: Colors.red),
                                onPressed: () => _handleDeleteMaterial(material),
                                tooltip: "Delete",
                              ),
                            ],
                          ),
                          onTap: () { /* _launchURL(material.downloadURL); */ }, // Make list item tappable to view/download
                        ),
                      );
                    },
                  ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}