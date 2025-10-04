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
      .orderBy('createdAt', descending: true)  // Remove the isRead filter
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
      // The stream will automatically update the UI
    } catch (e) {
      // Handle error silently or show a toast
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Check notification type
  final notificationType = data['type'] as String?;

  // Handle removal notifications differently - just show a dialog
  if (notificationType == 'removal') {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700),
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
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
    return; // Don't try to navigate
  }

  // Handle navigation based on link pattern (only if link exists)
  if (data['link'] != null && data['link'] is String) {
    final link = data['link'] as String;

    try {
      // Handle assessment submission review links
      if (link.contains('/student/submission/') && link.contains('review')) {
        // Extract submissionId from URL path
        String submissionId = '';
        if (link.contains('/student/submission/')) {
          List<String> parts = link.split('/student/submission/');
          if (parts.length > 1) {
            submissionId = parts[1].split('/review').first;
          }
        }

        // Extract assessmentId from query parameters
        String? assessmentId;
        if (link.contains('assessmentId=')) {
          assessmentId = link.split('assessmentId=')[1];
          if (assessmentId.contains('&')) {
            assessmentId = assessmentId.split('&').first;
          }
        }

        if (assessmentId != null && submissionId.isNotEmpty) {
          debugPrint('Navigating to assessment review with ID: $assessmentId, submission: $submissionId');

          // Navigate to the assessment review page directly
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
        // Extract classId from the link
        String classId = '';
        List<String> parts = link.split('/student/class/');
        if (parts.length > 1) {
          classId = parts[1];

          // Remove any content part or hash fragments
          if (classId.contains('/content')) {
            classId = classId.split('/content')[0];
          }

          if (classId.contains('#')) {
            classId = classId.split('#')[0];
          }

          classId = classId.trim();
        }

        if (classId.isNotEmpty) {
          debugPrint('Navigating to class content: $classId');
          // Get class details from Firestore
          try {
            final classDoc = await FirebaseFirestore.instance
                .collection('trainerClass')
                .doc(classId)
                .get();

            if (classDoc.exists) {
              final classData = classDoc.data() ?? {};
              final className = classData['className'] ?? 'Class';

              // Navigate to the class content page
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
              const SnackBar(
                content: Text('Could not find the class. It may have been deleted.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }

      // Fallback to standard route navigation if specific patterns don't match
      else {
        // Try to navigate using named route
        try {
          Navigator.pushNamed(context, link);
        } catch (e) {
          debugPrint('Navigation error: $e');
          // If navigation fails, just show a message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This notification has no associated page'),
                backgroundColor: Colors.grey,
              ),
            );
          }
        }
      }

    } catch (e) {
      debugPrint('Error navigating from notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this notification content'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } else {
    // No link provided - just show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Notification'),
          duration: const Duration(seconds: 3),
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
          const SnackBar(
            content: Text('Notification deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete notification'),
            backgroundColor: Colors.red,
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
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark notifications as read'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive design
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
      title: const Text('All Notifications'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_unreadCount > 0)
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              'Mark All Read',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(bool isTablet) {
    if (_loading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border(left: BorderSide(color: Colors.red, width: 4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: isTablet ? 32 : 24),
            SizedBox(width: isTablet ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 18 : 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ],
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
          Icon(
            Icons.mark_email_read_outlined,
            size: isTablet ? 80 : 60,
            color: Colors.grey,
          ),
          SizedBox(height: isTablet ? 24 : 16),
          Text(
            'No Notifications Yet',
            style: TextStyle(
              fontSize: isTablet ? 28 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            'You currently have no notifications.',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: Colors.grey,
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
      separatorBuilder: (_, __) => SizedBox(height: isTablet ? 16 : 12),
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

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notification),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isTablet ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete,
          color: Colors.white,
          size: isTablet ? 32 : 24,
        ),
      ),
      child: GestureDetector(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : Colors.blue[50],
            border: Border.all(
              color: isRead ? Colors.grey[200]! : Colors.blue[200]!,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        color: isRead ? Colors.black87 : Colors.blue[900],
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (!isRead) ...[
                    SizedBox(width: isTablet ? 12 : 8),
                    Container(
                      width: isTablet ? 12 : 10,
                      height: isTablet ? 12 : 10,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: isTablet ? 12 : 10),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: isTablet ? 18 : 16,
                    color: Colors.grey,
                  ),
                  SizedBox(width: isTablet ? 8 : 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 13,
                      color: Colors.grey,
                    ),
                  ),
                  if (className != null) ...[
                    SizedBox(width: isTablet ? 16 : 12),
                    Container(
                      height: isTablet ? 20 : 18,
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    SizedBox(width: isTablet ? 12 : 8),
                    Flexible(
                      child: Text(
                        'Class: $className',
                        style: TextStyle(
                          fontSize: isTablet ? 15 : 13,
                          color: Colors.grey,
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
    );
  }
}