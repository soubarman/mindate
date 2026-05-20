import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/app_state_provider.dart';
import 'package:intl/intl.dart';

class CommentsSheet extends ConsumerStatefulWidget {
  final String postId;
  final String postUserName;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.postUserName,
  });

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(currentUserProvider);
    final comment = CommentModel(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      postId: widget.postId,
      userId: currentUser.id,
      userName: currentUser.name,
      userAvatar: currentUser.avatarUrl,
      text: text,
      createdAt: DateTime.now(),
    );

    ref.read(commentsProvider(widget.postId).notifier).addComment(comment);
    ref.read(postsProvider.notifier).incrementCommentCount(widget.postId);
    _commentController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comments = ref.watch(commentsProvider(widget.postId));
    final currentUser = ref.watch(currentUserProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${comments.length}',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text('No comments yet. Be the first!',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      return _CommentTile(
                        comment: comments[index],
                        currentUserId: currentUser.id,
                        onLike: () => ref
                            .read(commentsProvider(widget.postId).notifier)
                            .toggleLike(comments[index].id, currentUser.id),
                        onDelete: comments[index].userId == currentUser.id
                            ? () {
                                ref.read(commentsProvider(widget.postId).notifier).deleteComment(comments[index].id);
                                ref.read(postsProvider.notifier).decrementCommentCount(widget.postId);
                              }
                            : null,
                      );
                    },
                  ),
          ),
          // Input
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(
                      currentUser.avatarUrl ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(currentUser.name)}&size=100&background=6ECBF5&color=fff&rounded=true',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _submitComment,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  final CommentModel comment;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onLike,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = comment.likes.contains(currentUserId);
    final timeStr = DateFormat('MMM d · h:mm a').format(comment.createdAt);
    // Live-watch commenter's profile for up-to-date name/avatar.
    final liveAuthor = ref.watch(otherUserProvider(comment.userId));
    final displayName = liveAuthor.asData?.value?.name ?? comment.userName;
    final displayAvatar = liveAuthor.asData?.value?.avatarUrl
        ?? comment.userAvatar
        ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(comment.userName)}&size=100&background=6ECBF5&color=fff&rounded=true';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(displayAvatar),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(timeStr, style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    if (onDelete != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Comment?'),
                              content: const Text('Are you sure you want to delete this comment?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onDelete!();
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(comment.text, style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLike,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
              child: Column(
                children: [
                  Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 16,
                    color: isLiked ? AppTheme.error : AppTheme.textTertiary,
                  ),
                  if (comment.likes.isNotEmpty)
                    Text(
                      '${comment.likes.length}',
                      style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
