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

  ClassDetails? _classDetails; 
  List<ClassMaterial> _materials = [];

  bool _isLoading = true;
  String? _error;
  File? _selectedFile;
  String? _selectedFileName;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  // ThemeData? _theme;

  @override
  void initState() {
    super.initState();
    _fetchClassData();
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _theme = Theme.of(context);
  // }

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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(_classDetails?.className ?? "Manage Content", style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: theme.colorScheme.surfaceVariant,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        elevation: 0,
         actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.arrowsRotate),
            onPressed: _isLoading ? null : () => _fetchClassData(),
            tooltip: "Refresh Content",
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: theme.dividerColor,
            height: 1.0,
          ),
        ),
      ),
      body: _isLoading && _materials.isEmpty 
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)))
          : _error != null && !_error!.toLowerCase().contains("deletion failed") && !_error!.toLowerCase().contains("upload failed")
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: $_error", style: TextStyle(color: theme.colorScheme.error))))
              : _classDetails == null
                  ? const Center(child: Text("Class details not available."))
                  : RefreshIndicator(
                      onRefresh: () => _fetchClassData(showLoading: false),
                      color: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Upload New Material", style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_uploadError!, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13))),
                  ]),
                )
              ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Title*", 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(FontAwesomeIcons.heading, color: theme.colorScheme.onSurfaceVariant, size: 18),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              enabled: !_isUploading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: "Description (Optional)", 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(FontAwesomeIcons.alignLeft, color: theme.colorScheme.onSurfaceVariant, size: 18),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              maxLines: 2,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(FontAwesomeIcons.paperclip, size: 16, color: _isUploading ? theme.disabledColor : theme.colorScheme.primary),
                    label: Text(
                      _selectedFileName ?? "Select File*", 
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _isUploading ? theme.disabledColor : theme.colorScheme.primary),
                    ),
                    onPressed: _isUploading ? null : _pickFile,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      side: BorderSide(color: _isUploading ? theme.disabledColor : theme.colorScheme.primary.withOpacity(0.7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: _isUploading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary)) : const Icon(FontAwesomeIcons.upload, size: 16),
                  label: const Text("Upload"),
                  onPressed: (_isUploading || _selectedFile == null || _titleController.text.trim().isEmpty) ? null : _handleUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress, 
                      backgroundColor: theme.colorScheme.surfaceVariant, 
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 4),
                    Text("${(_uploadProgress * 100).toStringAsFixed(0)}%", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsList() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Uploaded Materials (${_materials.length})", style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        if (_error != null && (_error!.toLowerCase().contains("deletion failed") || _error!.toLowerCase().contains("upload failed")))
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text("Error: $_error", style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13))),
                  ]),
                )
              ),
        _isLoading && _materials.isNotEmpty 
            ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary))))
            : _materials.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0), 
                    child: Text("No materials uploaded yet.", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                  ))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _materials.length,
                    itemBuilder: (context, index) {
                      final material = _materials[index];
                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        color: theme.colorScheme.surface,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          leading: FaIcon(_getFileIcon(material.fileName), size: 30, color: theme.colorScheme.primary),
                          title: Text(material.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              if (material.description != null && material.description!.isNotEmpty)
                                Text(material.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              Text(material.fileName, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8))),
                              Text("Uploaded: ${_formatTimestamp(material.createdAt)}", style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6))),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(FontAwesomeIcons.circleDown, color: theme.colorScheme.secondary, size: 20),
                                onPressed: () { /* _launchURL(material.downloadURL); */ }, // Ensure url_launcher is setup
                                tooltip: "Download/View",
                              ),
                              IconButton(
                                icon: Icon(FontAwesomeIcons.trashCan, color: theme.colorScheme.error, size: 20),
                                onPressed: () => _handleDeleteMaterial(material),
                                tooltip: "Delete",
                              ),
                            ],
                          ),
                          onTap: () { /* _launchURL(material.downloadURL); */ }, 
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