// screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import 'chat_screen.dart';
import '../services/chat_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    // Get all types of notifications
    final allNotifications = await _getAllNotifications();

    setState(() {
      _notifications = allNotifications;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _getAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> allNotifications = [];

    // 1. Emulator notifications
    final currentUserId = prefs.getString('user_id');
    if (currentUserId != null) {
      final String? emulatorNotificationsJson = prefs.getString('emulator_notifications_$currentUserId');
      if (emulatorNotificationsJson != null) {
        final List<dynamic> emulatorNotifications = json.decode(emulatorNotificationsJson);
        allNotifications.addAll(emulatorNotifications.map((item) {
          final notification = Map<String, dynamic>.from(item);
          notification['source'] = 'emulator';
          return notification;
        }).toList());
      }
    }

    // 2. In-app notifications
    final String? inAppNotificationsJson = prefs.getString('in_app_notifications');
    if (inAppNotificationsJson != null) {
      final List<dynamic> inAppNotifications = json.decode(inAppNotificationsJson);
      final currentUserId = prefs.getString('user_id');

      // Filter notifications for current user only
      final userInAppNotifications = inAppNotifications.where((notification) {
        return notification['targetUserId'] == currentUserId;
      }).map((item) {
        final notification = Map<String, dynamic>.from(item);
        notification['source'] = 'in_app';
        return notification;
      }).toList();

      allNotifications.addAll(userInAppNotifications);
    }

    // 3. Stored notifications from FCM
    final String? storedNotificationsJson = prefs.getString('stored_notifications');
    if (storedNotificationsJson != null) {
      final List<dynamic> storedNotifications = json.decode(storedNotificationsJson);
      allNotifications.addAll(storedNotifications.map((item) {
        final notification = Map<String, dynamic>.from(item);
        notification['source'] = 'system';
        return notification;
      }).toList());
    }

    // Sort notifications from newest to oldest
    allNotifications.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    return allNotifications;
  }

  Future<void> _markAsRead(String notificationId, String source) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      switch (source) {
        case 'emulator':
          final currentUserId = prefs.getString('user_id');
          if (currentUserId != null) {
            final String? notificationsJson = prefs.getString('emulator_notifications_$currentUserId');
            if (notificationsJson != null) {
              List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(json.decode(notificationsJson));

              for (var i = 0; i < notifications.length; i++) {
                if (notifications[i]['id'] == notificationId) {
                  notifications[i]['read'] = true;
                  break;
                }
              }

              await prefs.setString('emulator_notifications_$currentUserId', json.encode(notifications));
            }
          }
          break;

        case 'in_app':
          final String? notificationsJson = prefs.getString('in_app_notifications');
          if (notificationsJson != null) {
            List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(json.decode(notificationsJson));

            for (var i = 0; i < notifications.length; i++) {
              if (notifications[i]['id'] == notificationId) {
                notifications[i]['read'] = true;
                break;
              }
            }

            await prefs.setString('in_app_notifications', json.encode(notifications));
          }
          break;
      }

      await _loadNotifications(); // Reload the list

    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id');

      // Update emulator notifications
      if (currentUserId != null) {
        final String? emulatorNotificationsJson = prefs.getString('emulator_notifications_$currentUserId');
        if (emulatorNotificationsJson != null) {
          List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(json.decode(emulatorNotificationsJson));

          for (var notification in notifications) {
            notification['read'] = true;
          }

          await prefs.setString('emulator_notifications_$currentUserId', json.encode(notifications));
        }
      }

      // Update app notifications
      final String? inAppNotificationsJson = prefs.getString('in_app_notifications');
      if (inAppNotificationsJson != null) {
        List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(json.decode(inAppNotificationsJson));

        for (var notification in notifications) {
          if (notification['targetUserId'] == currentUserId) {
            notification['read'] = true;
          }
        }

        await prefs.setString('in_app_notifications', json.encode(notifications));
      }

      await _loadNotifications();

    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  Future<void> _onNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read
    await _markAsRead(notification['id'], notification['source'] ?? 'in_app');

    // If it's a chat notification, open the chat
    if (notification['type'] == 'chat' && notification['chatRoomId'] != null) {
      final chatRoom = await _chatService.getChatRoomById(notification['chatRoomId']);
      if (chatRoom != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatRoom: chatRoom,
              chatService: _chatService,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: AppColors.textLight.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All notifications you receive will appear here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final isRead = notification['read'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: isRead ? AppColors.surface : AppColors.accent1.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: _buildNotificationIcon(notification),
              title: Text(
                _getNotificationTitle(notification),
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    _getNotificationBody(notification),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(DateTime.parse(notification['timestamp'])),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (notification['source'] == 'emulator')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Emulator',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              trailing: !isRead
                  ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              )
                  : null,
              onTap: () => _onNotificationTap(notification),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationIcon(Map<String, dynamic> notification) {
    switch (notification['type']) {
      case 'chat':
        return CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.chat, color: Colors.white, size: 20),
        );
      default:
        return CircleAvatar(
          backgroundColor: AppColors.accent2,
          child: Icon(Icons.notifications, color: Colors.white, size: 20),
        );
    }
  }

  String _getNotificationTitle(Map<String, dynamic> notification) {
    switch (notification['type']) {
      case 'chat':
        return 'New message from ${notification['senderName'] ?? 'User'}';
      default:
        return notification['title'] ?? 'New notification';
    }
  }

  String _getNotificationBody(Map<String, dynamic> notification) {
    switch (notification['type']) {
      case 'chat':
        return notification['message'] ?? '';
      default:
        return notification['body'] ?? notification['message'] ?? '';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${time.day}/${time.month}/${time.year}';
  }
}