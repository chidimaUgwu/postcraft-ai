// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../create/image_selection_screen.dart';
import '../history/history_screen.dart';
import '../post_detail/post_detail_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Start real-time Firestore listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final List<Widget> bodies = [
      _dashBody(),
      const HistoryScreen(),
      const SettingsScreen()
    ];

    return Scaffold(
      appBar: _navIndex == 0
          ? AppBar(
              leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      child: Text(user?.displayName?[0].toUpperCase() ?? 'U',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)))),
              title: Column(children: [
                const Text('PostCraft AI',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Hi, ${user?.displayName ?? 'there'}',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.textMid)),
              ]),
              bottom: TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: 'Drafts'),
                    Tab(text: 'Saved'),
                    Tab(text: 'Favorites')
                  ],
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textMid,
                  indicatorColor: AppTheme.primary),
            )
          : null,
      body: bodies[_navIndex],
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ImageSelectionScreen())),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Post',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }

  Widget _dashBody() => Consumer<PostsProvider>(
        builder: (_, prov, __) {
          if (prov.loading)
            return const Center(child: CircularProgressIndicator());
          if (prov.error != null)
            return Center(
                child: Text(prov.error!,
                    style: const TextStyle(color: AppTheme.error)));
          return TabBarView(controller: _tabs, children: [
            _PostList(
                posts: prov.byStatus('draft'),
                emptyMsg: 'No drafts yet.\nTap + to create your first post!'),
            _PostList(
                posts: prov.byStatus('saved'), emptyMsg: 'No saved posts yet.'),
            _PostList(
                posts: prov.byStatus('favorite'),
                emptyMsg: 'No favorites yet.\nHeart a post to add it here.'),
          ]);
        },
      );
}

class _PostList extends StatelessWidget {
  final List<PostModel> posts;
  final String emptyMsg;
  const _PostList({required this.posts, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty)
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.inbox, size: 60, color: AppTheme.textLight),
        const SizedBox(height: 12),
        Text(emptyMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMid, fontSize: 14)),
      ]));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final post = posts[i];
        return PostCard(
          post: post,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
          onFavorite: () => context.read<PostsProvider>().updateStatus(
              post.id, post.status == 'favorite' ? 'saved' : 'favorite'),
        );
      },
    );
  }
}
