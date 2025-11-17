// screens/select_user_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';

import '../services/user_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import '../models/chat_models.dart';
import '../theme/app_colors.dart';

class SelectUserScreen extends StatefulWidget {
  const SelectUserScreen({super.key});

  @override
  State<SelectUserScreen> createState() => _SelectUserScreenState();
}

class _SelectUserScreenState extends State<SelectUserScreen> {
  final ChatService _chatService = ChatService();
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await UserService.isLoggedInToBackend();
      if (!isLoggedIn) {
        setState(() {
          _error = 'Please login first';
          _isLoading = false;
        });
        return;
      }
      await _loadUsers();
    } catch (e) {
      setState(() {
        _error = 'Error checking login status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await UserService.getAvailableUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final role = (user['role'] ?? '').toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || email.contains(searchLower) || role.contains(searchLower);
      }).toList();
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _filterUsers(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorWidget()
              : _buildUserList(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textWhite,
      title: const Text(
        'New Conversation',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 24),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _error,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return Column(
      children: [
        Container(
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
                hintText: 'Search users...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.primary),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers('');
                          setState(() {});
                        },
                      )
                    : null,
                hintStyle: const TextStyle(color: AppColors.textLight),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
        Expanded(
          child: _filteredUsers.isEmpty
              ? _buildNoUsersFound()
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: _buildGroupedList(),
                ),
        ),
      ],
    );
  }

  Widget _buildGroupedList() {
    final sections = _groupUsersByRole(_filteredUsers);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final role = section['role'] as String;
        final items = section['items'] as List<Map<String, dynamic>>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                role,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
              ),
            ),
            ...items.map((user) => _UserListItem(user: user, onTap: () => _startChatWithUser(user))).toList(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _groupUsersByRole(List<Map<String, dynamic>> users) {
    final order = ['Parent', 'Specialist', 'Manager', 'Admin', 'User'];
    final map = <String, List<Map<String, dynamic>>>{};
    for (final u in users) {
      final role = (u['role'] ?? 'User').toString();
      map.putIfAbsent(role, () => []).add(u);
    }
    final roles = map.keys.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
      });
    return roles.map((r) => {'role': r, 'items': map[r]!}).toList();
  }

  Widget _buildNoUsersFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            'No users found',
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

  void _startChatWithUser(Map<String, dynamic> user) async {
    try {
      final chatRoomId = await _chatService.createDirectChat(
        otherUserId: user['id'].toString(),
        otherUserName: user['name'],
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatRoom: ChatRoom(
              id: chatRoomId,
              name: user['name'],
              type: 'direct',
              participantIds: [],
              adminIds: [],
              createdAt: DateTime.now(),
            ),
            chatService: _chatService,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start chat: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _UserListItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserListItem({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMockData = user['isMock'] == true;
    final String name = (user['name'] ?? '').toString();
    final String? imageUrl = user['profileImage']?.toString();
    final String email = (user['email'] ?? '').toString();
    final String role = (user['role'] ?? 'User').toString();
    final String? specialization = user['specialization']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _buildAvatar(name, imageUrl),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (isMockData)
                const Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: AppColors.warning,
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              if (specialization != null && specialization.isNotEmpty)
                Text(
                  specialization,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return SizedBox(
        width: 48,
        height: 48,
        child: ClipOval(
          child: Image.network(
            imageUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) {
              return CircleAvatar(
                backgroundColor: _getRoleColor((user['role'] ?? 'User').toString()),
                radius: 24,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: _getRoleColor((user['role'] ?? 'User').toString()),
      radius: 24,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Parent':
        return AppColors.success;
      case 'Specialist':
        return AppColors.primary;
      case 'Manager':
        return AppColors.warning;
      case 'Admin':
        return AppColors.info;
      default:
        return AppColors.textGray;
    }
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'Parent':
        return 'Parent';
      case 'Specialist':
        return 'Specialist';
      case 'Manager':
        return 'Manager';
      case 'Admin':
        return 'Admin';
      default:
        return 'User';
    }
  }
}