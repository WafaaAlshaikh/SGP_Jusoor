// screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';
import 'chat_screen.dart';
import 'select_user_screen.dart';
import '../theme/app_colors.dart';
import '../services/user_service.dart';
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  Stream<List<ChatRoom>>? _chatRoomsStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  void _loadChatRooms() {
    _chatRoomsStream = _chatService.getUserChatRooms();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 🔍 Search Bar - NEW FEATURE
          _buildSearchBar(),
          Expanded(
            child: _chatRoomsStream == null
                ? const Center(child: CircularProgressIndicator())
                : _buildChatList(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textWhite,
      elevation: 0,
      title: const Text(
        'Messages',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Removed search icon from here since we have search bar below
        IconButton(
          icon: const Icon(Icons.more_vert, size: 24),
          onPressed: _showMoreOptions,
        ),
      ],
    );
  }

  // 🔍 NEW: Search Bar Widget
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.accent1,
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: Icon(Icons.search, color: AppColors.primary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: AppColors.primary),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            )
                : null,
            hintStyle: TextStyle(color: AppColors.textLight),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<List<ChatRoom>>(
      stream: _chatRoomsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget('Failed to load conversations');
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final chatRooms = snapshot.data!;

        // 🔍 NEW: Filter chat rooms based on search query
        final filteredChatRooms = _searchQuery.isEmpty
            ? chatRooms
            : chatRooms.where((chatRoom) =>
            chatRoom.name.toLowerCase().contains(_searchQuery)).toList();

        if (filteredChatRooms.isEmpty) {
          return _buildNoResults();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredChatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = filteredChatRooms[index];
            return _ChatRoomListItem(
              chatRoom: chatRoom,
              chatService: _chatService,
              onTap: () => _openChat(chatRoom),
            );
          },
        );
      },
    );
  }

  // 🔍 NEW: No results widget
  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            'No conversations found',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
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
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadChatRooms,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation by tapping the + button',
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

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SelectUserScreen()),
        );
      },
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textWhite,
      elevation: 4,
      child: const Icon(Icons.chat, size: 24),
    );
  }

  void _showMoreOptions() {
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
              _buildMenuOption(Icons.archive, 'Archive chats', () {}),
              _buildMenuOption(Icons.notifications, 'Notification settings', () {}),
              _buildMenuOption(Icons.help, 'Help', () {}),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
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

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _openChat(ChatRoom chatRoom) {
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

class _ChatRoomListItem extends StatelessWidget {
  final ChatRoom chatRoom;
  final ChatService chatService;
  final VoidCallback onTap;

  const _ChatRoomListItem({
    required this.chatRoom,
    required this.chatService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 48),
            child: _buildUserAvatar(context),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  chatRoom.name.isEmpty ? 'Unknown User' : chatRoom.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (chatRoom.lastMessageTime != null)
                Text(
                  _formatTime(chatRoom.lastMessageTime!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              chatRoom.lastMessage ?? 'Start a conversation...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: chatRoom.lastMessage != null
                    ? AppColors.textGray
                    : AppColors.textLight,
                fontSize: 14,
              ),
            ),
          ),
          trailing: _buildUnreadIndicator(),
          onTap: onTap,
        ),
      ),
    );
  }

  // 🆕 UPDATED: Build user avatar with profile image from backend
  Widget _buildUserAvatar(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getUserProfileImage(chatRoom.name),
      builder: (context, snapshot) {
        // إذا في خطأ أو الاسم فارغ، استخدم الحرف الأول مباشرة
        if (chatRoom.name.isEmpty) {
          return _buildFallbackAvatar('User');
        }

        final profileImage = snapshot.data;

        if (profileImage != null && profileImage.isNotEmpty) {
          // استخدم Image.network مع errorBuilder
          return SizedBox(
            width: 48,
            height: 48,
            child: ClipOval(
              child: Image.network(
                profileImage,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // إذا فشل تحميل الصورة، استخدم الحرف الأول
                  return _buildFallbackAvatar(chatRoom.name);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  // أثناء التحميل، اعرض الحرف الأول مؤقتاً
                  return _buildFallbackAvatar(chatRoom.name);
                },
              ),
            ),
          );
        } else {
          // إذا ما في صورة - استخدم الحرف الأول
          return _buildFallbackAvatar(chatRoom.name);
        }
      },
    );
  }

// 🆕 UPDATED: دالة تجلب صورة المستخدم مع debugging
  Future<String?> _getUserProfileImage(String userName) async {
    if (userName.isEmpty) {
      print('❌ User name is empty');
      return null;
    }

    try {
      final availableUsers = await UserService.getAvailableUsers();

      print('🔍 Available users count: ${availableUsers.length}');
      print('🔍 Searching for user: "$userName"');

      // ابحث عن المستخدم بالاسم المطابق
      final user = availableUsers.firstWhere(
            (user) {
          final name = user['name']?.toString() ?? '';
          final match = name == userName;
          print('   Comparing: "$name" == "$userName" → $match');
          return match;
        },
        orElse: () => {},
      );

      if (user.isNotEmpty) {
        final profileImage = user['profileImage'];
        print('🖼️ Found profile image for $userName: "$profileImage"');

        // تحقق إذا الصورة null أو فارغة
        if (profileImage == null || profileImage.toString().isEmpty) {
          print('❌ Profile image is null or empty');
          return null;
        }

        return profileImage.toString();
      } else {
        print('❌ User "$userName" not found in available users');
        // اطبع جميع المستخدمين المتاحين للمساعدة في debugging
        for (var u in availableUsers) {
          print('   Available user: "${u['name']}" → profile: "${u['profileImage']}"');
        }
        return null;
      }

    } catch (e) {
      print('❌ Error getting user profile image: $e');
      return null;
    }
  }

  // 🆕 NEW: دالة لبناء الصورة الافتراضية بالحرف الأول
  Widget _buildFallbackAvatar(String name) {
    return CircleAvatar(
      backgroundColor: _getColorFromName(name),
      radius: 24,
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  // 🆕 UPDATED: دالة تستخرج الأحرف الأولى من الاسم مع معالجة الأخطاء
  String _getInitials(String name) {
    if (name.isEmpty) {
      return '?'; // إذا الاسم فارغ
    }

    final names = name.split(' ');

    if (names.length >= 2) {
      // إذا الاسم كامل - خذ أول حرف من الاسم الأول والثاني
      final first = names[0].isNotEmpty ? names[0][0] : '';
      final second = names[1].isNotEmpty ? names[1][0] : '';
      return '${first}${second}'.toUpperCase();
    } else if (name.isNotEmpty) {
      // إذا اسم واحد فقط - خذ أول حرف
      return name[0].toUpperCase();
    }

    return '?'; // حالة افتراضية
  }

  // ... باقي الدوال بدون تغيير
  Widget _buildUnreadIndicator() {
    // يمكنك إضافة منطق عدد الرسائل غير المقروءة هنا
    const hasUnread = false;
    const unreadCount = 3;

    if (!hasUnread) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        unreadCount.toString(),
        style: const TextStyle(
          color: AppColors.textWhite,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay.year == now.year) {
      return '${time.day}/${time.month}';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  Color _getColorFromName(String name) {
    final colors = [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.accent1,
      AppColors.accent2,
      AppColors.accent3,
    ];
    final index = name.isEmpty ? 0 : name.length % colors.length;
    return colors[index];
  }
}