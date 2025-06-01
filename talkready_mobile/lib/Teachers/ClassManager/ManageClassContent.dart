import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'ManageClassStudents.dart';

// --- Data Models ---
class ClassMaterial {
  final String id;
  final String title;
  final String? description;
  final String downloadURL;
  final String filePath;
  final String fileName;
  final String? fileType;
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

// --- Firebase Service Functions ---
Future<List<ClassMaterial>> fetchClassMaterialsFromService(String classId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('classMaterials')
      .where('classId', isEqualTo: classId)
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
    'fileType': file.path.split('.').last,
  };
}

Future<DocumentReference> addClassMaterialMetadataToFirestore(String classId, Map<String, dynamic> materialData) async {
  return FirebaseFirestore.instance
      .collection('classMaterials')
      .add({
        ...materialData,
        'classId': classId,
        'trainerId': materialData['trainerId'],
        'createdAt': FieldValue.serverTimestamp(),
      });
}

Future<void> deleteClassMaterialFileFromStorage(String filePath) async {
  await FirebaseStorage.instance.ref(filePath).delete();
}

Future<void> deleteClassMaterialMetadataFromFirestore(String classId, String materialId) async {
  await FirebaseFirestore.instance
      .collection('classMaterials')
      .doc(materialId)
      .delete();
}

class ManageClassContentPage extends StatefulWidget {
  final String classId;

  const ManageClassContentPage({super.key, required this.classId});

  @override
  _ManageClassContentPageState createState() => _ManageClassContentPageState();
}

class _ManageClassContentPageState extends State<ManageClassContentPage>
    with TickerProviderStateMixin {
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

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchClassData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

      // Start animations
      _fadeController.forward();
      _slideController.forward();
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
        'fileType': uploadData['fileType'],
        'trainerId': _currentUser!.uid,
      };

      await addClassMaterialMetadataToFirestore(widget.classId, materialMetadata);

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
      });
      await _fetchClassData(showLoading: false);
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
      builder: (ctx) => _buildModernDialog(material),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    _error = null;
    try {
      await deleteClassMaterialFileFromStorage(material.filePath);
      await deleteClassMaterialMetadataFromFirestore(widget.classId, material.id);
      await _fetchClassData(showLoading: false);
    } catch (e) {
      setState(() => _error = "Deletion failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildModernDialog(ClassMaterial material) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade100, Colors.red.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FaIcon(
                FontAwesomeIcons.triangleExclamation,
                color: Colors.red.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirm Deletion',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Are you sure you want to delete "${material.title}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      actions: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.grey.shade200, Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    if (_isLoading && _materials.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white, // Changed to white background
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                "Loading class content...",
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white, // Changed to white background
      appBar: _buildSimpleAppBar(isSmallScreen), // Use simple AppBar
      body: _buildContent(isSmallScreen),
    );
  }

  PreferredSizeWidget _buildSimpleAppBar(bool isSmallScreen) {
    return AppBar(
      backgroundColor: const Color(0xFF8B5CF6),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        "Manage Content",
        style: TextStyle(
          color: Colors.white,
          fontSize: isSmallScreen ? 18 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.refresh,
            color: Colors.white,
          ),
          onPressed: _isLoading ? null : () => _fetchClassData(),
          tooltip: "Refresh Content",
        ),
      ],
    );
  }

  Widget _buildContent(bool isSmallScreen) {
    if (_error != null && !_error!.toLowerCase().contains("deletion failed") && !_error!.toLowerCase().contains("upload failed")) {
      return _buildErrorState();
    }

    if (_classDetails == null) {
      return const Center(
        child: Text(
          "Class details not available.",
          style: TextStyle(color: Color(0xFF1E293B), fontSize: 16),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          onRefresh: () => _fetchClassData(showLoading: false),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Column(
              children: [
                _buildUploadSection(isSmallScreen),
                SizedBox(height: isSmallScreen ? 20 : 24),
                _buildMaterialsList(isSmallScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade200.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.triangleExclamation,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Error",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.cloudArrowUp,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Upload New Material",
                  style: TextStyle(
                    color: const Color(0xFF1E293B), // Changed to dark color
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          if (_uploadError != null) _buildUploadErrorMessage(),
          _buildFormField(
            controller: _titleController,
            label: "Title*",
            icon: FontAwesomeIcons.heading,
            enabled: !_isUploading,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          _buildFormField(
            controller: _descriptionController,
            label: "Description (Optional)",
            icon: FontAwesomeIcons.alignLeft,
            maxLines: 3,
            enabled: !_isUploading,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFileSelectButton(isSmallScreen),
                    const SizedBox(height: 12),
                    _buildUploadButton(isSmallScreen),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(child: _buildFileSelectButton(isSmallScreen)),
                    const SizedBox(width: 12),
                    _buildUploadButton(isSmallScreen),
                  ],
                );
              }
            },
          ),
          if (_isUploading) _buildUploadProgress(),
        ],
      ),
    );
  }

  Widget _buildMaterialsList(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.folderOpen,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Materials (${_materials.length})",
                  style: TextStyle(
                    color: const Color(0xFF1E293B), // Changed to dark color
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null && (_error!.toLowerCase().contains("deletion failed") || _error!.toLowerCase().contains("upload failed")))
            _buildMaterialsErrorMessage(),
          if (_isLoading && _materials.isNotEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
            )
          else if (_materials.isEmpty)
            _buildEmptyMaterialsState()
          else
            _buildMaterialsGrid(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildUploadErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50, // Changed to visible background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: Colors.red.shade700,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _uploadError!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[50],
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        enabled: enabled,
        style: const TextStyle(
          color: Color(0xFF1E293B), // Changed to dark color
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: isSmallScreen ? 14 : 16,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(
              icon,
              color: const Color(0xFF8B5CF6),
              size: 16,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF8B5CF6),
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isSmallScreen ? 16 : 20,
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelectButton(bool isSmallScreen) {
    return Container(
      height: isSmallScreen ? 48 : 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[100], // Changed to visible background
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isUploading ? null : _pickFile,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.paperclip,
                    color: Color(0xFF8B5CF6),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFileName ?? "Select File*",
                    style: TextStyle(
                      color: const Color(0xFF1E293B), // Changed to dark color
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton(bool isSmallScreen) {
    final canUpload = !_isUploading && _selectedFile != null && _titleController.text.trim().isNotEmpty;
    
    return Container(
      height: isSmallScreen ? 48 : 52,
      constraints: const BoxConstraints(minWidth: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: canUpload
            ? const LinearGradient(
                colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : LinearGradient(
                colors: [
                  Colors.grey[300]!, // Changed to visible gray
                  Colors.grey[200]!,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        boxShadow: canUpload
            ? [
                BoxShadow(
                  color: const Color(0xFF4facfe).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canUpload ? _handleUpload : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isUploading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        canUpload ? Colors.white : Colors.grey[600]!,
                      ),
                    ),
                  )
                else
                  FaIcon(
                    FontAwesomeIcons.upload,
                    color: canUpload ? Colors.white : Colors.grey[600]!,
                    size: 16,
                  ),
                const SizedBox(width: 8),
                Text(
                  "Upload",
                  style: TextStyle(
                    color: canUpload ? Colors.white : Colors.grey[600]!,
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey[300], // Changed to visible background
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${(_uploadProgress * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              color: const Color(0xFF1E293B), // Changed to dark color
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: Colors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Error: $_error",
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMaterialsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: FaIcon(
              FontAwesomeIcons.inbox,
              color: Colors.grey[400],
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No materials uploaded yet.",
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Upload your first material using the form above.",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsGrid(bool isSmallScreen) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallScreen ? 1 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isSmallScreen ? 3.5 : 3,
      ),
      itemCount: _materials.length,
      itemBuilder: (context, index) {
        final material = _materials[index];
        return _buildMaterialCard(material, isSmallScreen);
      },
    );
  }

  Widget _buildMaterialCard(ClassMaterial material, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Add download/view functionality here
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FaIcon(
                        _getFileIcon(material.fileName),
                        color: const Color(0xFF8B5CF6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.title,
                            style: TextStyle(
                              color: const Color(0xFF1E293B),
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            material.fileName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isSmallScreen ? 12 : 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: FaIcon(
                              FontAwesomeIcons.download,
                              color: Colors.blue.shade600,
                              size: 16,
                            ),
                            onPressed: () {
                              // Add download functionality
                            },
                            tooltip: "Download",
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: FaIcon(
                              FontAwesomeIcons.trashCan,
                              color: Colors.red.shade600,
                              size: 16,
                            ),
                            onPressed: () => _handleDeleteMaterial(material),
                            tooltip: "Delete",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (material.description != null && material.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    material.description!,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: isSmallScreen ? 12 : 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                Text(
                  "Uploaded: ${_formatTimestamp(material.createdAt)}",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}