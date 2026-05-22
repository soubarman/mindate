import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/chat_model.dart';
import '../../../core/models/post_model.dart';
import '../../feed/widgets/post_card.dart';
class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  int _activeTab = 0;
  double _sliderValue = 0.0;
  bool _isRequesting = false;

  void _handleFollow(UserModel currentUser, UserModel targetUser, bool isFollowing) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(socialProvider.notifier).toggleFollow(
        currentUserId: currentUser.id,
        targetUserId: targetUser.id,
        isCurrentlyFollowing: isFollowing,
      );
      if (mounted) {
        _showSuccess(isFollowing ? 'Unfollowed ${targetUser.name}' : 'Now following ${targetUser.name}!');
      }
    } catch (e) {
      if (mounted) _showError('Could not update follow. Check Firebase Rules!');
    }
  }

  void _showGiftDialog(UserModel currentUser, UserModel targetUser) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text('Send a Gift to ${targetUser.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You have 🪙 ${currentUser.coins} coins', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGiftOption(context, '🌹', 'Rose', 10, currentUser, targetUser),
                _buildGiftOption(context, '💍', 'Ring', 50, currentUser, targetUser),
                _buildGiftOption(context, '👑', 'Crown', 100, currentUser, targetUser),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftOption(BuildContext context, String emoji, String name, int cost, UserModel currentUser, UserModel targetUser) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _sendGift(currentUser, targetUser, name, cost);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('🪙 $cost', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  void _sendGift(UserModel currentUser, UserModel targetUser, String giftName, int cost) async {
    if (currentUser.coins < cost) {
      _showError('Not enough coins for $giftName!');
      return;
    }

    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      );
      
      final batch = db.batch();
      batch.update(db.collection('users').doc(currentUser.id), {
        'coins': FieldValue.increment(-cost),
      });
      batch.update(db.collection('users').doc(targetUser.id), {
        'coins': FieldValue.increment(cost),
      });

      await batch.commit();

      // Send Notification!
      await sendNotification(
        userId: targetUser.id,
        senderId: currentUser.id,
        senderName: currentUser.name,
        senderAvatar: currentUser.avatarUrl,
        type: 'gift',
        title: 'New Gift received! 🎁',
        body: '${currentUser.name} sent you a $giftName!',
      );

      if (mounted) {
        _showSuccess('Sent $giftName to ${targetUser.name}! 🎁');
      }
    } catch (e) {
      if (mounted) _showError('Gift failed. Check Firebase Rules!');
    }
  }

  void _handleChatRequest(UserModel currentUser, UserModel targetUser) async {
    if (_isRequesting) return;

    if (currentUser.coins < 10) {
      _showError('Not enough coins! 🪙 Need 10 coins to chat.');
      setState(() => _sliderValue = 0);
      return;
    }

    setState(() => _isRequesting = true);

    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      );
      final chatId = 'chat_${currentUser.id}_${targetUser.id}';

      await db.collection('chats').doc(chatId).set({
        'id': chatId,
        'participants': [currentUser.id, targetUser.id],
        'otherUserId': targetUser.id,
        'otherUserName': targetUser.name,
        'otherUserAvatar': targetUser.avatarUrl,
        'otherUserIsOnline': false,
        'lastMessage': 'Chat request sent! 💫',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
        'isExpired': false,
        'status': 'requested',
        'requestSenderId': currentUser.id,
        'senderId': currentUser.id,
        'senderName': currentUser.name,
        'senderAvatar': currentUser.avatarUrl,
        'receiverId': targetUser.id,
        'receiverName': targetUser.name,
        'receiverAvatar': targetUser.avatarUrl,
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timed out. Check your internet.'),
      );

      // Deduct coins
      await db.collection('users').doc(currentUser.id).update({
        'coins': FieldValue.increment(-10),
      }).timeout(const Duration(seconds: 5), onTimeout: () {});

      // Send Notification!
      await sendNotification(
        userId: targetUser.id,
        senderId: currentUser.id,
        senderName: currentUser.name,
        senderAvatar: currentUser.avatarUrl,
        type: 'chat_request',
        title: 'New Chat Request! 💖',
        body: '${currentUser.name} wants to chat with you!',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat request sent! 💫'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go('/chats');
      }
    } catch (e) {
      if (mounted) _showError('Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
          _sliderValue = 0;
        });
      }
    }
  }

  void _cancelChatRequest(UserModel currentUser, ChatModel chat) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Do you want to cancel this chat request? Your 10 coins will be refunded immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      );

      final batch = db.batch();
      batch.delete(db.collection('chats').doc(chat.id));
      batch.update(db.collection('users').doc(currentUser.id), {
        'coins': FieldValue.increment(10),
      });

      await batch.commit();
      _showSuccess('Request cancelled & 10 coins refunded! 🪙');
    } catch (e) {
      _showError('Failed to cancel request: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(otherUserProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final chats = ref.watch(chatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('User not found 😢')));
        }

        final isFollowing = currentUser.following.contains(user.id);
        // Check if a chat already exists between these two users
        final existingChat = chats.where((c) =>
          c.participants.contains(currentUser.id) &&
          c.participants.contains(user.id)
        ).firstOrNull;

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF8FAFC),
          body: SafeArea(
            top: true,
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildMainProfileImage(user, currentUser, isDark, context),
                const SizedBox(height: 12),
                _buildReactionButtons(isDark, currentUser, user, isFollowing),
                const SizedBox(height: 32),
                _buildSlideToChat(currentUser, user, existingChat: existingChat),
                const SizedBox(height: 32),
                _buildActionButtons(currentUser, user, isFollowing, isDark),
                const SizedBox(height: 32),
                _buildTabbedSections(user, isDark),
                const SizedBox(height: 24),
                _buildBottomActions(isDark),
                const SizedBox(height: 120),
              ],
            ),
          ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildCoinBadge(int coins, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainProfileImage(UserModel user, UserModel currentUser, bool isDark, BuildContext context) {
    return Container(
      width: double.infinity,
      height: 440,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Image.network(
              user.avatarUrl ?? 'https://i.pravatar.cc/600',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.9),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          // Top Actions (Back Button & Coins)
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    '${currentUser.coins}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.amber),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Positioned(
            bottom: 32,
            left: 28,
            right: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.name}, ${user.age}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildOverlayTag('🎨 Feeling creative', AppTheme.accentPink),
                    _buildOverlayTag('Creative', Colors.white.withOpacity(0.2)),
                    _buildOverlayTag('Introvert', Colors.white.withOpacity(0.2)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildOverlayTag('📍 5 miles away', Colors.white.withOpacity(0.2), isLocation: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayTag(String text, Color color, {bool isLocation = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLocation ? 16 : 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: isLocation ? Border.all(color: Colors.white.withOpacity(0.3)) : null,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildReactionButtons(bool isDark, UserModel currentUser, UserModel targetUser, bool isFollowing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildReactionItem('🥶', 'Cold!', const Color(0xFFE0F2FE), isDark, () => _handleReaction('🥶', currentUser, targetUser, isFollowing)),
        const SizedBox(width: 20),
        _buildReactionItem('🤌', 'Chief Kiss', const Color(0xFFFEF3C7), isDark, () => _handleReaction('🤌', currentUser, targetUser, isFollowing), isLarge: true),
        const SizedBox(width: 20),
        _buildReactionItem('😘', 'Love!', const Color(0xFFFEE2E2), isDark, () => _handleReaction('😘', currentUser, targetUser, isFollowing)),
      ],
    );
  }

  Widget _buildReactionItem(String emoji, String label, Color bg, bool isDark, VoidCallback onTap, {bool isLarge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          _buildCircleEmoji(emoji, bg, isDark, isLarge: isLarge),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  void _handleReaction(String emoji, UserModel currentUser, UserModel targetUser, bool isFollowing) async {
    // Only auto-follow if we are NOT already following!
    if (!isFollowing) {
      _handleFollow(currentUser, targetUser, false);
    }

    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      );
      final chatId = 'chat_${currentUser.id}_${targetUser.id}';

      // 1. Check if chat request already exists
      final chatDoc = await db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        // Create the chat request!
        await db.collection('chats').doc(chatId).set({
          'id': chatId,
          'participants': [currentUser.id, targetUser.id],
          'otherUserId': targetUser.id,
          'otherUserName': targetUser.name,
          'otherUserAvatar': targetUser.avatarUrl,
          'otherUserIsOnline': false,
          'lastMessage': 'Sent a reaction: $emoji ✨',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': 0,
          'isExpired': false,
          'status': 'requested',
          'requestSenderId': currentUser.id,
          'senderId': currentUser.id,
          'senderName': currentUser.name,
          'senderAvatar': currentUser.avatarUrl,
          'receiverId': targetUser.id,
          'receiverName': targetUser.name,
          'receiverAvatar': targetUser.avatarUrl,
        });
      } else {
        // Just update last message
        await db.collection('chats').doc(chatId).update({
          'lastMessage': 'Sent a reaction: $emoji ✨',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      // 2. Add message to chat subcollection
      final messageId = db.collection('chats').doc(chatId).collection('messages').doc().id;
      await db.collection('chats').doc(chatId).collection('messages').doc(messageId).set({
        'id': messageId,
        'senderId': currentUser.id,
        'text': 'Sent a reaction: $emoji ✨',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
        'type': 'text',
      });

      // 3. Send Notification!
      await sendNotification(
        userId: targetUser.id,
        senderId: currentUser.id,
        senderName: currentUser.name,
        senderAvatar: currentUser.avatarUrl,
        type: 'reaction',
        title: 'New Reaction! 💖',
        body: '${currentUser.name} sent you a $emoji reaction!',
      );

      _showSuccess('Sent $emoji reaction to ${targetUser.name}! ✨');
    } catch (e) {
      _showError('Reaction error: $e');
    }
  }

  Widget _buildCircleEmoji(String emoji, Color bg, bool isDark, {bool isLarge = false}) {
    final size = isLarge ? 54.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? bg.withOpacity(0.1) : bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: isLarge ? 24 : 18),
        ),
      ),
    );
  }

  Widget _buildSlideToChat(UserModel currentUser, UserModel targetUser, {ChatModel? existingChat}) {
    if (existingChat != null) {
      if (existingChat.status == 'accepted') {
        return _buildStatusBanner('Chat Request Accepted! 💬', AppTheme.primaryBlue, () {
          context.push('/chat/${existingChat.id}', extra: {
            'userId': targetUser.id,
            'name': targetUser.name,
            'avatar': targetUser.avatarUrl,
            'isOnline': targetUser.isOnline,
          });
        });
      } else if (existingChat.status == 'requested') {
        if (existingChat.requestSenderId == currentUser.id) {
          return _buildStatusBanner('Request Pending ⏳ (Tap to Cancel)', Colors.orange, () => _cancelChatRequest(currentUser, existingChat));
        } else {
          return _buildStatusBanner('They requested to chat! 💖', Colors.pinkAccent, () {
            context.go('/chats'); // Go to chats page to accept
          });
        }
      }
    }

    return Container(
      width: 310,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Slide to Request Chat',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                SizedBox(width: 8),
                Text('🪙 10', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.amber, fontSize: 14)),
              ],
            ),
          ),
          Positioned.fill(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 52,
                thumbShape: _CustomThumbShape(),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
              ),
              child: Slider(
                value: _sliderValue,
                onChanged: _isRequesting ? null : (v) {
                  setState(() => _sliderValue = v);
                  if (v > 0.9) {
                    _handleChatRequest(currentUser, targetUser);
                  }
                },
                onChangeEnd: (v) {
                  if (v < 0.9) {
                    setState(() => _sliderValue = 0);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String text, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 310,
        height: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(UserModel currentUser, UserModel targetUser, bool isFollowing, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildMainActionButton(
              label: isFollowing ? 'Following' : 'Follow',
              icon: isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
              onTap: () => _handleFollow(currentUser, targetUser, isFollowing),
              isActive: isFollowing,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: _buildMainActionButton(
              label: 'Gift',
              icon: Icons.card_giftcard_rounded,
              onTap: () => _showGiftDialog(currentUser, targetUser),
              isAccent: true,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    bool isAccent = false,
    required bool isDark,
  }) {
    final color = isAccent 
        ? const Color(0xFFFFB300) 
        : (isActive ? AppTheme.primaryBlue : (isDark ? Colors.white : Colors.black));
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isActive 
              ? AppTheme.primaryBlue.withOpacity(0.1) 
              : (isAccent ? const Color(0xFFFFB300).withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppTheme.primaryBlue : (isAccent ? const Color(0xFFFFB300) : Colors.transparent),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required String subLabel,
    required VoidCallback onTap,
    bool isAccent = false,
    bool isActive = false,
    required bool isDark,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryBlue : (isDark ? AppTheme.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isAccent ? const Color(0xFFFFB300) : (isActive ? Colors.transparent : const Color(0xFFE2E8F0)),
                width: 2,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon, 
                  size: 20, 
                  color: isActive ? Colors.white : (isAccent ? const Color(0xFFFFB300) : (isDark ? Colors.white70 : Colors.black)),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 15,
                    color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subLabel,
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildAboutCard(UserModel user, bool isDark) {
    return Container(
      key: const ValueKey(0),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [AppTheme.darkCard, AppTheme.darkBg]
            : [const Color(0xFFFDF2F8), const Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFFCE7F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'About ${user.name}',
                style: const TextStyle(
                  color: AppTheme.accentPink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              const Text('✨', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.bio ?? 'Artist who finds beauty in the chaos of the city. My paintbrush is my best friend. Looking for someone to explore galleries with.',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabbedSections(UserModel user, bool isDark) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildTabHeader(0, 'About me', isDark),
              _buildTabHeader(1, 'Compatibility', isDark),
              _buildTabHeader(2, 'Posts', isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _activeTab == 0
              ? _buildAboutCard(user, isDark)
              : _activeTab == 1
                  ? _buildCompatibilityCard(user, isDark)
                  : _buildPostsList(user, isDark),
        ),
      ],
    );
  }

  Widget _buildTabHeader(int index, String title, bool isDark) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? (isDark ? AppTheme.primaryBlue.withOpacity(0.2) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppTheme.primaryBlue : (isDark ? Colors.white54 : AppTheme.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompatibilityCard(UserModel user, bool isDark) {
    return Container(
      key: const ValueKey(1),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Match Score',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '92% Match',
                  style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Top Traits', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTraitChip('♓ Pisces', AppTheme.primaryBlue),
              _buildTraitChip('🐶 Dog Lover', Colors.orange),
              _buildTraitChip('✈️ Traveler', Colors.green),
              _buildTraitChip('🍷 Wine', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTraitChip(String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: isDark ? color.withOpacity(0.9) : color, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _buildPostsList(UserModel user, bool isDark) {
    final streamPosts = ref.watch(postsStreamProvider).asData?.value ?? [];
    final localPosts = ref.watch(postsProvider);
    
    final List<PostModel> posts = [];
    final Set<String> seenIds = {};
    for (var p in [...localPosts, ...streamPosts]) {
      if (!seenIds.contains(p.id) && p.userId == user.id) {
        posts.add(p);
        seenIds.add(p.id);
      }
    }
    // Sort posts: float pinned posts to the top, and sort by date descending secondary
    posts.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (posts.isEmpty) {
      return Container(
        key: const ValueKey(2),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const Center(
          child: Text('No posts yet 📸', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
        ),
      );
    }

    return Container(
      key: const ValueKey(2),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          // Assuming we have access to PostCard here. Since we are in UserDetailScreen, we might need to import it.
          return PostCard(
            post: post,
            onLike: () => ref.read(postsProvider.notifier).toggleLike(post.id, ref.read(currentUserProvider).id),
          );
        },
      ),
    );
  }

  Widget _buildBottomActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTextAction(Icons.share_rounded, 'Share Profile', isDark),
          const SizedBox(width: 24),
          Container(width: 1, height: 18, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(width: 24),
          _buildTextAction(Icons.flag_rounded, 'Report', isDark),
        ],
      ),
    );
  }

  Widget _buildTextAction(IconData icon, String label, bool isDark) {
    return GestureDetector(
      onTap: () => _showSuccess('$label coming soon! ✨'),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black45),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black45, 
              fontSize: 14, 
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomThumbShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(44, 44);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw white circle thumb (radius 22)
    canvas.drawCircle(center, 22, paint);

    // Draw icon inside
    const icon = Icons.send_rounded;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 20,
          fontFamily: icon.fontFamily,
          color: AppTheme.accentPink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }
}
