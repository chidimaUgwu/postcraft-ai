// lib/widgets/video_player_tile.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_theme.dart';

/// Inline player for a local video file. Shows a thumbnail with a play
/// overlay until the user taps to start — then plays with a mini controller
/// (play/pause, seek bar). Used in the caption-generation screen and post
/// detail screen so the user can rewatch their property video without
/// leaving the app.
class VideoPlayerTile extends StatefulWidget {
  final String path;
  final double? height;
  final double? width;
  const VideoPlayerTile(
      {super.key, required this.path, this.height, this.width});

  @override
  State<VideoPlayerTile> createState() => _VideoPlayerTileState();
}

class _VideoPlayerTileState extends State<VideoPlayerTile> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _failed = false;
  // True once the controller has loaded the first frame. While false we
  // show the initialising spinner; once true we show either the first-frame
  // cover (not playing) or the live video (playing).
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Pre-load the first frame as the cover image so the user sees a
    // thumbnail of their video instead of a plain black box.
    if (!kIsWeb) _initForCover();
  }

  @override
  void dispose() {
    _controller?.removeListener(_tick);
    _controller?.dispose();
    super.dispose();
  }

  /// Initialise the controller just enough to render the first frame as a
  /// cover. We do NOT auto-play — the user taps to start playback.
  Future<void> _initForCover() async {
    if (_controller != null || _initializing) return;
    setState(() => _initializing = true);
    try {
      final c = VideoPlayerController.file(File(widget.path));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.setLooping(false);
      // Seek to a small offset so the first frame isn\'t a black intro frame
      // on some codecs. Silent if it fails.
      try {
        await c.seekTo(const Duration(milliseconds: 200));
      } catch (_) {}
      c.addListener(_tick);
      setState(() {
        _controller = c;
        _initializing = false;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _initializing = false;
      });
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      // Restart from the beginning if it finished.
      if (c.value.position >= c.value.duration) {
        c.seekTo(Duration.zero);
      }
      c.play();
    }
    setState(() {});
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _placeholder();
    if (_failed) return _placeholder(broken: true);

    final c = _controller;
    // Still loading — show a spinner. Retry on tap if the cover load failed.
    if (c == null || !c.value.isInitialized) {
      return GestureDetector(
        onTap: _initForCover,
        child: Container(
          height: widget.height,
          width: widget.width,
          color: Colors.black87,
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    final playing = c.value.isPlaying;

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            color: Colors.black,
            width: widget.width,
            height: widget.height,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          ),
          // Play/pause overlay on tap.
          // Big play overlay on the cover frame when paused / not yet started.
          if (!playing)
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.black26,
              alignment: Alignment.center,
              child: const Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 72),
            ),
          // Bottom control strip.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(children: [
              IconButton(
                icon: Icon(
                    c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white),
                onPressed: _togglePlay,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              Text(
                '${_fmt(c.value.position)} / ${_fmt(c.value.duration)}',
                style:
                    const TextStyle(color: Colors.white, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    min: 0,
                    max: c.value.duration.inMilliseconds.toDouble().clamp(
                        1, double.infinity),
                    value: c.value.position.inMilliseconds
                        .clamp(0, c.value.duration.inMilliseconds)
                        .toDouble(),
                    activeColor: AppTheme.primary,
                    inactiveColor: Colors.white24,
                    onChanged: (v) =>
                        c.seekTo(Duration(milliseconds: v.toInt())),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _placeholder({bool broken = false}) => Container(
        height: widget.height,
        width: widget.width,
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(broken ? Icons.broken_image : Icons.videocam,
                  color: Colors.white70, size: 48),
              const SizedBox(height: 6),
              Text(broken ? 'Video unavailable' : 'Video',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
}
