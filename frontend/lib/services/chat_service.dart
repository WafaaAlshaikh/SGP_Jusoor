// services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // 🆕 ADD THIS
import '../models/chat_models.dart';
import 'notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// 🆕 ADD THESE IMPORTS
import 'package:firebase_messaging/firebase_messaging.dart';
import 'complete_notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // 1. Create new chat room
  Future<String> createChatRoom({
    required String name,
    required String type,
    required List<String> participantIds,
    List<String>? adminIds,
  }) async {
    try {
      final chatRoomRef = _firestore.collection('chatRooms').doc();

      final chatRoom = ChatRoom(
        id: chatRoomRef.id,
        name: name,
        type: type,
        participantIds: participantIds,
        adminIds: adminIds ?? participantIds,
        createdAt: DateTime.now(),
      ).toMap();

      await chatRoomRef.set(chatRoom);
      print('✅ Chat room created: $name');
      return chatRoomRef.id;
    } catch (e) {
      print('❌ Error creating chat room: $e');
      throw e;
    }
  }

  // 2. Send message - UPDATED WITH NOTIFICATIONS
  Future<void> sendMessage({
    required String chatRoomId,
    required String content,
    String type = 'text',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get username from local storage
      final userName = await _getUserNameFromLocalStorage();

      final prefs = await SharedPreferences.getInstance();
      final localId = prefs.getString('user_id');
      final myTag = localId != null ? 'user_$localId' : user.uid;

      final messageRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc();

      final message = ChatMessage(
        id: messageRef.id,
        chatRoomId: chatRoomId,
        senderId: myTag,
        senderName: userName ?? user.displayName ?? user.email!.split('@')[0],
        content: content,
        type: type,
        timestamp: DateTime.now(),
        isRead: false,
        readBy: [myTag],
      ).toMap();

      await messageRef.set(message);

      // Update last message in chat room
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': content,
        'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
        'lastSenderId': myTag,
      });

      // NEW: Send smart notifications
      await _sendSmartNotifications(
        chatRoomId: chatRoomId,
        messageContent: content,
        senderName: userName ?? 'مستخدم',
      );

      print(' Message sent: $content');

    } catch (e) {
      print(' Error sending message: $e');
      throw e;
    }
  }

  // 3. Get user's chat rooms
  Stream<List<ChatRoom>> getUserChatRooms() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return Stream.fromFuture(SharedPreferences.getInstance()).asyncExpand((prefs) async* {
      final localId = prefs.getString('user_id');
      if (localId == null) {
        yield [];
        return;
      }

      final myTag = 'user_$localId';
      print(' getUserChatRooms myTag = $myTag');

      yield* _firestore
          .collection('chatRooms')
          .where('participantIds', arrayContains: myTag)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .map((snapshot) {
        try {
          print(' getUserChatRooms returned ${snapshot.docs.length} rooms');
          for (final d in snapshot.docs) {
            final data = d.data();
            print('  • room ${d.id} participants=${data['participantIds']} name=${data['name']}');
          }
        } catch (_) {}
        return snapshot.docs.map((doc) {
          return ChatRoom.fromMap(doc.data() as Map<String, dynamic>);
        }).toList();
      });
    });
  }

  // 4. Get messages for specific chat room
  Stream<List<ChatMessage>> getChatMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessage.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }


  // في ChatService - أضف هذه الدوال الجديدة
  Future<void> markMessageAsSeen(String messageId, String chatRoomId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // use local tag for read receipts
      final prefs = await SharedPreferences.getInstance();
      final localId = prefs.getString('user_id');
      final myTag = localId != null ? 'user_$localId' : user.uid;

      final messageRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId);

      await messageRef.update({
        'readBy': FieldValue.arrayUnion([myTag]),
        'isRead': true,
      });

      print(' Message marked as seen: $messageId');
    } catch (e) {
      print(' Error marking message as seen: $e');
    }
  }

  Future<void> markAllMessagesAsSeen(String chatRoomId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final localId = prefs.getString('user_id');
      final myTag = localId != null ? 'user_$localId' : user.uid;

      // جلب جميع الرسائل غير المقروءة
      final messagesSnapshot = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: myTag)
          .get();

      final batch = _firestore.batch();

      for (var doc in messagesSnapshot.docs) {
        final messageRef = _firestore
            .collection('chatRooms')
            .doc(chatRoomId)
            .collection('messages')
            .doc(doc.id);

        final data = doc.data();
        final readBy = List<String>.from((data['readBy'] ?? []) as List);
        if (!readBy.contains(myTag)) {
          batch.update(messageRef, {
            'readBy': FieldValue.arrayUnion([myTag]),
            'isRead': true,
          });
        }
      }

      await batch.commit();
      print(' All messages marked as seen in chat: $chatRoomId');
    } catch (e) {
      print(' Error marking all messages as seen: $e');
    }
  }

// NEW: دالة لتحديث حالة seen عند فتح الشات
  Stream<void> onChatOpened(String chatRoomId) {
    return Stream.value(null).asyncMap((_) => markAllMessagesAsSeen(chatRoomId));
  }

  // 5. Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, List<String> messageIds) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString('user_id');
    final myTag = localId != null ? 'user_$localId' : user.uid;

    final batch = _firestore.batch();

    for (String messageId in messageIds) {
      final messageRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId);

      batch.update(messageRef, {
        'readBy': FieldValue.arrayUnion([myTag]),
      });
    }

    await batch.commit();
    print(' Messages marked as read');
  }

  // 6. Enhanced function to create direct chat
  Future<String> createDirectChat({
    required String otherUserId, // ID from local database
    required String otherUserName,
  }) async {
    try {
      // Auto-sync with Firebase if not logged in
      var user = _auth.currentUser;
      if (user == null) {
        print(' User not logged in to Firebase, attempting auto-sync...');
        await _autoSyncFirebaseAuth();
        user = _auth.currentUser;
        if (user == null) throw Exception('User not logged in');
      }

      // Resolve local sender tag (user_<localId>)
      final prefs = await SharedPreferences.getInstance();
      final localId = prefs.getString('user_id');
      final myTag = localId != null ? 'user_$localId' : user.uid;

      // Get Firebase UID for the other user
      final otherUserFirebaseId = await _getFirebaseUserId(otherUserId);

      // participantIds تعتمد فقط على user_<localId> لكلا الطرفين لتجنب تسريب الغرف عبر UID مشترك
      final participants = [
        myTag,
        otherUserFirebaseId,
      ];

      // Check if chat already exists (match any of my identifiers)
      final myVariants = <String>[if (myTag != null) myTag];
      final existingChats = await _firestore
          .collection('chatRooms')
          .where('type', isEqualTo: 'direct')
          .where('participantIds', arrayContainsAny: myVariants)
          .get();

      for (var doc in existingChats.docs) {
        final chat = ChatRoom.fromMap(doc.data() as Map<String, dynamic>);
        if (chat.participantIds.length == 2 &&
            chat.participantIds.contains(otherUserFirebaseId)) {
          print('✅ Found existing chat: ${doc.id}');
          return doc.id;
        }
      }

      // Create new chat
      final chatName = '$otherUserName';
      return await createChatRoom(
        name: chatName,
        type: 'direct',
        participantIds: participants,
      );

    } catch (e) {
      print('❌ Error creating direct chat: $e');
      throw e;
    }
  }

  // 🔄 Helper function to get Firebase UID for other user
  Future<String> _getFirebaseUserId(String localUserId) async {
    try {
      // In a real system, we can store mapping between local ID and Firebase UID
      // Currently using a simple method to generate a consistent ID
      return 'user_$localUserId';
    } catch (e) {
      print('❌ Error getting Firebase UID: $e');
      throw e;
    }
  }

  // Helper function to get username from local storage
  Future<String?> _getUserNameFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_name') ?? prefs.getString('name');
    } catch (e) {
      print('❌ Error getting username: $e');
      return null;
    }
  }

  // 7. Delete message
  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .delete();
      print('✅ Message deleted');
    } catch (e) {
      print('❌ Error deleting message: $e');
      throw e;
    }
  }

  // 8. Get chat room by ID
  Future<ChatRoom?> getChatRoomById(String chatRoomId) async {
    try {
      final doc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (doc.exists) {
        return ChatRoom.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ Error getting chat room: $e');
      throw e;
    }
  }

  // 9. Update chat room details
  Future<void> updateChatRoom({
    required String chatRoomId,
    String? name,
    String? description,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;

      await _firestore.collection('chatRooms').doc(chatRoomId).update(updateData);
      print('✅ Chat room updated');
    } catch (e) {
      print('❌ Error updating chat room: $e');
      throw e;
    }
  }

  // 10. Leave chat room
  Future<void> leaveChatRoom(String chatRoomId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'participantIds': FieldValue.arrayRemove([user.uid]),
        'adminIds': FieldValue.arrayRemove([user.uid]),
      });
      print('✅ Left chat room');
    } catch (e) {
      print('❌ Error leaving chat room: $e');
      throw e;
    }
  }

  // 11. Get unread message count for a chat room
  Stream<int> getUnreadMessageCount(String chatRoomId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return Stream.fromFuture(SharedPreferences.getInstance()).asyncExpand((prefs) {
      final localId = prefs.getString('user_id');
      final myTag = localId != null ? 'user_$localId' : user.uid;

      return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final message = ChatMessage.fromMap(doc.data() as Map<String, dynamic>);
        return message.senderId != myTag && !message.readBy.contains(myTag);
      }).length;
    });
    });
  }

  // 🆕 NEW: نظام الإشعارات الذكي
  Future<void> _sendSmartNotifications({
    required String chatRoomId,
    required String messageContent,
    required String senderName,
  }) async {
    try {
      final chatRoom = await getChatRoomById(chatRoomId);
      if (chatRoom == null) return;

      final prefs = await SharedPreferences.getInstance();
      final localId = prefs.getString('user_id');
      final myTag = localId != null ? 'user_$localId' : _auth.currentUser?.uid;
      if (myTag == null) return;

      // الحصول على المشاركين الآخرين (استبعاد معرفي المحلي)
      final otherParticipants = chatRoom.participantIds.where((id) => id != myTag).toList();
      if (otherParticipants.isEmpty) return;

      print('🔔 إرسال إشعارات إلى ${otherParticipants.length} مستخدم');

      for (final participantId in otherParticipants) {
        await _sendCompleteNotification(
          targetUserId: participantId,
          senderName: senderName,
          message: messageContent,
          chatRoomId: chatRoomId,
        );
      }

    } catch (e) {
      print('❌ خطأ في الإشعارات الذكية: $e');
    }
  }

  // 🆕 NEW: إرسال إشعار كامل
  Future<void> _sendCompleteNotification({
    required String targetUserId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    try {
      // 1. إشعار النظام الفوري
      await _sendSystemNotification(
        targetUserId: targetUserId,
        senderName: senderName,
        message: message,
        chatRoomId: chatRoomId,
      );

      // 2. تخزين للإشعارات الداخلية
      await _storeNotificationForInApp(
        targetUserId: targetUserId,
        senderName: senderName,
        message: message,
        chatRoomId: chatRoomId,
      );

      print('📲 تم إرسال إشعار كامل للمستخدم: $targetUserId');

    } catch (e) {
      print('❌ خطأ في الإشعار الكامل: $e');
    }
  }

  // 🆕 NEW: إرسال إشعار نظام
  Future<void> _sendSystemNotification({
    required String targetUserId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    try {
      final notificationService = CompleteNotificationService();

      // إنشاء بيانات الإشعار
      final currentSenderId = _auth.currentUser?.uid;
      final notificationData = {
        'type': 'chat',
        'chatRoomId': chatRoomId,
        'senderId': currentSenderId,
        'senderName': senderName,
        'message': message,
        'channel': 'chat_channel',
        'title': 'رسالة جديدة من $senderName',
        'body': message.length > 50 ? '${message.substring(0, 50)}...' : message,
      };

      // استخدام نظام الإشعارات المحلي
      await showChatNotification(
        senderName: senderName,
        message: message,
        chatRoomId: chatRoomId,
      );

      print('🔔 إشعار نظام مرسل للمستخدم: $targetUserId');

    } catch (e) {
      print('❌ خطأ في إشعار النظام: $e');
      // Fallback to simple notification
      await showSimpleNotification(
        title: 'رسالة جديدة من $senderName',
        body: message,
        id: chatRoomId.hashCode,
      );
    }
  }

  // 🆕 NEW: تخزين إشعار للتطبيق
  Future<void> _storeNotificationForInApp({
    required String targetUserId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // جلب الإشعارات الحالية
      final String? notificationsJson = prefs.getString('in_app_notifications');
      List<Map<String, dynamic>> notifications = [];

      if (notificationsJson != null) {
        notifications = List<Map<String, dynamic>>.from(json.decode(notificationsJson));
      }

      // إضافة الإشعار الجديد
      notifications.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'targetUserId': targetUserId,
        'senderName': senderName,
        'message': message,
        'chatRoomId': chatRoomId,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
        'type': 'chat',
      });

      // الحفاظ على الحد الأقصى (50 إشعار)
      if (notifications.length > 50) {
        notifications = notifications.sublist(notifications.length - 50);
      }

      await prefs.setString('in_app_notifications', json.encode(notifications));

      print('💾 تم تخزين إشعار للتطبيق');

    } catch (e) {
      print('❌ خطأ في تخزين إشعار التطبيق: $e');
    }
  }

  // 🔔 NEW: Get participant name for notifications
  Future<String> _getParticipantName(String participantId) async {
    try {
      // This should get the participant's name from your local database
      // For now, we'll return a generic name
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_name') ?? 'User';
    } catch (e) {
      return 'User';
    }
  }

  // 12. Search messages in chat room
  Stream<List<ChatMessage>> searchMessages(String chatRoomId, String query) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data() as Map<String, dynamic>))
          .where((message) => message.content.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  // 🔥 Auto-sync Firebase Authentication
  Future<void> _autoSyncFirebaseAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');
      final userToken = prefs.getString('token');
      final userId = prefs.getString('user_id');
      final userName = prefs.getString('user_name');

      if (userEmail == null || userId == null || userToken == null) {
        print('❌ No local user data for Firebase sync');
        return;
      }

      print('🔄 Auto-syncing Firebase for user: $userName ($userEmail)');

      final firebaseEmail = userEmail;
      // ✅ استخدام password ثابت متطابق مع auth_sync_service
      final firebasePassword = 'jusoor_user_${userId}_fixed_password';

      try {
        await _auth.signInWithEmailAndPassword(
          email: firebaseEmail,
          password: firebasePassword,
        );
        print('✅ Firebase auto-sync successful');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          print('🔄 Creating Firebase account during chat sync...');
          
          try {
            final userCredential = await _auth.createUserWithEmailAndPassword(
              email: firebaseEmail,
              password: firebasePassword,
            );

            if (userName != null) {
              await userCredential.user!.updateDisplayName(userName);
            }

            await prefs.setString('firebase_uid', userCredential.user!.uid);
            await prefs.setString('firebase_email', firebaseEmail);

            print('✅ Firebase user created during auto-sync: $userName');
          } catch (createError) {
            print('❌ Failed to create Firebase user: $createError');
          }
        } else {
          print('❌ Firebase auth error: ${e.message}');
        }
      }
    } catch (e) {
      print('❌ Auto-sync Firebase failed: $e');
    }
  }
}