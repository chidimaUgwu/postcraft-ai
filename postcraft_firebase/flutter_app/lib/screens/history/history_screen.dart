// lib/screens/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../post_detail/post_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  String? _filterStatus;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search your posts…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            })
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _Chip(
                        label: 'All',
                        selected: _filterStatus == null,
                        onTap: () => setState(() => _filterStatus = null)),
                    _Chip(
                        label: 'Drafts',
                        selected: _filterStatus == 'draft',
                        onTap: () => setState(() => _filterStatus = 'draft')),
                    _Chip(
                        label: 'Saved',
                        selected: _filterStatus == 'saved',
                        onTap: () => setState(() => _filterStatus = 'saved')),
                    _Chip(
                        label: 'Favorites',
                        selected: _filterStatus == 'favorite',
                        onTap: () =>
                            setState(() => _filterStatus = 'favorite')),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        body: Consumer<PostsProvider>(builder: (_, prov, __) {
          if (prov.loading)
            return const Center(child: CircularProgressIndicator());

          var posts = _filterStatus != null
              ? prov.byStatus(_filterStatus!)
              : prov.posts;
          if (_searchQuery.isNotEmpty) posts = prov.search(_searchQuery);

          if (posts.isEmpty)
            return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.search_off,
                      size: 60, color: AppTheme.textLight),
                  const SizedBox(height: 12),
                  Text(
                      _searchQuery.isNotEmpty
                          ? 'No posts match "$_searchQuery"'
                          : 'No posts in this category',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMid)),
                ]));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: posts.length,
            itemBuilder: (_, i) {
              final post = posts[i];
              return PostCard(
                post: post,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PostDetailScreen(post: post))),
                onFavorite: () => context.read<PostsProvider>().updateStatus(
                    post.id, post.status == 'favorite' ? 'saved' : 'favorite'),
              );
            },
          );
        }),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.white,
            border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      );
}
