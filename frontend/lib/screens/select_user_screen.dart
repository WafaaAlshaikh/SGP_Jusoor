// screens/select_user_screen.dart
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
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
        final name = user['name'].toString().toLowerCase();
        final email = user['email'].toString().toLowerCase();
        final role = user['role'].toString().toLowerCase();
        final searchLower = query.toLowerCase();

        return name.contains(searchLower) ||
            email.contains(searchLower) ||
            role.contains(searchLower);
      }).toList();
    });
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
        // Search Bar
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
              decoration: const InputDecoration(
                hintText: 'Search users...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.search, color: AppColors.primary),
                hintStyle: TextStyle(color: AppColors.textLight),
              ),
              onChanged: _filterUsers,
            ),
          ),
        ),

        // User List
        Expanded(
          child: _filteredUsers.isEmpty
              ? _buildNoUsersFound()
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredUsers.length,
            itemBuilder: (context, index) {
              final user = _filteredUsers[index];
              return _UserListItem(
                user: user,
                onTap: () => _startChatWithUser(user),
              );
            },
          ),
        ),
      ],
    );
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: _getRoleColor(user['role']),
            radius: 24,
            child: Text(
              user['name'][0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  user['name'],
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
                user['email'],
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user['role']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleText(user['role']),
                      style: TextStyle(
                        color: _getRoleColor(user['role']),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (user['specialization'] != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      user['specialization'],
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
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