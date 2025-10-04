import 'package:flutter/material.dart';

/// A reusable notification bell icon with an unread count badge
class NotificationBadge extends StatelessWidget {
  /// The number of unread notifications
  final int unreadCount;

  /// Callback when the notification bell is tapped
  final VoidCallback onTap;

  /// Icon color (defaults to white)
  final Color iconColor;

  /// Badge background color (defaults to red)
  final Color badgeColor;

  /// Icon size (defaults to 24)
  final double iconSize;

  const NotificationBadge({
    super.key,
    required this.unreadCount,
    required this.onTap,
    this.iconColor = Colors.white,
    this.badgeColor = Colors.red,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications,
            color: iconColor,
            size: iconSize,
          ),
          onPressed: onTap,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}