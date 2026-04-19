// lib/screens/create/platform_selection_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import 'generation_screen.dart';

class PlatformSelectionScreen extends StatefulWidget {
  final List<XFile> images;
  final Map<String, Uint8List> imageBytes;
  final Map<String, dynamic> postData;
  const PlatformSelectionScreen(
      {super.key,
      required this.images,
      required this.imageBytes,
      required this.postData});
  @override
  State<PlatformSelectionScreen> createState() =>
      _PlatformSelectionScreenState();
}

class _PlatformSelectionScreenState extends State<PlatformSelectionScreen> {
  String? _selected;
  bool _loading = false;

  static const _platforms = [
    {
      'key': 'whatsapp',
      'label': 'WhatsApp',
      'desc': 'Short, direct, bold key points with CTA'
    },
    {
      'key': 'instagram',
      'label': 'Instagram',
      'desc': 'Lifestyle hook + emojis + hashtags'
    },
    {
      'key': 'facebook',
      'label': 'Facebook',
      'desc': 'Detailed & engaging community post'
    },
    {
      'key': 'twitter',
      'label': 'Twitter / X',
      'desc': 'Max 280 chars — punchy and catchy'
    },
    {
      'key': 'linkedin',
      'label': 'LinkedIn',
      'desc': 'Professional investor-focused copy'
    },
    {
      'key': 'tiktok',
      'label': 'TikTok',
      'desc': 'Punchy hook caption + on-screen text overlays'
    },
  ];

  Future<void> _createAndGenerate() async {
    if (_selected == null) return;
    setState(() => _loading = true);

    final postsProv = context.read<PostsProvider>();
    final post = await postsProv.createPost(widget.postData, widget.images);
    if (!mounted) return;

    if (post == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            postsProv.error ?? 'Failed to save post. Check your connection.'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }

    final aiProv = context.read<AiProvider>();
    aiProv.listenToPlatform(post.id, _selected!);

    final ok = await aiProv.generate(
      postId: post.id,
      platform: _selected!,
      propertyData: widget.postData,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(aiProv.error ??
            'Caption generation failed. Check your API key in Settings.'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GenerationScreen(post: post, initialPlatform: _selected!),
        ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Choose Platform'), leading: const BackButton()),
        body: Column(children: [
          const StepIndicator(current: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a platform',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    const SizedBox(height: 6),
                    const Text(
                      'Each platform gets a unique caption. You can generate for more platforms on the results screen.',
                      style: TextStyle(color: AppTheme.textMid, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ..._platforms.map((p) => _PlatformCard(
                          platformKey: p['key']!,
                          label: p['label']!,
                          desc: p['desc']!,
                          isSelected: _selected == p['key'],
                          onTap: () => setState(() => _selected = p['key']),
                        )),
                  ]),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Saving post & generating AI caption…',
                    style: TextStyle(color: AppTheme.textMid)),
                SizedBox(height: 4),
                Text('This takes 5–15 seconds',
                    style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: ElevatedButton(
                onPressed: _selected != null ? _createAndGenerate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selected != null ? AppTheme.primary : AppTheme.border,
                ),
                child: Text(_selected != null
                    ? 'Generate for ${_platforms.firstWhere((p) => p['key'] == _selected)['label']}'
                    : 'Select a platform first'),
              ),
            ),
        ]),
      );
}

class _PlatformCard extends StatelessWidget {
  final String platformKey, label, desc;
  final bool isSelected;
  final VoidCallback onTap;
  const _PlatformCard(
      {required this.platformKey,
      required this.label,
      required this.desc,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.platformColors[platformKey] ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
              color: isSelected ? color : AppTheme.border,
              width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? color.withOpacity(0.07) : Colors.white,
        ),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(AppTheme.platformIcons[platformKey],
                  color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isSelected ? color : AppTheme.textDark)),
                const SizedBox(height: 3),
                Text(desc,
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.textMid)),
              ])),
          if (isSelected)
            Icon(Icons.check_circle, color: color, size: 22)
          else
            const Icon(Icons.radio_button_unchecked,
                color: AppTheme.textLight, size: 22),
        ]),
      ),
    );
  }
}
