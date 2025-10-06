import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkready_mobile/progress_page.dart';
import 'dart:async';
import 'class_content_page.dart';

class AllNotificationsPage extends StatefulWidget {
  const AllNotificationsPage({super.key});

  @override
  State<AllNotificationsPage> createState() => _AllNotificationsPageState();
}

class _AllNotificationsPageState extends State<AllNotificationsPage> {
  final _auth = FirebaseAuth.instance;
  late final String? _uid;
  bool _loading = true;
  String? _error;
  List<DocumentSnapshot> _notifications = [];
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser?.uid;
    _startListeningToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _startListeningToNotifications() {
    if (_uid == null) {
      setState(() {
        _error = "Please log in to view your notifications.";
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _notifications = snapshot.docs;
            _loading = false;
            _error = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = "Failed to load notifications. Please try again.";
            _loading = false;
          });
        }
      },
    );
  }

  Future<void> _refreshNotifications() async {
    _startListeningToNotifications();
  }

  Future<void> _handleNotificationTap(DocumentSnapshot notif) async {
    final data = notif.data() as Map<String, dynamic>;

    // Mark as read if unread
    if (!(data['isRead'] ?? false)) {
      try {
        await notif.reference.update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error marking notification as read: $e');
      }
    }

    // Check notification type
    final notificationType = data['type'] as String?;

    // Handle removal notifications differently
    if (notificationType == 'removal') {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.info_outline, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Class Removal'),
              ],
            ),
            content: Text(
              data['message'] ?? 'You have been removed from a class.',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Handle navigation based on link pattern
    if (data['link'] != null && data['link'] is String) {
      final link = data['link'] as String;

      try {
        // Handle assessment submission review links
        if (link.contains('/student/submission/') && link.contains('review')) {
          String submissionId = '';
          if (link.contains('/student/submission/')) {
            List<String> parts = link.split('/student/submission/');
            if (parts.length > 1) {
              submissionId = parts[1].split('/review').first;
            }
          }

          String? assessmentId;
          if (link.contains('assessmentId=')) {
            assessmentId = link.split('assessmentId=')[1];
            if (assessmentId.contains('&')) {
              assessmentId = assessmentId.split('&').first;
            }
          }

          if (assessmentId != null && submissionId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssessmentReviewPage(
                  assessmentId: assessmentId!,
                  submissionId: submissionId,
                ),
              ),
            );
            return;
          }
        }

        // Handle class content links
        else if (link.contains('/student/class/')) {
          String classId = '';
          List<String> parts = link.split('/student/class/');
          if (parts.length > 1) {
            classId = parts[1];

            if (classId.contains('/content')) {
              classId = classId.split('/content')[0];
            }

            if (classId.contains('#')) {
              classId = classId.split('#')[0];
            }

            classId = classId.trim();
          }

          if (classId.isNotEmpty) {
            try {
              final classDoc = await FirebaseFirestore.instance
                  .collection('trainerClass')
                  .doc(classId)
                  .get();

              if (classDoc.exists) {
                final classData = classDoc.data() ?? {};
                final className = classData['className'] ?? 'Class';

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClassContentPage(
                      classId: classId,
                      className: className,
                      classData: classData,
                    ),
                  ),
                );
                return;
              } else {
                throw Exception('Class not found');
              }
            } catch (e) {
              debugPrint('Error fetching class data: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Could not find the class. It may have been deleted.'),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        }

        // Fallback navigation
        else {
          try {
            Navigator.pushNamed(context, link);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('This notification has no associated page'),
                  backgroundColor: Colors.grey.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open this notification content'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Notification'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(DocumentSnapshot notif) async {
    try {
      await notif.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Notification deleted'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete notification'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final unreadNotifications = _notifications
        .where((notif) => !((notif.data() as Map<String, dynamic>)['isRead'] ?? false))
        .toList();

    if (unreadNotifications.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final notif in unreadNotifications) {
      batch.update(notif.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('All notifications marked as read'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to mark notifications as read'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  int get _unreadCount {
    return _notifications
        .where((notif) => !((notif.data() as Map<String, dynamic>)['isRead'] ?? false))
        .length;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Recently';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'material':
        return Icons.folder_outlined;
      case 'assessment':
        return Icons.assignment_outlined;
      case 'enrollment':
        return Icons.person_add_outlined;
      case 'removal':
        return Icons.person_remove_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'material':
        return const Color(0xFF14B8A6); // Teal
      case 'assessment':
        return const Color(0xFF8B5CF6); // Purple
      case 'enrollment':
        return const Color(0xFF10B981); // Green
      case 'removal':
        return const Color(0xFFF59E0B); // Orange
      default:
        return const Color(0xFF2563EB); // Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        color: const Color(0xFF2563EB),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;
            final horizontalPadding = isTablet ? 32.0 : 16.0;
            final maxWidth = isTablet ? 800.0 : double.infinity;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _buildContent(isTablet),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'Notifications',
        style: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_unreadCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.done_all,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _buildContent(bool isTablet) {
    if (_loading && _notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading notifications...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorWidget(_error!, isTablet);
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState(isTablet);
    }

    return _buildNotificationsList(isTablet);
  }

  Widget _buildErrorWidget(String error, bool isTablet) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(isTablet ? 32 : 16),
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: isTablet ? 48 : 40,
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              'Error',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 20 : 18,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 32 : 24),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(
              Icons.notifications_none_outlined,
              size: isTablet ? 80 : 64,
              color: const Color(0xFF2563EB),
            ),
          ),
          SizedBox(height: isTablet ? 24 : 20),
          Text(
            'No Notifications',
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isTablet) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 24 : 16),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => SizedBox(height: isTablet ? 12 : 10),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification, isTablet);
      },
    );
  }

  Widget _buildNotificationCard(DocumentSnapshot notification, bool isTablet) {
    final data = notification.data() as Map<String, dynamic>;
    final isRead = data['isRead'] ?? false;
    final message = data['message'] ?? '';
    final className = data['className'];
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = _formatDate(createdAt);
    final type = data['type'] as String?;
    final icon = _getNotificationIcon(type);
    final iconColor = _getNotificationColor(type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notification),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isTablet ? 24 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: isTablet ? 32 : 28,
        ),
      ),
      child: GestureDetector(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFF2563EB).withOpacity(0.3),
              width: isRead ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isRead
                    ? Colors.black.withOpacity(0.03)
                    : const Color(0xFF2563EB).withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon section
              Container(
                width: isTablet ? 80 : 72,
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isTablet ? 32 : 28,
                ),
              ),
              // Content section
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 15,
                                color: const Color(0xFF1E293B),
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: isTablet ? 10 : 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: isTablet ? 16 : 14,
                            color: const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          if (className != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                className,
                                style: TextStyle(
                                  fontSize: isTablet ? 13 : 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}