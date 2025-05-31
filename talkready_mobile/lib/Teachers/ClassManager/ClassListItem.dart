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
    final theme = Theme.of(context);

    if (classId.isEmpty) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
          title: Text("Error: Class data incomplete", style: TextStyle(color: theme.colorScheme.onErrorContainer)),
        ),
      );
    }

    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/trainer/class/$classId/dashboard');
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: theme.primaryColor.withOpacity(0.1),
        highlightColor: theme.primaryColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                className,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              if (subject.isNotEmpty)
                Text(
                  "Subject: $subject",
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.85)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(FontAwesomeIcons.users, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    "$studentCount Student${studentCount != 1 ? 's' : ''}",
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Created: $createdAtDisplay",
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
              ),
              const SizedBox(height: 16),
              Divider(color: theme.dividerColor.withOpacity(0.5), height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(FontAwesomeIcons.bookOpenReader, size: 14),
                      label: const Text("Content"),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trainer/class/$classId/content');
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(FontAwesomeIcons.usersGear, size: 14),
                      label: const Text("Students"),
                       style: TextButton.styleFrom(
                        foregroundColor: Colors.green.shade700, // Or theme.colorScheme.tertiary
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trainer/class/$classId/students');
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(FontAwesomeIcons.penToSquare, size: 14),
                      label: const Text("Edit"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700, // Or theme.colorScheme.tertiary
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trainer/class/$classId/edit');
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(FontAwesomeIcons.trashCan, size: 14),
                      label: const Text("Delete"),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
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