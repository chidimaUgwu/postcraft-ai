// lib/screens/post_detail/post_detail_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/video_player_tile.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PostModel _post;
  String _platform = 'whatsapp';

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    // Start listening to captions for default platform
    _startListening(_platform);
  }

  void _startListening(String platform) {
    context.read<AiProvider>().listenToPlatform(_post.id, platform);
  }

  Future<void> _regenerate() async {
    await context.read<AiProvider>().generate(
          postId: _post.id,
          platform: _platform,
          propertyData: _post.toPropertyData(),
        );
  }

  /// Share the caption + attached property images via the OS share sheet.
  /// The user can then pick LinkedIn, WhatsApp, TikTok, Instagram, etc.
  /// and the images + text are pre-filled in that app.
  /// Human-friendly timestamp for a caption version (Today / Yesterday /
  /// "Nd ago" / full date).
  static String _formatCaptionDate(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (diff == 0) return 'Today $hh:$mm';
    if (diff == 1) return 'Yesterday $hh:$mm';
    if (diff < 7) return '${diff}d ago • $hh:$mm';
    return '${dt.day}/${dt.month}/${dt.year} $hh:$mm';
  }

  Future<void> _shareWithMedia(String captionText) async {
    // Web can\'t share local files — fall back to text-only.
    if (kIsWeb || _post.imagePaths.isEmpty) {
      await Share.share(captionText);
      return;
    }
    final files = _post.imagePaths
        .where((p) => File(p).existsSync())
        .map((p) => XFile(p))
        .toList();
    if (files.isEmpty) {
      await Share.share(captionText);
      return;
    }
    await Share.shareXFiles(
      files,
      text: captionText,
      subject: _post.title,
    );
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
            'This permanently deletes the post and all its captions. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await context.read<PostsProvider>().deletePost(_post.id);
      if (mounted && ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title:
              Text(_post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  _deletePost();
                  return;
                }
                await context.read<PostsProvider>().updateStatus(_post.id, v);
                setState(() => _post.status = v);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'saved', child: Text('✅ Mark as Saved')),
                const PopupMenuItem(
                    value: 'favorite', child: Text('❤️ Mark as Favorite')),
                const PopupMenuItem(
                    value: 'draft', child: Text('📝 Move to Draft')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('🗑️ Delete Post',
                        style: TextStyle(color: AppTheme.error))),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Image carousel ───────────────────────────────────
                // Update the image carousel section

                if (_post.imagePaths.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: PageView.builder(
                      itemCount: _post.imagePaths.length,
                      itemBuilder: (_, i) {
                        final path = _post.imagePaths[i];
                        final lower = path.toLowerCase();
                        final isVideo = lower.endsWith('.mp4') ||
                            lower.endsWith('.mov') ||
                            lower.endsWith('.avi') ||
                            lower.endsWith('.mkv') ||
                            lower.endsWith('.webm') ||
                            lower.endsWith('.m4v');
                        if (isVideo) {
                          return VideoPlayerTile(
                              path: path,
                              height: 220,
                              width: double.infinity);
                        }
                        return buildLocalImage(
                          path,
                          height: 220,
                          width: double.infinity,
                        );
                      },
                    ),
                  )
                else
                  _imgPlaceholder(),

                // if (_post.imageUrls.isNotEmpty)
            //   SizedBox(
            //       height: 220,
            //       child: PageView.builder(
            //         itemCount: _post.imageUrls.length,
            //         itemBuilder: (_, i) => Image.network(_post.imageUrls[i],
            //             fit: BoxFit.cover,
            //             errorBuilder: (_, __, ___) => _imgPlaceholder()),
            //       ))
            // else
            //   _imgPlaceholder(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Price + title ────────────────────────────────
                    Text(
                      '${AppConstants.formatPrice(_post.price)} / ${_post.pricePeriod}',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_post.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark)),
                    if (_post.address != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 15, color: AppTheme.textMid),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(_post.address!,
                                style:
                                    const TextStyle(color: AppTheme.textMid))),
                      ]),
                    ],

                    const SizedBox(height: 16),

                    // ── Specs ────────────────────────────────────────
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _Spec(Icons.bed, '${_post.bedrooms} Bedrooms'),
                      _Spec(Icons.bathtub, '${_post.bathrooms} Bathrooms'),
                      _Spec(Icons.wc, '${_post.toilets} Toilets'),
                      _Spec(Icons.water_drop,
                          _post.waterAvailable ? 'Water ✓' : 'No Water',
                          ok: _post.waterAvailable),
                      _Spec(
                          Icons.bolt,
                          _post.electricityAvailable
                              ? 'Electricity ✓'
                              : 'No PHCN',
                          ok: _post.electricityAvailable),
                      _Spec(Icons.local_parking,
                          _post.parkingAvailable ? 'Parking ✓' : 'No Parking',
                          ok: _post.parkingAvailable),
                    ]),

                    if (_post.extraFeatures.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _post.extraFeatures
                              .map((f) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(f,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w500))))
                              .toList()),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // ── AI Caption section ────────────────────────────
                    const Text('AI Captions',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    const SizedBox(height: 12),

                    // Platform tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                          children: AppConstants.platforms.map((p) {
                        final pColor =
                            AppTheme.platformColors[p] ?? AppTheme.primary;
                        final active = _platform == p;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _platform = p);
                            _startListening(p);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: active ? pColor : Colors.white,
                              border: Border.all(
                                  color: active ? pColor : AppTheme.border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(children: [
                              Icon(AppTheme.platformIcons[p],
                                  size: 14,
                                  color: active ? Colors.white : pColor),
                              const SizedBox(width: 5),
                              Text(p[0].toUpperCase() + p.substring(1),
                                  style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : AppTheme.textMid,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        );
                      }).toList()),
                    ),

                    const SizedBox(height: 14),

                    // ── Caption versions (real-time from Firestore) ───
                    Consumer<AiProvider>(builder: (_, ai, __) {
                      final selected = ai.selectedFor(_platform);
                      if (ai.generating)
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      if (selected != null)
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.event,
                                    size: 13, color: AppTheme.textMid),
                                const SizedBox(width: 4),
                                Text(
                                    'v${selected.generationNum} • ${_formatCaptionDate(selected.createdAt)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMid,
                                        fontWeight: FontWeight.w500)),
                              ]),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.border)),
                                child: Text(selected.captionText,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.6)),
                              ),
                              const SizedBox(height: 10),
                              Row(children: [
                                _SmBtn('Copy', Icons.copy, () {
                                  Clipboard.setData(ClipboardData(
                                      text: selected.captionText));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied!')));
                                }),
                                const SizedBox(width: 8),
                                _SmBtn('Share', Icons.share,
                                    () => _shareWithMedia(selected.captionText)),
                                const SizedBox(width: 8),
                                _SmBtn('↻ New', Icons.autorenew, _regenerate),
                              ]),
                              if (ai.versionsFor(_platform).length > 1) ...[
                                const SizedBox(height: 8),
                                Text(
                                    '${ai.versionsFor(_platform).length} versions generated. Earlier ones are preserved.',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.textMid)),
                              ],
                            ]);
                      return Column(children: [
                        const Text('No caption yet for this platform.',
                            style: TextStyle(color: AppTheme.textMid)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _regenerate,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                              'Generate for ${_platform[0].toUpperCase()}${_platform.substring(1)}'),
                        ),
                      ]);
                    }),
                    const SizedBox(height: 30),
                  ]),
            ),
          ]),
        ),
      );

  Widget _imgPlaceholder() => Container(
      height: 180,
      color: AppTheme.background,
      child: const Center(
          child: Icon(Icons.home_work, size: 60, color: AppTheme.textLight)));
}

class _Spec extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool? ok;
  const _Spec(this.icon, this.label, {this.ok});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: ok == false
                  ? AppTheme.textLight
                  : ok == true
                      ? AppTheme.secondary
                      : AppTheme.textMid),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: ok == false ? AppTheme.textLight : AppTheme.textDark)),
        ]),
      );
}

class _SmBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SmBtn(this.label, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: AppTheme.textMid),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}
