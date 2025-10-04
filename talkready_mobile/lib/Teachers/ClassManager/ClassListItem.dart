import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'ManageClassContent.dart';
import '../TrainerClassDashboardPage.dart';

class ClassListItemWidget extends StatefulWidget {
  final Map<String, dynamic> classData;
  final Function(String classId, String className) onDeleteClass;

  const ClassListItemWidget({
    super.key,
    required this.classData,
    required this.onDeleteClass,
  });

  @override
  State<ClassListItemWidget> createState() => _ClassListItemWidgetState();
}

class _ClassListItemWidgetState extends State<ClassListItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMd().format(timestamp.toDate());
    } else if (timestamp is String) {
      try {
        return DateFormat.yMd().format(DateTime.parse(timestamp));
      } catch (e) {
        // Handle error silently
      }
    }
    return "Date not set";
  }

  @override
  Widget build(BuildContext context) {
    final String className =
        widget.classData['className'] as String? ?? "Unnamed Class";
    final String description =
        widget.classData['description'] as String? ??
        "No description available.";
    final int studentCount = widget.classData['studentCount'] as int? ?? 0;
    final String subject = widget.classData['subject'] as String? ?? "General";
    final String classId = widget.classData['id'] as String? ?? '';
    final String createdAtDisplay = _formatDate(widget.classData['createdAt']);

    if (classId.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.red.shade50, Colors.red.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, color: Colors.red.shade700),
              ),
              title: Text(
                "Error: Class data incomplete",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.blue.shade50.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(-5, -5),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TrainerClassDashboardPage(
                                  classId: widget.classData['id'],
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Colors.blue.shade100.withOpacity(0.3),
                          highlightColor: Colors.blue.shade50.withOpacity(0.2),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(className, context),
                                if (subject.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildSubject(subject),
                                ],
                                const SizedBox(height: 16),
                                _buildClassCodeSection(),
                                const SizedBox(height: 16),
                                _buildDescription(description),
                                const SizedBox(height: 16),
                                _buildStats(studentCount, createdAtDisplay),
                                const SizedBox(height: 20),
                                _buildDivider(),
                                const SizedBox(height: 16),
                                _buildActionButtons(classId, className),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(String className, BuildContext context) {
    return Row(
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
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const FaIcon(
            FontAwesomeIcons.chalkboardUser,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            className,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: 0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSubject(String subject) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade100, Colors.blue.shade100],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Text(
        "Subject: $subject",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.purple.shade700,
          fontStyle: FontStyle.italic,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDescription(String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Text(
        description,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF64748B),
          height: 1.4,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStats(int studentCount, String createdAtDisplay) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade100, Colors.green.shade50],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FontAwesomeIcons.users,
                  size: 14,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "$studentCount Student${studentCount != 1 ? 's' : ''}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            "Created: $createdAtDisplay",
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey.shade300,
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String classId, String className) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we should use a single column layout for narrow screens
        final bool useColumnLayout = constraints.maxWidth < 500;

        final List<Widget> buttons = [
          _buildActionButton(
            icon: FontAwesomeIcons.fileLines,
            label: "Content",
            colors: [Colors.teal.shade400, Colors.teal.shade600],
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ManageClassContentPage(classId: widget.classData['id']),
                ),
              );
            },
          ),
          _buildActionButton(
            icon: FontAwesomeIcons.usersGear,
            label: "Students",
            colors: [Colors.green.shade400, Colors.green.shade600],
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/trainer/classes/$classId/students',
              );
            },
          ),
          _buildActionButton(
            icon: FontAwesomeIcons.penToSquare,
            label: "Edit",
            colors: [Colors.orange.shade400, Colors.orange.shade600],
            onPressed: () {
              Navigator.pushNamed(context, '/trainer/classes/$classId/edit');
            },
          ),
          _buildActionButton(
            icon: FontAwesomeIcons.trashCan,
            label: "Delete",
            colors: [Colors.red.shade400, Colors.red.shade600],
            onPressed: () => widget.onDeleteClass(classId, className),
          ),
        ];

        if (useColumnLayout) {
          // Stack buttons vertically for narrow screens
          return Column(
            children: buttons
                .map(
                  (button) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: button,
                  ),
                )
                .toList(),
          );
        } else {
          // Use wrap for wider screens
          return Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.end,
            children: buttons,
          );
        }
      },
    );
  }

  Widget _buildClassCodeSection() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FaIcon(FontAwesomeIcons.tag, size: 14, color: Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          'Code:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          widget.classData['classCode'] ?? 'N/A',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(text: widget.classData['classCode']),
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Class code copied!'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
          child: const FaIcon(
            FontAwesomeIcons.solidCopy,
            size: 14,
            color: Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: const BoxConstraints(minWidth: 100),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
}
