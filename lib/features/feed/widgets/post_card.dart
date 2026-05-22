import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/post_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/firestore_provider.dart';
import '../../../core/models/comment_model.dart';
import '../screens/comments_screen.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback onLike;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  bool _showHeart = false;
  bool _isExpanded = false;
  bool _isBookmarked = false;
  final GlobalKey<PopupMenuButtonState<String>> _reactKey = GlobalKey();
  OverlayEntry? _reactionOverlayEntry;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _heartController = AnimationController(
      vsync: this,
      duration: AppDurations.heartAnimation,
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _hideReactionPopup();
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarked_posts') ?? [];
    if (mounted) {
      setState(() {
        _isBookmarked = bookmarks.contains(widget.post.id);
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarked_posts') ?? [];

    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    if (_isBookmarked) {
      bookmarks.add(widget.post.id);
      await prefs.setStringList('bookmarked_posts', bookmarks);
      HapticFeedback.lightImpact();
    } else {
      bookmarks.remove(widget.post.id);
      await prefs.setStringList('bookmarked_posts', bookmarks);
      HapticFeedback.lightImpact();
    }
  }

  void _doubleTapLike() {
    HapticFeedback.mediumImpact();
    setState(() => _showHeart = true);
    _heartController.forward(from: 0);
    Future.delayed(AppDurations.heartAnimation, () {
      if (mounted) setState(() => _showHeart = false);
    });
    if (!widget.post.likes.contains(_currentUserId)) {
      widget.onLike();
    }
  }

  String get _currentUserId {
    return ref.read(currentUserProvider).id;
  }

  bool get _isLiked => widget.post.likes.contains(_currentUserId) || widget.post.reactions.containsKey(_currentUserId);

  String? get _myReaction => widget.post.reactions[_currentUserId];

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}y';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Just now';
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveAuthor = ref.watch(otherUserProvider(widget.post.userId));
    final displayName = liveAuthor.asData?.value?.name ?? widget.post.userName;
    final displayAvatar = liveAuthor.asData?.value?.avatarUrl
        ?? widget.post.userAvatar
        ?? 'https://i.pravatar.cc/100?u=${widget.post.userId}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.5),
          bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark, displayName, displayAvatar),
          if (widget.post.caption.isNotEmpty && widget.post.caption != widget.post.mood)
            _buildCaption(isDark),
          if (widget.post.imageUrl != null) _buildImage(),
          if (widget.post.imageUrl == null && widget.post.mood != null &&
              (widget.post.caption.isEmpty || widget.post.caption == widget.post.mood))
            _buildMoodHero(isDark),
          _buildActions(isDark),
          if (widget.post.commentCount > 0)
            _buildRecentComment(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, String displayName, String displayAvatar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/view/${widget.post.userId}'),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(displayAvatar),
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/profile/view/${widget.post.userId}'),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (widget.post.isUserVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: AppTheme.primaryBlue, size: 14),
                    ],
                    if (widget.post.isPinned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.push_pin, size: 8, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'PINNED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.post.communityId != null && widget.post.communityName != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.play_arrow_rounded, size: 12, color: isDark ? Colors.white30 : Colors.black38),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => context.push('/community/${widget.post.communityId}'),
                        child: Text(
                          widget.post.communityName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatTimeAgo(widget.post.createdAt),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 4),
                    Text('·', style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
                    const SizedBox(width: 4),
                    Icon(Icons.public, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            color: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 8,
            icon: Icon(Icons.more_horiz, color: isDark ? Colors.white60 : Colors.black54),
            onSelected: (value) {
              if (value == 'delete') {
                ref.read(postsProvider.notifier).deletePost(widget.post.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post deleted')),
                );
              } else if (value == 'pin') {
                ref.read(postsProvider.notifier).togglePinPost(widget.post.id, true);
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Post pinned successfully!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              } else if (value == 'unpin') {
                ref.read(postsProvider.notifier).togglePinPost(widget.post.id, false);
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Post unpinned successfully!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              if (widget.post.userId == _currentUserId) ...[
                PopupMenuItem(
                  value: widget.post.isPinned ? 'unpin' : 'pin',
                  child: Row(
                    children: [
                      Icon(
                        widget.post.isPinned ? Icons.pin_drop_outlined : Icons.push_pin_outlined,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(widget.post.isPinned ? 'Unpin Post' : 'Pin Post'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Delete Post', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ] else ...[
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report Post'),
                ),
                const PopupMenuItem(
                  value: 'hide',
                  child: Text('Hide Post'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: AspectRatio(
              aspectRatio: 1,
              child: widget.post.imageUrl != null
                  ? Image.network(
                      widget.post.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.image_rounded, size: 48)),
                    ),
            ),
          ),
          if (_showHeart)
            AnimatedBuilder(
              animation: _heartScale,
              builder: (context, child) => Transform.scale(
                scale: _heartScale.value,
                child: child,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 100,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isDark) {
    final Set<String> uniqueReactors = {
      ...widget.post.likes,
      ...widget.post.reactions.keys,
    };
    final int reactionCount = uniqueReactors.length;

    return Column(
      children: [
        // Stats Row
        if (reactionCount > 0 || widget.post.commentCount > 0 || widget.post.shareCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (reactionCount > 0) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: () {
                      final Set<String> activeEmojis = {};
                      if (widget.post.likes.isNotEmpty) {
                        activeEmojis.add('👍');
                      }
                      activeEmojis.addAll(widget.post.reactions.values);
                      return activeEmojis.toList().take(3).map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: _buildEmojiImage(emoji, size: 18),
                        );
                      }).toList();
                    }(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatCount(reactionCount),
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],
                const Spacer(),
                if (widget.post.commentCount > 0)
                  Text(
                    '${_formatCount(widget.post.commentCount)} comments',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                if (widget.post.commentCount > 0 && widget.post.shareCount > 0)
                  Text(' · ', style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                if (widget.post.shareCount > 0)
                  Text(
                    '${_formatCount(widget.post.shareCount)} shares',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                  ),
              ],
            ),
          ),
        Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12, indent: 12, endIndent: 12),
        // Buttons Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (buttonContext) {
                    Widget reactionWidget;
                    Color? reactionColor;
                    String reactionLabel = 'Like';

                    if (_myReaction != null) {
                      if (_myReaction == '👍') {
                        reactionLabel = 'Like';
                        reactionWidget = const Icon(Icons.thumb_up, size: 20, color: AppTheme.primaryBlue);
                        reactionColor = AppTheme.primaryBlue;
                      } else if (_myReaction == '❤️') {
                        reactionLabel = 'Love';
                        reactionWidget = const Icon(Icons.favorite, size: 20, color: Colors.red);
                        reactionColor = Colors.red;
                      } else {
                        if (_myReaction == '😆') {
                          reactionLabel = 'Haha';
                          reactionColor = Colors.amber[800];
                        } else if (_myReaction == '😮') {
                          reactionLabel = 'Wow';
                          reactionColor = Colors.amber[800];
                        } else if (_myReaction == '😢') {
                          reactionLabel = 'Sad';
                          reactionColor = Colors.amber[800];
                        } else if (_myReaction == '😡') {
                          reactionLabel = 'Angry';
                          reactionColor = Colors.deepOrange;
                        } else {
                          reactionLabel = 'Like';
                          reactionColor = Colors.orange;
                        }
                        reactionWidget = Icon(Icons.thumb_up, size: 20, color: reactionColor);
                      }
                    } else if (_isLiked) {
                      reactionWidget = const Icon(Icons.thumb_up, size: 20, color: AppTheme.primaryBlue);
                      reactionColor = AppTheme.primaryBlue;
                      reactionLabel = 'Like';
                    } else {
                      reactionWidget = Icon(Icons.thumb_up_alt_outlined, size: 20, color: isDark ? Colors.white70 : Colors.black54);
                    }

                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showReactionPopup(buttonContext, isDark);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            reactionWidget,
                            const SizedBox(width: 8),
                            Text(
                              reactionLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: reactionColor ?? (isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                ),
              ),
              Expanded(
                child: _FbActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comment',
                  isDark: isDark,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CommentsSheet(
                        postId: widget.post.id,
                        postUserName: widget.post.userName,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _FbActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  isDark: isDark,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _ShareSheet(post: widget.post),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentComment(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CommentsSheet(
                  postId: widget.post.id,
                  postUserName: widget.post.userName,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
              child: Text(
                'View more comments',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          StreamBuilder(
            stream: firestoreProvider
                .collection('posts')
                .doc(widget.post.id)
                .collection('comments')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              final doc = snapshot.data!.docs.first;
              final comment = CommentModel.fromMap(doc.data() as Map<String, dynamic>);
              
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(
                      comment.userAvatar ?? 'https://i.pravatar.cc/100?u=${comment.userId}',
                    ),
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                comment.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            _formatTimeAgo(comment.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showReactionPopup(BuildContext buttonContext, bool isDark) {
    if (_reactionOverlayEntry != null) {
      _hideReactionPopup();
      return;
    }

    final renderBox = buttonContext.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _reactionOverlayEntry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(buttonContext).size.width;
        double leftPosition = offset.dx - (300 - size.width) / 2;
        // Clamp to prevent overlay going off-screen
        leftPosition = leftPosition.clamp(12.0, screenWidth - 312.0);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _hideReactionPopup();
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: leftPosition,
              top: offset.dy - 65,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface.withOpacity(0.98) : Colors.white.withOpacity(0.98),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['👍', '❤️', '😆', '😮', '😢', '😡'].map((emoji) {
                      return _ReactionItem(
                        emoji: emoji,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (emoji == '👍') {
                            widget.onLike();
                          } else {
                            ref.read(postsProvider.notifier).reactToPost(
                              widget.post.id,
                              _currentUserId,
                              emoji,
                            );
                          }
                          _hideReactionPopup();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(buttonContext).insert(_reactionOverlayEntry!);
  }

  void _hideReactionPopup() {
    _reactionOverlayEntry?.remove();
    _reactionOverlayEntry = null;
  }

  Widget _buildCaption(bool isDark) {
    final caption = widget.post.caption;
    final isLongCaption = caption.length > 100;
    final displayCaption = isLongCaption && !_isExpanded ? '${caption.substring(0, 100)}...' : caption;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: () {
          if (isLongCaption) setState(() => _isExpanded = !_isExpanded);
        },
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: displayCaption,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.4,
                ),
              ),
              if (isLongCaption)
                TextSpan(
                  text: _isExpanded ? ' See less' : ' See more',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Mood-only posts get a gradient hero card instead of a blank image slot
  Widget _buildMoodHero(bool isDark) {
    final mood = widget.post.mood!;
    final parts = mood.split(' ');
    final emoji = parts.first;
    final label = parts.skip(1).join(' ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue.withOpacity(isDark ? 0.25 : 0.12),
            AppTheme.primaryGreen.withOpacity(isDark ? 0.25 : 0.12),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEmojiImage(emoji, size: 52),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodBadge(bool isDark) {
    final mood = widget.post.mood!;
    final parts = mood.split(' ');
    final emoji = parts.first;
    final label = parts.skip(1).join(' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEmojiImage(emoji, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color? iconColor;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? (isDark ? Colors.white70 : AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final PostModel post;
  const _ShareSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Future<void> copyLink() async {
      // Simulate copying a link to the post
      // In production, this would be a real URL
      final postUrl = 'https://situationship.app/post/${post.id}';

      // Using ScaffoldMessenger to show feedback (in production use Clipboard.setData)
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Link copied: $postUrl')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.success,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 5,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Text('Share Post', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          // Send in Chat
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('💬', style: TextStyle(fontSize: 22)),
              ),
              title: const Text('Send in Chat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Select a conversation to share'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
          // Copy Link
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('📋', style: TextStyle(fontSize: 22)),
              ),
              title: const Text('Copy Link', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: copyLink,
            ),
          ),
          // Share to Twitter (placeholder)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('🐦', style: TextStyle(fontSize: 22)),
              ),
              title: const Text('Share to Twitter', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Twitter integration coming soon'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
          // Share to Instagram (placeholder)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('📸', style: TextStyle(fontSize: 22)),
              ),
              title: const Text('Share to Instagram', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Instagram integration coming soon'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
          // More Options (placeholder)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('📲', style: TextStyle(fontSize: 22)),
              ),
              title: const Text('More Options', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('More sharing options coming soon'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _FbActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDark;

  const _FbActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: color ?? (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionItem extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionItem({required this.emoji, required this.onTap});

  @override
  State<_ReactionItem> createState() => _ReactionItemState();
}

class _ReactionItemState extends State<_ReactionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity()..scale(_isHovered ? 1.25 : 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildEmojiImage(widget.emoji, size: 28),
        ),
      ),
    );
  }
}

Widget _buildEmojiImage(String emoji, {double size = 20}) {
  try {
    final runes = emoji.runes.toList();
    final cleanRunes = runes.where((r) => r != 0xFE0F).toList();
    final hex = cleanRunes.map((r) => r.toRadixString(16)).join('-');
    
    return Image.network(
      'https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/72x72/$hex.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Text(
        emoji,
        style: TextStyle(
          fontSize: size,
          fontFamilyFallback: const ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji', 'Android Emoji'],
        ),
      ),
    );
  } catch (_) {
    return Text(
      emoji,
      style: TextStyle(
        fontSize: size,
        fontFamilyFallback: const ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji', 'Android Emoji'],
      ),
    );
  }
}

