import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../firebase_service.dart';

class TrainerSignatureUpload extends StatefulWidget {
  final String? currentSignature;
  final String? currentSignaturePath;
  final Function(String?, String?) onSignatureUpdate;
  final String trainerId;

  const TrainerSignatureUpload({
    super.key,
    this.currentSignature,
    this.currentSignaturePath,
    required this.onSignatureUpdate,
    required this.trainerId,
  });

  @override
  State<TrainerSignatureUpload> createState() => _TrainerSignatureUploadState();
}

class _TrainerSignatureUploadState extends State<TrainerSignatureUpload> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  bool _uploading = false;
  String? _previewUrl;
  String? _previewPath;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.currentSignature;
    _previewPath = widget.currentSignaturePath;
  }

  Future<void> _handleFileSelect() async {
    try {
      // Pick image from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 400,
        imageQuality: 90,
      );

      if (image == null) return;

      final File imageFile = File(image.path);

      // Validate file size (max 2MB)
      final fileSize = await imageFile.length();
      if (fileSize > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ File size must be less than 2MB'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });

      // Upload to Firebase Storage
      final result = await _firebaseService.uploadTrainerSignature(
        widget.trainerId,
        imageFile,
        (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      // Update Firestore
      await _firebaseService.updateTrainerSignature(
        widget.trainerId,
        result['downloadURL'],
        result['filePath'],
      );

      setState(() {
        _previewUrl = result['downloadURL'];
        _previewPath = result['filePath'];
      });

      widget.onSignatureUpdate(result['downloadURL'], result['filePath']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('✅ Signature uploaded successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading signature: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to upload signature: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _uploading = false;
        _uploadProgress = 0;
      });
    }
  }

  Future<void> _handleRemoveSignature() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Signature?'),
        content: const Text('Are you sure you want to remove your signature?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _uploading = true);

    try {
      // Delete from Storage if path exists
      if (_previewPath != null && _previewPath!.isNotEmpty) {
        await _firebaseService.deleteTrainerSignature(_previewPath!);
      }

      // Update Firestore
      await _firebaseService.updateTrainerSignature(
        widget.trainerId,
        null,
        null,
      );

      setState(() {
        _previewUrl = null;
        _previewPath = null;
      });

      widget.onSignatureUpdate(null, null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('✅ Signature removed successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing signature: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to remove signature: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.signature,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your E-Signature',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This signature will appear on certificates you authorize',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Preview Area
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _previewUrl != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.network(
                            _previewUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load signature',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Current signature',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.signature,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No signature uploaded yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 20),

          // Upload Progress (if uploading)
          if (_uploading) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Uploading...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    Text(
                      '${_uploadProgress.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _uploadProgress / 100,
                  backgroundColor: Colors.blue.shade100,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF3B82F6),
                  ),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _handleFileSelect,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(FontAwesomeIcons.upload, size: 16),
                  label: Text(
                    _uploading
                        ? 'Uploading...'
                        : _previewUrl != null
                        ? 'Replace Signature'
                        : 'Upload Signature',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              if (_previewUrl != null && !_uploading) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _handleRemoveSignature,
                  icon: const Icon(FontAwesomeIcons.trash, size: 16),
                  label: const Text('Remove'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Tips Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tips for best results:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...[
                  '• Use a transparent background (PNG format) for best results',
                  '• Horizontal signatures work best (landscape orientation)',
                  '• Dark ink (black/blue) shows up clearer than light colors',
                  '• Recommended size: 600x200 pixels or larger',
                  '• High resolution = sharper signature on certificates',
                  '• Avoid very thin lines (they may not print well)',
                  '• Maximum file size: 2MB',
                ].map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
