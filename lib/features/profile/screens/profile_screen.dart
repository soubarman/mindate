import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/seeder.dart';
import '../../../core/providers/firebase_auth_provider.dart';
import '../../feed/screens/comments_screen.dart';
import '../../feed/widgets/post_card.dart';
import '../../feed/screens/saved_posts_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? AppTheme.darkSurface 
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout 🚪', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to log out? We\'ll miss you! ✨'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).signOut();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer(bool isDark) {
    return Scaffold(
      body: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 100),
              // Profile image shimmer
              Center(
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Name shimmer
              Container(
                width: 120,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 8),
              // Username shimmer
              Container(
                width: 80,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 32),
              // Stats shimmer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (i) => Column(
                  children: [
                    Container(
                      width: 40,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                )),
              ),
              const SizedBox(height: 32),
              // Bio shimmer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Grid shimmer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataStreamProvider);
    final user = ref.watch(currentUserProvider);
    
    // Fetch all posts belonging to the user directly, independent of the active Feed filter
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show loading shimmer while user data is loading
    if (userDataAsync.isLoading) {
      return _buildLoadingShimmer(isDark);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context, ref, user, isDark),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildStats(user, posts.length, context, isDark),
                _buildBio(user, context),
                _buildInterests(user, context),
                _buildPostsHeader(context, posts.length, isDark),
              ],
            ),
          ),
          _buildPostsList(posts, isDark, ref),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context, WidgetRef ref, UserModel user, bool isDark) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Vibrant modern gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                ),
              ),
            ),
            // Soft overlay to make text pop
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.1), isDark ? AppTheme.darkBg : AppTheme.lightBg],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: NetworkImage(
                        user.avatarUrl ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.name)}&size=200&background=6ECBF5&color=fff&rounded=true',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: AppTheme.primaryBlue, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (user.location != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          user.location!,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        _HeaderActionButton(
          icon: Icons.edit_rounded,
          onTap: () => context.go('/profile/edit'),
          isDark: isDark,
        ),
        _HeaderActionButton(
          icon: Icons.logout_rounded,
          onTap: () => _handleLogout(context, ref),
          isDark: isDark,
        ),
        _HeaderActionButton(
          icon: Icons.settings_rounded,
          onTap: () => _showSettingsSheet(context, ref),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(ref: ref),
    );
  }

  Widget _buildStats(UserModel user, int postCount, BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(isDark ? 0.05 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: 'Posts', value: '$postCount'),
          _Divider(isDark: isDark),
          _StatItem(label: 'Followers', value: '${user.followers.length}'),
          _Divider(isDark: isDark),
          _StatItem(label: 'Following', value: '${user.following.length}'),
          _Divider(isDark: isDark),
          _StatItem(label: 'Matches', value: '${user.matches.length}'),
        ],
      ),
    );
  }

  Widget _buildBio(UserModel user, BuildContext context) {
    if (user.bio == null || user.bio!.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 1.2,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.bio!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterests(UserModel user, BuildContext context) {
    if (user.interests == null || user.interests!.isEmpty) return const SizedBox();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Interests',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 1.2,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: (user.interests as List<dynamic>).map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.primaryBlue.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  interest.toString(),
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsHeader(BuildContext context, int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
            child: const Icon(Icons.grid_view_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            'My Posts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count posts',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverList _buildPostsList(
    List<PostModel> posts,
    bool isDark,
    WidgetRef ref,
  ) {
    if (posts.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          Container(
            margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Column(
              children: [
                const Text('✨', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your first vibe with the world!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = posts[index];
          final currentUser = ref.read(currentUserProvider);
          return PostCard(
            key: ValueKey(post.id),
            post: post,
            onLike: () => ref.read(postsProvider.notifier).toggleLike(post.id, currentUser.id),
          );
        },
        childCount: posts.length,
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final WidgetRef ref;
  const _SettingsSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Settings ⚙️', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          // Theme toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : const Color(0xFFF3F6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600))),
                Switch(
                  value: themeMode == ThemeMode.dark,
                  activeColor: AppTheme.primaryBlue,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).state =
                        val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Notifications
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : const Color(0xFFF3F6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_outlined, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600))),
                Switch(
                  value: true,
                  activeColor: AppTheme.primaryBlue,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Privacy
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: isDark ? AppTheme.darkCard : const Color(0xFFF3F6FF),
            leading: Icon(Icons.privacy_tip_outlined, color: AppTheme.accentPurple),
            title: const Text('Privacy', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Privacy settings coming soon ✨'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Saved Posts (Bookmarks)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: isDark ? AppTheme.darkCard : const Color(0xFFF3F6FF),
            leading: const Icon(Icons.bookmark_outline, color: AppTheme.primaryBlue),
            title: const Text('Saved Posts', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
              );
            },
          ),
           const SizedBox(height: 20),
          // Logout
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error.withOpacity(0.1),
                foregroundColor: AppTheme.error,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.4),
          ),
        ),
        child: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: isDark ? AppTheme.darkBorder : Colors.grey.withOpacity(0.2),
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
