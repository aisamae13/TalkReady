import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser?.uid;
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
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
    try {
      final query = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true);
      final snapshot = await query.get();
      setState(() {
        _notifications = snapshot.docs;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load notifications. Please try again.";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _handleNotificationTap(DocumentSnapshot notif) async {
    final data = notif.data() as Map<String, dynamic>;
    if (!(data['isRead'] ?? false)) {
      await notif.reference.update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notif.id) {
            final updated = Map<String, dynamic>.from(n.data() as Map<String, dynamic>);
            updated['isRead'] = true;
            return _FakeDocSnapshot(n.id, updated);
          }
          return n;
        }).toList();
      });
    }
    if (data['link'] != null && data['link'] is String) {
      // You can use Navigator.pushNamed(context, data['link']) if your routes are set up
      Navigator.pushNamed(context, data['link']);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Notifications'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _error != null
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border(left: BorderSide(color: Colors.red, width: 4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(_error!, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.mark_email_read_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No Notifications Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('You currently have no notifications.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final data = notif.data() as Map<String, dynamic>;
                      final isRead = data['isRead'] ?? false;
                      final message = data['message'] ?? '';
                      final className = data['className'];
                      final Timestamp? createdAt = data['createdAt'];
                      final dateStr = createdAt != null
                          ? DateTime.fromMillisecondsSinceEpoch(createdAt.millisecondsSinceEpoch)
                              .toLocal()
                              .toString()
                          : 'Recently';
                      return GestureDetector(
                        onTap: () => _handleNotificationTap(notif),
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
                                blurRadius: 4,
                                offset: const Offset(0, 2),
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
                                        fontSize: 16,
                                        color: isRead ? Colors.black87 : Colors.blue[900],
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8, top: 2),
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                  if (className != null) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      height: 18,
                                      width: 1,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Class: $className',
                                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

// Helper class to update local notification state
class _FakeDocSnapshot implements DocumentSnapshot {
  @override
  final String id;
  final Map<String, dynamic> _data;
  _FakeDocSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;

  // The rest of the DocumentSnapshot interface can throw UnimplementedError for this local use
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}