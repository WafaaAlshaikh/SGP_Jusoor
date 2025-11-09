// screens/chat_screen.dart
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';
import '../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final ChatService chatService;

  const ChatScreen({
    super.key,
    required this.chatRoom,
    required this.chatService,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Stream<List<ChatMessage>>? _messagesStream;
  bool _isTyping = false;
  Set<String> _seenMessages = {}; // 🆕 NEW: تتبع الرسائل المقروءة

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAllMessagesAsSeen(); // 🆕 NEW: وضع علامة مقروء عند فتح الشات
  }

  void _loadMessages() {
    _messagesStream = widget.chatService.getChatMessages(widget.chatRoom.id);
  }

  // 🆕 NEW: وضع علامة مقروء على جميع الرسائل عند فتح الشات
  void _markAllMessagesAsSeen() async {
    try {
      await widget.chatService.markAllMessagesAsSeen(widget.chatRoom.id);
      print('👀 All messages marked as seen');
    } catch (e) {
      print('❌ Error marking messages as seen: $e');
    }
  }

  // 🆕 NEW: وضع علامة مقروء على رسالة محددة
  void _markMessageAsSeen(String messageId) async {
    if (_seenMessages.contains(messageId)) return;

    try {
      await widget.chatService.markMessageAsSeen(messageId, widget.chatRoom.id);
      setState(() {
        _seenMessages.add(messageId);
      });
    } catch (e) {
      print('❌ Error marking message as seen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textWhite,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 24),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accent1,
            radius: 18,
            child: Text(
              widget.chatRoom.name[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatRoom.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                StreamBuilder<List<ChatMessage>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final lastMessage = snapshot.data!.last;
                      final isOnline = _isUserOnline(lastMessage.timestamp);

                      return Text(
                        isOnline ? 'Online' : 'Last seen ${_formatLastSeen(lastMessage.timestamp)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isOnline ? AppColors.success : AppColors.textLight,
                        ),
                      );
                    }
                    return const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.success,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, size: 22),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call, size: 22),
          onPressed: () {},
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 22),
          onSelected: (value) {
            _handleAppBarAction(value);
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'view_profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('View Profile'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'media',
              child: Row(
                children: [
                  Icon(Icons.photo_library, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Media & Files'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'search',
              child: Row(
                children: [
                  Icon(Icons.search, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Search Messages'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'clear_chat',
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Clear Chat', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🆕 NEW: معالجة إجراءات AppBar
  void _handleAppBarAction(String value) {
    switch (value) {
      case 'clear_chat':
        _showClearChatDialog();
        break;
      case 'search':
        _showSearchDialog();
        break;
    // يمكن إضافة المزيد من الإجراءات
    }
  }

  // 🆕 NEW: حذف المحادثة
  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // هنا بتكون عملية حذف الرسائل
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // 🆕 NEW: البحث في المحادثة
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Messages'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Type to search...'),
          onChanged: (query) {
            // هنا بتكون عملية البحث
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // تنفيذ البحث
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget('Failed to load messages');
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyChat();
        }

        final messages = snapshot.data!;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == widget.chatService.currentUserId;

            // 🆕 UPDATED: تحسين منطق عرض التواريخ
            final showTimestamp = _shouldShowTimestamp(messages, index, message);

            return Column(
              children: [
                if (showTimestamp) _buildDateDivider(message.timestamp),
                _MessageBubble(
                  message: message,
                  isMe: isMe,
                  showAvatar: _shouldShowAvatar(messages, index, message),
                  onSeen: () => _markMessageAsSeen(message.id), // 🆕 NEW: callback للـ seen
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🆕 NEW: منطق محسن لعرض التواريخ
  bool _shouldShowTimestamp(List<ChatMessage> messages, int index, ChatMessage currentMessage) {
    if (index == 0) return true;

    final previousMessage = messages[index - 1];
    final timeDifference = currentMessage.timestamp.difference(previousMessage.timestamp);

    // عرض التاريخ إذا:
    // 1. تغير اليوم
    // 2. الفرق أكثر من 30 دقيقة
    // 3. أول رسالة في اليوم
    return _isDifferentDay(previousMessage.timestamp, currentMessage.timestamp) ||
        timeDifference.inMinutes > 30 ||
        index == 0;
  }

  // 🆕 NEW: منطق محسن لعرض الصورة
  bool _shouldShowAvatar(List<ChatMessage> messages, int index, ChatMessage currentMessage) {
    if (currentMessage.senderId == widget.chatService.currentUserId) return false;

    if (index == messages.length - 1) return true;

    final nextMessage = messages[index + 1];
    return nextMessage.senderId != currentMessage.senderId;
  }

  // 🆕 NEW: التحقق من اختلاف اليوم
  bool _isDifferentDay(DateTime date1, DateTime date2) {
    return date1.year != date2.year ||
        date1.month != date2.month ||
        date1.day != date2.day;
  }

  // 🆕 NEW: التحقق إذا المستخدم متصل
  bool _isUserOnline(DateTime lastSeen) {
    final now = DateTime.now();
    return now.difference(lastSeen).inMinutes < 5; // يعتبر متصل إذا كان نشط منذ أقل من 5 دقائق
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMessages,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppColors.textLight.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send your first message to begin chatting',
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

  Widget _buildDateDivider(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatDate(timestamp),
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (!_isTyping) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.theirMessage,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypingDot(0),
            _buildTypingDot(1),
            _buildTypingDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 8,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment Button
          Container(
            decoration: BoxDecoration(
              color: AppColors.accent1,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.attach_file, color: AppColors.primary),
              onPressed: _showAttachmentMenu,
            ),
          ),
          const SizedBox(width: 8),

          // Voice Message Button
          Container(
            decoration: BoxDecoration(
              color: AppColors.accent1,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.mic, color: AppColors.primary),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 8),

          // Message Input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: TextStyle(color: AppColors.textLight),
                ),
                maxLines: null,
                onChanged: (text) {
                  setState(() {
                    _isTyping = text.isNotEmpty;
                  });
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: AppColors.textWhite),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(Icons.photo, 'Gallery', () {}),
                  _buildAttachmentOption(Icons.camera_alt, 'Camera', () {}),
                  _buildAttachmentOption(Icons.attach_file, 'Document', () {}),
                  _buildAttachmentOption(Icons.location_on, 'Location', () {}),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.accent1,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: AppColors.primary, size: 24),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await widget.chatService.sendMessage(
        chatRoomId: widget.chatRoom.id,
        content: message,
        type: 'text',
      );

      _messageController.clear();
      setState(() {
        _isTyping = false;
      });

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatLastSeen(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String _formatDate(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return 'Today';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageDay).inDays < 7) {
      // الأيام السبعة الماضية
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[messageDay.weekday - 1];
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onSeen; // 🆕 NEW: callback للـ seen

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    this.onSeen,
  });

  @override
  Widget build(BuildContext context) {
    // 🆕 NEW: استدعاء callback عندما تكون الرسالة مرئية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMe && onSeen != null && !message.isRead) {
        onSeen!();
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.accent2,
              child: Text(
                message.senderName[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.myMessage : AppColors.theirMessage,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? AppColors.messageTextMe : AppColors.messageTextThem,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? AppColors.textWhite.withOpacity(0.7) : AppColors.textLight,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        // 🆕 UPDATED: نظام الـ seen المحسن
                        _buildMessageStatus(message),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe && showAvatar) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                'Me',
                style: TextStyle(
                  fontSize: 8,
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🆕 NEW: بناء حالة الرسالة (Seen/Delivered/Sent)
  Widget _buildMessageStatus(ChatMessage message) {
    IconData icon;
    Color color;

    if (message.isRead) {
      icon = Icons.done_all;
      color = AppColors.success; // ✅ مقروء - لون أخضر
    } else if (message.readBy.length > 1) {
      icon = Icons.done_all;
      color = AppColors.textWhite.withOpacity(0.7); // ✅ موصل - لون أبيض شفاف
    } else {
      icon = Icons.done;
      color = AppColors.textWhite.withOpacity(0.7); // ✅ مرسل - لون أبيض شفاف
    }

    return Icon(
      icon,
      size: 12,
      color: color,
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}