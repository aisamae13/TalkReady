import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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
        // The stream will automatically update the UI
      } catch (e) {
        // Handle error silently or show a toast
        debugPrint('Error marking notification as read: $e');
      }
    }

    // Navigate to link if available
    if (data['link'] != null && data['link'] is String) {
      Navigator.pushNamed(context, data['link']);
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