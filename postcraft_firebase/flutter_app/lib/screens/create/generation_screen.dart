// lib/screens/create/generation_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/providers.dart';
import '../../services/notification_service.dart';
import '../home/home_screen.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/video_player_tile.dart';

class GenerationScreen extends StatefulWidget {
  final PostModel post;
  final String initialPlatform;
  const GenerationScreen(
      {super.key, required this.post, required this.initialPlatform});
  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen> {
  late String _platform;
  bool _editing = false;
  late TextEditingController _editCtrl;
  int _currentImageIndex = 0;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _platform = widget.initialPlatform;
    _editCtrl = TextEditingController();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _switchToPlatform(String platform) async {
    final ai = context.read<AiProvider>();
    setState(() {
      _platform = platform;
      _editing = false;
    });
    ai.listenToPlatform(widget.post.id, platform);
    final versions = ai.versionsFor(platform);
    if (versions.isEmpty) {
      await ai.generate(
        postId: widget.post.id,
        platform: platform,
        propertyData: widget.post.toPropertyData(),
      );
    }
  }

  Future<void> _regenerate() async {
    setState(() => _editing = false);
    await context.read<AiProvider>().generate(
          postId: widget.post.id,
          platform: _platform,
          propertyData: widget.post.toPropertyData(),
        );
  }

  Future<void> _savePost(String status) async {
    await context.read<PostsProvider>().updateStatus(widget.post.id, status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(status == 'saved' ? '✅ Post saved!' : '❤️ Added to favorites!'),
      backgroundColor: AppTheme.secondary,
    ));
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caption copied to clipboard!')),
    );
  }

  Future<void> _schedulePost(String captionText) async {
    final pickerNow = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(pickerNow.year, pickerNow.month, pickerNow.day),
      firstDate: DateTime(pickerNow.year, pickerNow.month, pickerNow.day),
      lastDate: pickerNow.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    // Re-read current time right before opening the time picker so a slow
    // user doesn\'t end up with a stale comparison window.
    final nowBeforeTime = DateTime.now();
    final pickedToday = date.year == nowBeforeTime.year &&
        date.month == nowBeforeTime.month &&
        date.day == nowBeforeTime.day;

    // Default the time to "now + 1 hour" if they picked today so the
    // confirmed time is always in the future by default.
    final defaultTime = pickedToday
        ? TimeOfDay.fromDateTime(nowBeforeTime.add(const Duration(hours: 1)))
        : const TimeOfDay(hour: 9, minute: 0);

    final time = await showTimePicker(
      context: context,
      initialTime: defaultTime,
    );
    if (time == null || !mounted) return;

    final scheduledAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // Re-read "now" RIGHT before validation — anything more than 1 minute
    // in the future is fine. The 1-minute buffer covers the case where the
    // user picks a time exactly at the current minute.
    final nowAtValidation = DateTime.now();
    final minScheduled =
        nowAtValidation.add(const Duration(minutes: 1));
    if (scheduledAt.isBefore(minScheduled)) {
      final hh = nowAtValidation.hour.toString().padLeft(2, '0');
      final mm = nowAtValidation.minute.toString().padLeft(2, '0');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Pick a time at least 1 minute from now. Current time is $hh:$mm.'),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    // Ask how the user wants to be reminded before the post goes out.
    final reminder = await showModalBottomSheet<_ReminderChoice>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReminderSheet(scheduledAt: scheduledAt),
    );
    if (reminder == null || !mounted) return;

    // 1. Local push notification (fires even if app is closed).
    await NotificationService.schedulePostReminder(
      id: widget.post.id.hashCode,
      postTitle: widget.post.title,
      platform: _platform,
      scheduledTime: scheduledAt,
      reminderOffset: reminder.offset,
    );

    // 2. Optional calendar event — hands an .ics file to the OS share sheet.
    if (reminder.addToCalendar) {
      await NotificationService.shareCalendarEvent(
        postTitle: widget.post.title,
        platform: _platform,
        captionText: captionText,
        scheduledTime: scheduledAt,
        reminderOffset: reminder.offset,
      );
    }

    await context.read<PostsProvider>().updatePost(widget.post.id, {
      'scheduledAt': scheduledAt.toIso8601String(),
      'scheduledPlatform': _platform,
      'reminderOffsetMinutes': reminder.offset?.inMinutes,
    });

    if (!mounted) return;
    Clipboard.setData(ClipboardData(text: captionText));

    final formattedDate =
        '${date.day}/${date.month}/${date.year} at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final reminderSummary = reminder.offset == null
        ? 'No pre-reminder'
        : 'Reminder ${_formatOffset(reminder.offset!)} before';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Scheduled for $formattedDate • $reminderSummary\nCaption copied to clipboard!'),
      backgroundColor: AppTheme.secondary,
      duration: const Duration(seconds: 4),
    ));
  }

  String _formatOffset(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
    return '${d.inMinutes} min';
  }

  /// Human-friendly timestamp for the caption card. Today/yesterday get the
  /// short labels, older captions show the full date.
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

  /// Share caption + all media files via system share sheet
  Future<void> _shareWithImages(String captionText) async {
    final imagePaths = widget.post.imagePaths;
    final List<XFile> files = [];

    for (final path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        // Detect MIME type from extension
        final lowerPath = path.toLowerCase();
        String mimeType = 'image/jpeg';
        if (lowerPath.endsWith('.png')) {
          mimeType = 'image/png';
        } else if (lowerPath.endsWith('.mp4')) {
          mimeType = 'video/mp4';
        } else if (lowerPath.endsWith('.mov')) {
          mimeType = 'video/quicktime';
        } else if (lowerPath.endsWith('.avi')) {
          mimeType = 'video/x-msvideo';
        } else if (lowerPath.endsWith('.gif')) {
          mimeType = 'image/gif';
        } else if (lowerPath.endsWith('.webp')) {
          mimeType = 'image/webp';
        }
        files.add(XFile(path, mimeType: mimeType));
      }
    }

    if (files.isNotEmpty) {
      await Share.shareXFiles(
        files,
        text: captionText,
        subject: widget.post.title,
      );
    } else {
      await Share.share(captionText, subject: widget.post.title);
    }
  }

  /// Get list of valid local media files
  List<String> get _validMediaPaths {
    return widget.post.imagePaths.where((path) {
      return File(path).existsSync();
    }).toList();
  }

  bool _isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.platformColors[_platform] ?? AppTheme.primary;
    final mediaPaths = _validMediaPaths;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Caption'),
        leading: const BackButton(),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Save'),
            onPressed: () => _savePost('saved'),
          ),
        ],
      ),
      body: Consumer<AiProvider>(
        builder: (_, ai, __) {
          final versions = ai.versionsFor(_platform);
          final selected = ai.selectedFor(_platform);

          return Column(children: [
            const StepIndicator(current: 4),

            // ── Platform selector bar ────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                    children: AppConstants.platforms.map((p) {
                  final pColor = AppTheme.platformColors[p] ?? AppTheme.primary;
                  final active = _platform == p;
                  final hasVers = ai.versionsFor(p).isNotEmpty;
                  return GestureDetector(
                    onTap: () => _switchToPlatform(p),
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
                            size: 14, color: active ? Colors.white : pColor),
                        const SizedBox(width: 5),
                        Text(p[0].toUpperCase() + p.substring(1),
                            style: TextStyle(
                                color: active ? Colors.white : AppTheme.textMid,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        if (hasVers && !active) ...[
                          const SizedBox(width: 4),
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: pColor, shape: BoxShape.circle)),
                        ],
                      ]),
                    ),
                  );
                }).toList()),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── MEDIA PREVIEW (images/videos at top) ────────
                      if (mediaPaths.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: 220,
                            child: PageView.builder(
                              controller: _pageCtrl,
                              itemCount: mediaPaths.length,
                              onPageChanged: (i) =>
                                  setState(() => _currentImageIndex = i),
                              itemBuilder: (_, i) {
                                final path = mediaPaths[i];
                                if (_isVideo(path)) {
                                  return VideoPlayerTile(
                                      path: path,
                                      width: double.infinity,
                                      height: 220);
                                }
                                return Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppTheme.background,
                                    child: const Center(
                                        child: Icon(Icons.broken_image,
                                            size: 48,
                                            color: AppTheme.textLight)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (mediaPaths.length > 1) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              mediaPaths.length,
                              (i) => Container(
                                width: _currentImageIndex == i ? 20 : 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: _currentImageIndex == i
                                      ? color
                                      : AppTheme.border,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            '${mediaPaths.length} media file${mediaPaths.length > 1 ? 's' : ''} — will be shared with caption',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMid),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Generating indicator ─────────────────────────
                      if (ai.generating)
                        Center(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(children: [
                            SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                    color: color, strokeWidth: 3)),
                            const SizedBox(height: 16),
                            Text(
                                'AI is writing for ${_platform[0].toUpperCase()}${_platform.substring(1)}...',
                                style:
                                    const TextStyle(color: AppTheme.textMid)),
                            const SizedBox(height: 4),
                            const Text('Crafting the perfect caption...',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textLight)),
                          ]),
                        ))

                      // ── Selected / current caption ────────────────────
                      else if (selected != null) ...[
                        Row(children: [
                          Text('Caption',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: color)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('v${selected.generationNum}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const Spacer(),
                          Text(_formatCaptionDate(selected.createdAt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMid,
                                  fontWeight: FontWeight.w500)),
                        ]),
                        const SizedBox(height: 10),

                        // Caption box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: color, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            color: color.withOpacity(0.04),
                          ),
                          child: _editing
                              ? TextField(
                                  controller: _editCtrl,
                                  maxLines: null,
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.6),
                                  decoration: const InputDecoration.collapsed(
                                      hintText: 'Edit caption...'),
                                )
                              : SelectableText(selected.captionText,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.65,
                                      color: AppTheme.textDark)),
                        ),

                        const SizedBox(height: 14),

                        // Action buttons row
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (_editing) ...[
                            _Btn('Save Edit', Icons.check, AppTheme.secondary,
                                () async {
                              await context.read<AiProvider>().editCaption(
                                  selected.id, _platform, _editCtrl.text);
                              setState(() => _editing = false);
                            }),
                            _Btn('Cancel', Icons.close, AppTheme.textMid,
                                () => setState(() => _editing = false)),
                          ] else ...[
                            _Btn('Copy', Icons.copy, AppTheme.primary,
                                () => _copy(selected.captionText)),
                            _Btn('Edit', Icons.edit, AppTheme.textMid, () {
                              _editCtrl.text = selected.captionText;
                              setState(() => _editing = true);
                            }),
                            _Btn('Favorite', Icons.favorite_border, Colors.red,
                                () => _savePost('favorite')),
                            _Btn('Save', Icons.bookmark, AppTheme.primary,
                                () => _savePost('saved')),
                          ],
                        ]),

                        // ── Share section ─────────────────────────────
                        if (!_editing) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(children: [
                              const Text('Share with media',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.textDark)),
                              const SizedBox(height: 4),
                              Text(
                                mediaPaths.isNotEmpty
                                    ? 'Images + caption will be shared together'
                                    : 'Caption text will be shared',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMid),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _shareWithImages(selected.captionText),
                                  icon: const Icon(Icons.share,
                                      color: Colors.white),
                                  label: const Text('Share to any app',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: color,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 12),

                          // Schedule button
                          OutlinedButton.icon(
                            onPressed: () =>
                                _schedulePost(selected.captionText),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: const Text('Schedule for later'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade700,
                              side: BorderSide(color: Colors.orange.shade700),
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Regenerate button
                        OutlinedButton.icon(
                          onPressed: _regenerate,
                          icon: const Icon(Icons.autorenew, size: 18),
                          label: const Text('Regenerate caption'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: color,
                            side: BorderSide(color: color),
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),

                        if (ai.error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.error.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(ai.error!,
                                      style: const TextStyle(
                                          color: AppTheme.error,
                                          fontSize: 13))),
                            ]),
                          ),
                        ],

                        // ── Version history ────────────────────────────
                        if (versions.length > 1) ...[
                          const SizedBox(height: 28),
                          Row(children: [
                            const Text('All Versions',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppTheme.textDark)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('${versions.length} generated',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          ...versions.map((v) => _VersionCard(
                                version: v,
                                color: color,
                                onSelect: () => context
                                    .read<AiProvider>()
                                    .selectVersion(
                                        widget.post.id, _platform, v.id),
                                onCopy: () => _copy(v.captionText),
                              )),
                        ],
                      ]

                      // ── No caption yet ────────────────────────────────
                      else if (!ai.generating)
                        Center(
                            child: Column(children: [
                          const SizedBox(height: 40),
                          Icon(Icons.auto_awesome,
                              size: 64, color: color.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          const Text('No caption yet for this platform.',
                              style: TextStyle(color: AppTheme.textMid)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _regenerate,
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: Text(
                                'Generate for ${_platform[0].toUpperCase()}${_platform.substring(1)}'),
                          ),
                        ])),
                    ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Btn(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _VersionCard extends StatelessWidget {
  final CaptionVersionModel version;
  final Color color;
  final VoidCallback onSelect, onCopy;
  const _VersionCard(
      {required this.version,
      required this.color,
      required this.onSelect,
      required this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
              color: version.isSelected ? color : AppTheme.border,
              width: version.isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: version.isSelected ? color.withOpacity(0.04) : Colors.white,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('Version ${version.generationNum}',
                  style: TextStyle(
                      fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ),
            if (version.isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle,
                  color: AppTheme.secondary, size: 16),
              const Text(' Active',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.w500)),
            ],
            const Spacer(),
            Text(
                _GenerationScreenState._formatCaptionDate(version.createdAt),
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w500)),
            IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: onCopy,
                color: AppTheme.textMid,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 8),
          Text(version.captionText,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textDark, height: 1.5),
              maxLines: 5,
              overflow: TextOverflow.ellipsis),
          if (!version.isSelected) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onSelect,
              child: Row(children: [
                Icon(Icons.swap_horiz, size: 15, color: color),
                const SizedBox(width: 4),
                Text('Use this version',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ]),
            ),
          ],
        ]),
      );
}

class _ReminderChoice {
  final Duration? offset;
  final bool addToCalendar;
  const _ReminderChoice({required this.offset, required this.addToCalendar});
}

/// Bottom sheet: pick how far ahead to be reminded + whether to export an
/// .ics calendar event so Google / Outlook / Apple Calendar handles it too.
class _ReminderSheet extends StatefulWidget {
  final DateTime scheduledAt;
  const _ReminderSheet({required this.scheduledAt});
  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  Duration? _offset = const Duration(minutes: 15);
  bool _addToCalendar = false;

  static const _options = <_OffsetOption>[
    _OffsetOption('None', null),
    _OffsetOption('5 min before', Duration(minutes: 5)),
    _OffsetOption('15 min before', Duration(minutes: 15)),
    _OffsetOption('30 min before', Duration(minutes: 30)),
    _OffsetOption('1 hour before', Duration(hours: 1)),
    _OffsetOption('3 hours before', Duration(hours: 3)),
    _OffsetOption('1 day before', Duration(days: 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final dt = widget.scheduledAt;
    final formatted =
        '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 16,
          left: 20,
          right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Set a reminder',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark)),
          const SizedBox(height: 4),
          Text('Posting at $formatted',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
          const SizedBox(height: 16),
          const Text('Notify me',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.map((opt) {
              final selected = _offset == opt.offset;
              return ChoiceChip(
                label: Text(opt.label),
                selected: selected,
                onSelected: (_) => setState(() => _offset = opt.offset),
                selectedColor: AppTheme.primary.withOpacity(0.15),
                labelStyle: TextStyle(
                    color: selected ? AppTheme.primary : AppTheme.textMid,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                      color: selected ? AppTheme.primary : AppTheme.border),
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SwitchListTile.adaptive(
              value: _addToCalendar,
              onChanged: (v) => setState(() => _addToCalendar = v),
              title: const Text('Add to my calendar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Opens Google / Apple / Outlook Calendar so the reminder fires even with the app closed.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMid)),
              activeTrackColor: AppTheme.secondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
                onPressed: () => Navigator.pop(
                    context,
                    _ReminderChoice(
                        offset: _offset, addToCalendar: _addToCalendar)),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _OffsetOption {
  final String label;
  final Duration? offset;
  const _OffsetOption(this.label, this.offset);
}
