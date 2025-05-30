import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp

class ClassListItemWidget extends StatelessWidget {
  final Map<String, dynamic> classData;
  final Function(String classId, String className) onDeleteClass;
  // final Function(String classId) onNavigateToDashboard; // Or handle navigation directly

  const ClassListItemWidget({
    Key? key,
    required this.classData,
    required this.onDeleteClass,
    // required this.onNavigateToDashboard,
  }) : super(key: key);

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMd().format(timestamp.toDate());
    } else if (timestamp is String) {
      try {
        return DateFormat.yMd().format(DateTime.parse(timestamp));
      } catch (e) {
        //
      }
    }
    return "Date not set";
  }

  @override
  Widget build(BuildContext context) {
    final String className = classData['className'] as String? ?? "Unnamed Class";
    final String description = classData['description'] as String? ?? "No description available.";
    final int studentCount = classData['studentCount'] as int? ?? 0;
    final String subject = classData['subject'] as String? ?? "General";
    final String classId = classData['id'] as String? ?? '';
    final String createdAtDisplay = _formatDate(classData['createdAt']);

    if (classId.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text("Error: Class data incomplete"),
        ),
      );
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          // Navigate to class dashboard
          Navigator.pushNamed(context, '/trainer/class/$classId/dashboard');
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                className,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              if (subject.isNotEmpty)
                Text(
                  "Subject: $subject",
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[600]),
                ),
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(FontAwesomeIcons.users, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    "$studentCount Student${studentCount != 1 ? 's' : ''}",
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Created: $createdAtDisplay",
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(FontAwesomeIcons.bookOpen, size: 14),
                      label: const Text("Content"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trainer/class/$classId/content');
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(FontAwesomeIcons.usersCog, size: 14),
                      label: const Text("Students"),
                       style: TextButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trainer/class/$classId/students');
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(FontAwesomeIcons.edit, size: 14),
                      label: const Text("Edit"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trainer/class/$classId/edit');
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(FontAwesomeIcons.trashAlt, size: 14),
                      label: const Text("Delete"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => onDeleteClass(classId, className),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}