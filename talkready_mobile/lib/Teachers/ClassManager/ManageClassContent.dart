//Trainer

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../notification_service.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'ManageClassStudents.dart';
import 'package:file_saver/file_saver.dart';

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
      if (details.trainerId != _currentUser.uid) {
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
Future<void> _notifyStudentsAboutContent({
  required String action,
  required String contentTitle,
}) async {
  try {
    final classDoc = await FirebaseFirestore.instance
        .collection('trainerClass')
        .doc(widget.classId)
        .get();

    final className = classDoc.data()?['className'] as String?;

    await NotificationService.createNotificationsForStudents(
      classId: widget.classId,
      message: '$action: $contentTitle',
      className: className,
      link: '/student/class/${widget.classId}/content',
      type: 'material',
    );
  } catch (e) {
    debugPrint('Failed to send notifications: $e');
    // Don't throw - notifications are not critical
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
    'trainerId': _currentUser.uid,
  };

  await addClassMaterialMetadataToFirestore(widget.classId, materialMetadata);

  // Get trainer's name from Firestore
  String trainerName = 'Your trainer';
  try {
    final trainerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .get();

    if (trainerDoc.exists) {
      final trainerData = trainerDoc.data()!;
      trainerName = '${trainerData['firstName'] ?? ''} ${trainerData['lastName'] ?? ''}'.trim();
      if (trainerName.isEmpty) {
        trainerName = trainerData['displayName'] ?? 'Your trainer';
      }
    }
  } catch (e) {
    debugPrint('Could not fetch trainer name: $e');
  }

  // Notify students about new material
  await _notifyStudentsAboutContent(
    action: 'New material added by $trainerName',
    contentTitle: _titleController.text.trim(),
  );

    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Material uploaded and students notified!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }

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

Future<void> _handleDownloadMaterial(ClassMaterial material) async {
  double downloadProgress = 0.0;
  bool isDownloading = false;

  try {
    // Show downloading dialog with progress
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.download,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Downloading',
                        style: TextStyle(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      material.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: isDownloading ? downloadProgress : null,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade600,
                            ),
                          ),
                        ),
                        Text(
                          isDownloading
                              ? '${(downloadProgress * 100).toStringAsFixed(0)}%'
                              : '...',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDownloading
                          ? 'Downloading file...'
                          : 'Preparing download...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    // Download file to memory using Dio
    final dio = Dio();
    final response = await dio.get(
      material.downloadURL,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total != -1 && mounted) {
          final progress = received / total;
          // Update the dialog progress
          if (Navigator.of(context).canPop()) {
            // Find and update the dialog
            final dialogContext = context;
            if (dialogContext.mounted) {
              // Use setState if we stored the setDialogState callback
              downloadProgress = progress;
              isDownloading = true;
              // Force rebuild by popping and showing updated dialog
              // Or use a better state management approach
            }
          }
          debugPrint('Download progress: ${(progress * 100).toStringAsFixed(0)}%');
        }
      },
    );

    // Close downloading dialog
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Save file with system dialog
    await FileSaver.instance.saveAs(
      name: material.fileName,
      bytes: response.data,
      fileExtension: material.fileName.split('.').last,
      mimeType: MimeType.other,
    );

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Download complete!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved: ${material.fileName}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  } catch (e) {
    // Close downloading dialog if still open
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Download failed: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    debugPrint('Download error: $e');
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

  // Get trainer's name from Firestore
  String trainerName = 'Your trainer';
  try {
    final trainerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();

    if (trainerDoc.exists) {
      final trainerData = trainerDoc.data()!;
      trainerName = '${trainerData['firstName'] ?? ''} ${trainerData['lastName'] ?? ''}'.trim();
      if (trainerName.isEmpty) {
        trainerName = trainerData['displayName'] ?? 'Your trainer';
      }
    }
  } catch (e) {
    debugPrint('Could not fetch trainer name: $e');
  }

  // Notify students about deletion
  await _notifyStudentsAboutContent(
    action: 'Material removed by $trainerName',
    contentTitle: material.title,
  );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Material deleted and students notified!'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }

    await _fetchClassData(showLoading: false);
  } catch (e) {
    setState(() => _error = "Deletion failed: ${e.toString()}");
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

Future<void> _showUpdateMaterialDialog(ClassMaterial material) async {
  final titleController = TextEditingController(text: material.title);
  final descriptionController = TextEditingController(text: material.description ?? '');

  // State variables for the new file inside the dialog
  File? newSelectedFile;
  String? newSelectedFileName;
  bool isUpdating = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Update Material',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  TextField(
                    controller: titleController,
                    enabled: !isUpdating,
                    decoration: InputDecoration(
                      labelText: 'Material Title *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  TextField(
                    controller: descriptionController,
                    enabled: !isUpdating,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Current file section
                  const Text(
                    'Current File:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FaIcon(
                            _getFileIcon(material.fileName),
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                material.fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Uploaded: ${_formatTimestamp(material.createdAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.download,
                            color: Colors.blue.shade700,
                          ),
                          onPressed: isUpdating
                              ? null
                              : () {
                                  Navigator.of(dialogContext).pop();
                                  _handleDownloadMaterial(material);
                                },
                          tooltip: 'Download current file',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Replace file section
                  const Text(
                    'Replace File (Optional):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: newSelectedFileName != null
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                      ),
                      color: newSelectedFileName != null
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.attach_file,
                        color: newSelectedFileName != null
                            ? Colors.green.shade700
                            : const Color(0xFF8B5CF6),
                      ),
                      title: Text(
                        newSelectedFileName ?? 'Select new file to replace',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: newSelectedFileName != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                          fontWeight: newSelectedFileName != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        newSelectedFileName != null
                            ? 'Tap to change or tap X to cancel'
                            : 'Current file will be kept if not selected',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: newSelectedFileName != null
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: isUpdating
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        newSelectedFile = null;
                                        newSelectedFileName = null;
                                      });
                                    },
                              tooltip: 'Cancel file replacement',
                            )
                          : const Icon(Icons.upload_file),
                      onTap: isUpdating
                          ? null
                          : () async {
                              FilePickerResult? result =
                                  await FilePicker.platform.pickFiles();
                              if (result != null) {
                                setDialogState(() {
                                  newSelectedFile = File(result.files.single.path!);
                                  newSelectedFileName = result.files.single.name;
                                });
                              }
                            },
                    ),
                  ),

                  if (isUpdating)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Column(
                        children: [
                          LinearProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Updating material...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUpdating ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isUpdating
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Title cannot be empty.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isUpdating = true);

                        try {
                          Map<String, dynamic> dataToUpdate = {
                            'title': titleController.text.trim(),
                            'description': descriptionController.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          };

                          // If a new file was selected, upload it
                          if (newSelectedFile != null) {
                            final newUploadData = await uploadClassMaterialFileToStorage(
                              widget.classId,
                              newSelectedFile!,
                              newSelectedFileName!,
                              (progress) {},
                            );

                            dataToUpdate.addAll({
                              'downloadURL': newUploadData['downloadURL'],
                              'filePath': newUploadData['filePath'],
                              'fileName': newUploadData['fileName'],
                              'fileType': newUploadData['fileType'],
                            });
                          }

                          await FirebaseFirestore.instance
                              .collection('classMaterials')
                              .doc(material.id)
                              .update(dataToUpdate);

                          // Delete old file ONLY if new file was uploaded
                          if (newSelectedFile != null) {
                            try {
                              await deleteClassMaterialFileFromStorage(material.filePath);
                            } catch (e) {
                              debugPrint('Warning: Could not delete old file: $e');
                            }
                          }

                          Navigator.of(dialogContext).pop();

                          // Get trainer's name from Firestore
                          String trainerName = 'Your trainer';
                          try {
                            final trainerDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_currentUser!.uid)
                                .get();

                            if (trainerDoc.exists) {
                              final trainerData = trainerDoc.data()!;
                              trainerName = '${trainerData['firstName'] ?? ''} ${trainerData['lastName'] ?? ''}'.trim();
                              if (trainerName.isEmpty) {
                                trainerName = trainerData['displayName'] ?? 'Your trainer';
                              }
                            }
                          } catch (e) {
                            debugPrint('Could not fetch trainer name: $e');
                          }

                          await _notifyStudentsAboutContent(
                            action: 'Material updated by $trainerName',
                            contentTitle: titleController.text.trim(),
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Material updated successfully!'),
                                  ],
                                ),
                                backgroundColor: Colors.blue,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }

                          await _fetchClassData(showLoading: false);
                        } catch (e) {
                          setDialogState(() => isUpdating = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Update failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update'),
              ),
            ],
          );
        },
      );
    },
  );
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
    // On narrow screens we just stack cards; avoids forced fixed heights.
    if (isSmallScreen) {
      return Column(
        children: List.generate(
          _materials.length,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i == _materials.length - 1 ? 0 : 12),
            child: _buildMaterialCard(_materials[i], isSmallScreen),
          ),
        ),
      );
    }

    // Wider screens: true grid.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // Smaller ratio => taller cell. Adjusted to avoid overflow.
        childAspectRatio: 2.6,
      ),
      itemCount: _materials.length,
      itemBuilder: (context, index) => _buildMaterialCard(_materials[index], isSmallScreen),
    );
  }

  Widget _buildMaterialCard(ClassMaterial material, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!, width: 1),
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
            // TODO: view/download
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Let height wrap content
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.title,
                            style: TextStyle(
                              color: const Color(0xFF1E293B),
                              fontSize: isSmallScreen ? 14 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            material.fileName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isSmallScreen ? 11 : 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MaterialIconButton(
                        color: Colors.blue.shade50,
                        iconColor: Colors.blue.shade600,
                        icon: FontAwesomeIcons.download,
                        tooltip: 'Download',
                        onTap: () => _handleDownloadMaterial(material),
                      ),
                      const SizedBox(height: 6),
                      _MaterialIconButton(
                        color: Colors.green.shade50,
                        iconColor: Colors.green.shade600,
                        icon: FontAwesomeIcons.penToSquare, // Edit icon
                        tooltip: 'Edit',
                        onTap: () => _showUpdateMaterialDialog(material),
                      ),
                      const SizedBox(height: 6),
                      _MaterialIconButton(
                        color: Colors.red.shade50,
                        iconColor: Colors.red.shade600,
                        icon: FontAwesomeIcons.trashCan,
                        tooltip: 'Delete',
                        onTap: () => _handleDeleteMaterial(material),
                      ),
                    ],
                  ),
                  ],
                ),
                if (material.description != null && material.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    material.description!,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: isSmallScreen ? 11 : 12,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Uploaded: ${_formatTimestamp(material.createdAt)}',
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

class _MaterialIconButton extends StatelessWidget {
  final Color color;
  final Color iconColor;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MaterialIconButton({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: FaIcon(icon, color: iconColor, size: 14),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}