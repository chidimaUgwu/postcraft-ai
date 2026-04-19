// lib/screens/guide/guide_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';

/// Multi-page walkthrough covering every important feature of the app:
/// settings, Gemini key, creating posts, scheduling, sharing.
///
/// Can be opened from Settings (as a help screen) or shown automatically
/// after the first login (via [showOnce]).
class GuideScreen extends StatefulWidget {
  /// When true, shows a "Skip" button and finishes with a single "Got it".
  /// When false, hides Skip — user walks through deliberately.
  final bool firstRun;
  const GuideScreen({super.key, this.firstRun = false});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_GuidePage>[
    _GuidePage(
      icon: Icons.waving_hand,
      title: 'Welcome to PostCraft AI',
      body:
          'PostCraft turns a few property details and photos into high-converting '
          'captions for WhatsApp, Instagram, Facebook, LinkedIn, Twitter/X, and TikTok.\n\n'
          'This quick tour covers everything you need — set-up, creating a post, '
          'sharing, and scheduling.',
    ),
    _GuidePage(
      icon: Icons.vpn_key,
      title: 'Step 1 — Get your free Gemini API key',
      body:
          'PostCraft uses Google Gemini (free) to write your captions. Before '
          'anything else, grab your key:\n\n'
          '1. Visit aistudio.google.com/apikey\n'
          '2. Sign in with Google and click "Create API key"\n'
          '3. Copy the key (starts with AIza…)\n'
          '4. Paste it into Settings → Gemini API Key\n\n'
          'Your key is stored securely in your Firestore profile and is only '
          'used when you generate a caption.',
    ),
    _GuidePage(
      icon: Icons.badge,
      title: 'Step 2 — Fill in your Contact Info',
      body:
          'Open Settings and fill in:\n\n'
          '• Business / Agency name\n'
          '• Phone & WhatsApp numbers\n'
          '• Office address\n'
          '• Website or social link\n\n'
          'The AI automatically weaves these into every caption\'s call-to-action, '
          'so buyers know exactly how to reach you. If you leave them empty, '
          'captions end with a generic "DM for more info".',
    ),
    _GuidePage(
      icon: Icons.public,
      title: 'Step 3 — Set language, currency & country',
      body:
          'Still in Settings → App Preferences:\n\n'
          '• Language — the caption will be written in this language\n'
          '• Currency — all prices use this symbol (₦, \$, GH₵, €, etc.)\n'
          '• Base country — the AI tailors neighbourhoods, slang, and utility '
          'references (PHCN, ECG, KPLC) to this market\n\n'
          'Also choose Light / Dark / System appearance here.',
    ),
    _GuidePage(
      icon: Icons.photo_library,
      title: 'Create a post — Photos',
      body:
          'Tap the "+" Create tab. Step 1 lets you attach up to 5 photos or '
          'videos total.\n\n'
          '• The first image becomes the Cover\n'
          '• Swipe to remove any item\n'
          '• Videos are supported and will be attached when sharing',
    ),
    _GuidePage(
      icon: Icons.edit_note,
      title: 'Property details',
      body:
          'Step 2 captures everything the AI needs:\n\n'
          '• Title, price, price period (monthly / yearly / outright)\n'
          '• Location — type it, use GPS, or search any address worldwide\n'
          '• Property type, compound, bedrooms, bathrooms, toilets\n'
          '• Furnishing level\n'
          '• Description — optional free text the AI uses as seed content\n'
          '• Utilities and extra features (pool, gym, CCTV, etc.)',
    ),
    _GuidePage(
      icon: Icons.apps,
      title: 'Pick your platform',
      body:
          'Step 3 — choose the target platform. Each one gets a tailored format:\n\n'
          '• WhatsApp — scannable, fits 1024-char caption limit\n'
          '• Instagram / Facebook — hook + lifestyle + hashtags\n'
          '• LinkedIn — investor-focused, professional\n'
          '• Twitter/X — under 280 chars\n'
          '• TikTok — hook caption + on-screen text overlays\n\n'
          'You can generate for more platforms after the first caption too.',
    ),
    _GuidePage(
      icon: Icons.auto_awesome,
      title: 'Generate, edit, regenerate',
      body:
          'Step 4 shows the AI caption. From here you can:\n\n'
          '• Copy — puts it on your clipboard\n'
          '• Edit — tweak any line\n'
          '• Regenerate — get a different version (old ones are saved in history)\n'
          '• Save / Favorite — move to your library\n'
          '• Switch tabs to generate for other platforms',
    ),
    _GuidePage(
      icon: Icons.share,
      title: 'Share with media',
      body:
          'Tap "Share to any app" — the OS share sheet opens with BOTH your '
          'images/video AND the caption pre-attached.\n\n'
          'Pick LinkedIn, WhatsApp, Instagram, TikTok, email — anywhere. The '
          'target app opens with everything ready to post.',
    ),
    _GuidePage(
      icon: Icons.schedule,
      title: 'Schedule for later + reminders',
      body:
          'Not posting right now? Tap "Schedule for later":\n\n'
          '• Pick date and time\n'
          '• Choose a reminder offset — 5 min, 15 min, 1 hour, 1 day before\n'
          '• Optionally add to Google / Apple / Outlook Calendar\n\n'
          'A notification fires at the reminder time so you never miss a post — '
          'even with the app closed.',
    ),
    _GuidePage(
      icon: Icons.folder_special,
      title: 'Saved posts & favorites',
      body:
          'Every generated caption is saved with the post. Use the History tab '
          'to search, filter by saved / favorite, re-share, or delete.\n\n'
          'Images are kept on your device — not uploaded — so your listings '
          'stay private.',
    ),
    _GuidePage(
      icon: Icons.lock,
      title: 'Security & privacy',
      body:
          'In Settings you can:\n\n'
          '• Enable App Lock — require your phone\'s fingerprint / Face ID / '
          'passcode every time the app opens\n'
          '• Delete your account — wipes every post, caption, and setting\n'
          '• Sign out\n\n'
          'Firebase keeps you logged in until you explicitly sign out.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _skip() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (!widget.firstRun)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  const Spacer(),
                  Text('${_page + 1} / ${_pages.length}',
                      style: const TextStyle(
                          color: AppTheme.textMid, fontSize: 12)),
                  if (widget.firstRun) ...[
                    const SizedBox(width: 8),
                    TextButton(onPressed: _skip, child: const Text('Skip')),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _PageView(page: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : AppTheme.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(isLast ? 'Got it — start using the app' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePage {
  final IconData icon;
  final String title;
  final String body;
  const _GuidePage(
      {required this.icon, required this.title, required this.body});
}

class _PageView extends StatelessWidget {
  final _GuidePage page;
  const _PageView({required this.page});

  bool _looksLikeUrl(String text) =>
      text.contains('aistudio.google.com/apikey') ||
      RegExp(r'https?://').hasMatch(text);

  @override
  Widget build(BuildContext context) {
    // Shrink the decorative icon on short screens so the body text always
    // has room. 110 was cutting off welcome-page content on small phones.
    final screenH = MediaQuery.of(context).size.height;
    final iconSize = screenH < 650 ? 70.0 : 100.0;
    final iconBoxSize = screenH < 650 ? 90.0 : 110.0;

    return Scrollbar(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child:
                    Icon(page.icon, size: iconSize * 0.55, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 22),
            Text(page.title,
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark)),
            const SizedBox(height: 10),
            SelectableText(
              page.body,
              style: const TextStyle(
                  fontSize: 14, height: 1.55, color: AppTheme.textMid),
            ),
            if (_looksLikeUrl(page.body)) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(
                      text: 'https://aistudio.google.com/apikey'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Link copied — paste it in your browser'),
                    backgroundColor: AppTheme.secondary,
                  ));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Gemini key link'),
              ),
            ],
            // Extra bottom spacer so the last line never sits flush against
            // the dots / CTA button.
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
