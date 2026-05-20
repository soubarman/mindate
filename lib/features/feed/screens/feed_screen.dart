import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';
import '../widgets/quick_post_box.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/providers/firestore_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final postsStream = ref.watch(postsStreamProvider);
    final isLoading = postsStream.isLoading;
    final posts = ref.watch(filteredPostsProvider);
    final activeFilter = ref.watch(feedFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(postsPaginationProvider.notifier).refresh();
        },
        color: AppTheme.primaryBlue,
        child: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark, currentUser, ref),
          const SliverToBoxAdapter(
            child: StoriesRow(),
          ),
          // ── Inline post composer ─────────────────────────────────────────
          const SliverToBoxAdapter(
            child: QuickPostBox(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _TabChip(
                      label: 'All',
                      isSelected: activeFilter == 'all',
                      onTap: () =>
                          ref.read(feedFilterProvider.notifier).state = 'all',
                    ),
                    const SizedBox(width: 8),
                    _TabChip(
                      label: 'Following',
                      isSelected: activeFilter == 'following',
                      onTap: () =>
                          ref.read(feedFilterProvider.notifier).state = 'following',
                    ),
                    const SizedBox(width: 8),
                    _TabChip(
                      label: 'Trending',
                      isSelected: activeFilter == 'trending',
                      onTap: () =>
                          ref.read(feedFilterProvider.notifier).state = 'trending',
                    ),
                    const SizedBox(width: 8),
                    _TabChip(
                      label: 'Communities',
                      isSelected: activeFilter == 'communities',
                      onTap: () =>
                          ref.read(feedFilterProvider.notifier).state = 'communities',
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Firestore permission error — visible banner ──────────────────
          if (postsStream.hasError)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.error.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppTheme.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🔒 Firestore permission denied — fix your security rules in the Firebase Console.\n\nOpen F12 → Console to see the exact error.',
                        style: TextStyle(color: AppTheme.error, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Show loading shimmer while Firestore stream is loading
          if (isLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _PostShimmer(isDark: isDark),
                childCount: 3,
              ),
            )
          else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = posts[index];
                  return PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onLike: () {
                      ref
                          .read(postsProvider.notifier)
                          .toggleLike(post.id, currentUser.id);
                    },
                  );
                },
                childCount: posts.length,
              ),
            ),
            if (posts.isEmpty && !postsStream.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  emoji: '✨',
                  title: 'Nothing here yet!',
                  message: 'The vibe is just getting started. Pull down to refresh or create the first post! 🚀',
                  onAction: () => context.push('/create-post'),
                  actionLabel: 'Start the Vibe 🔥',
                ),
              ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      ),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    bool isDark,
    UserModel currentUser,
    WidgetRef ref,
  ) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: ShaderMask(
        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
        child: const Text(
          'Situationship',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
      actions: [
        _buildCoinBadge(currentUser.coins, isDark),
        Consumer(
          builder: (context, ref, child) {
            final notificationsAsync = ref.watch(notificationsStreamProvider);
            final notifications = notificationsAsync.asData?.value ?? [];
            final unreadCount = notifications.where((n) => !n.isRead).length;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => _showNotificationsSheet(context, currentUser, ref),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined, 
                      size: 20, 
                      color: unreadCount > 0 ? AppTheme.primaryBlue : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          onPressed: () => context.push('/search'),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.search_rounded, size: 20),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => context.go('/profile'),
            child: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: currentUser.avatarUrl != null
                        ? Image.network(currentUser.avatarUrl!,
                            fit: BoxFit.cover)
                        : const Center(
                            child: Text('😎', style: TextStyle(fontSize: 20))),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildCoinBadge(int coins, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, UserModel currentUser, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final notificationsAsync = ref.watch(notificationsStreamProvider);
            
            // Mark all as read when opening notifications
            WidgetsBinding.instance.addPostFrameCallback((_) {
              markAllNotificationsAsRead(currentUser.id);
            });

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Notifications 🔔',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: notificationsAsync.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('✨', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  'All caught up!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white60 : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Reactions and chat requests will appear here.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          itemCount: list.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = list[index];
                            IconData icon;
                            Color iconColor;
                            
                            if (item.type == 'reaction') {
                              icon = Icons.favorite_rounded;
                              iconColor = Colors.pinkAccent;
                            } else if (item.type == 'gift') {
                              icon = Icons.card_giftcard_rounded;
                              iconColor = Colors.amber;
                            } else {
                              icon = Icons.chat_bubble_rounded;
                              iconColor = AppTheme.primaryBlue;
                            }

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: iconColor.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(icon, color: iconColor, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.body,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white70 : AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatTime(item.createdAt),
                                          style: const TextStyle(fontSize: 10.5, color: AppTheme.textTertiary, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error loading notifications: $e')),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Shimmer placeholder while loading ────────────────────────────────────────

class _PostShimmer extends StatelessWidget {
  final bool isDark;
  const _PostShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shimmerColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 240,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            height: 12,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Chip ─────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
