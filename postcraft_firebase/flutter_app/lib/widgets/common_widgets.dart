// lib/widgets/common_widgets.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';

// Re-export models and constants so widgets file is a single import
export '../models/models.dart';
export '../utils/app_theme.dart';

/// Helper to display an image from a local path, handling web vs mobile.
/// On web, Image.file crashes, so we show a placeholder instead.
Widget buildLocalImage(String path,
    {double? height, double? width, BoxFit fit = BoxFit.cover}) {
  if (kIsWeb) {
    return Container(
      height: height,
      width: width,
      color: AppTheme.background,
      child: const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image, size: 40, color: AppTheme.textLight),
        SizedBox(height: 4),
        Text('Image saved on device',
            style: TextStyle(fontSize: 11, color: AppTheme.textMid)),
      ])),
    );
  }
  return Image.file(
    File(path),
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (_, __, ___) => Container(
      height: height,
      width: width,
      color: AppTheme.background,
      child: const Center(
          child: Icon(Icons.broken_image, size: 40, color: AppTheme.textLight)),
    ),
  );
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface(context))),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(color: AppTheme.onSurface(context)),
        decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
      ),
    ],
  );
}

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;

  const AppDropdown({super.key, required this.label, required this.value,
    required this.items, required this.onChanged, this.validator});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface(context))),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(color: AppTheme.onSurface(context), fontSize: 14),
        decoration: const InputDecoration(),
        isExpanded: true,
      ),
    ],
  );
}

class StepperField extends StatelessWidget {
  final String label;
  final int value;
  final void Function(int) onChanged;
  final int min, max;

  const StepperField({super.key, required this.label, required this.value,
    required this.onChanged, this.min = 0, this.max = 20});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface(context)))),
    Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.outline(context)), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 18),
          onPressed: value > min ? () => onChanged(value - 1) : null,
          color: value > min ? AppTheme.primary : AppTheme.textLight,
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          color: value < max ? AppTheme.primary : AppTheme.textLight,
        ),
      ]),
    ),
  ]);
}

class ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const ToggleChip({super.key, required this.label, required this.selected, required this.onTap, this.selectedColor});

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : AppTheme.surfaceOf(context),
          border: Border.all(
              color: selected ? color : AppTheme.outline(context),
              width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(label,
            style: TextStyle(
                color:
                    selected ? color : AppTheme.onSurfaceMuted(context),
                fontWeight: FontWeight.w500,
                fontSize: 13)),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final String? subtitle;
  const SectionLabel(this.text, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context))),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle!,
            style: TextStyle(
                fontSize: 12, color: AppTheme.onSurfaceMuted(context))),
      ],
    ]),
  );
}

class StepIndicator extends StatelessWidget {
  final int current;
  static const steps = ['Photos', 'Details', 'Platform', 'Caption'];
  const StepIndicator({super.key, required this.current});

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.surfaceOf(context),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(children: List.generate(steps.length * 2 - 1, (i) {
      if (i.isOdd) return Expanded(child: Container(height: 2,
          color: (i ~/ 2) < current - 1 ? AppTheme.primary : AppTheme.outline(context)));
      final step = i ~/ 2 + 1;
      final done = step < current, active = step == current;
      return Column(children: [
        Container(width: 28, height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: done || active ? AppTheme.primary : AppTheme.surfaceOf(context),
                border: Border.all(color: done || active ? AppTheme.primary : AppTheme.outline(context), width: 2)),
            child: Center(child: done
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text('$step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.onSurfaceMuted(context))))),
        const SizedBox(height: 4),
        Text(steps[step - 1], style: TextStyle(fontSize: 10,
            color: active ? AppTheme.primary : AppTheme.onSurfaceMuted(context),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ]);
    })),
  );
}

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  const PostCard({super.key, required this.post, required this.onTap, this.onFavorite});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: post.imagePaths.isNotEmpty
              ? buildLocalImage(post.imagePaths.first,
                  height: 160, width: double.infinity)
              : _placeholder(),
        ),
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(post.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.onSurface(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (onFavorite != null) GestureDetector(
              onTap: onFavorite,
              child: Icon(post.status == 'favorite' ? Icons.favorite : Icons.favorite_border,
                  color: post.status == 'favorite' ? Colors.red : AppTheme.textLight, size: 20),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${AppConstants.formatPrice(post.price)}/${post.pricePeriod}',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
          if (post.address != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.location_on, size: 13, color: AppTheme.onSurfaceMuted(context)),
              const SizedBox(width: 3),
              Expanded(child: Text(post.address!, style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          const SizedBox(height: 8),
          Row(children: [
            _spec(Icons.bed, '${post.bedrooms} bed'),
            const SizedBox(width: 12),
            _spec(Icons.bathtub, '${post.bathrooms} bath'),
            const SizedBox(width: 12),
            _spec(Icons.wc, '${post.toilets} WC'),
            const Spacer(),
            Text(_relativeDate(post.updatedAt),
                style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
          ]),
        ])),
      ]),
    ),
  );

  Widget _placeholder() => Builder(
      builder: (ctx) => Container(
          height: 160,
          color: AppTheme.surfaceOf(ctx),
          child: Center(
              child: Icon(Icons.home_work,
                  size: 40, color: AppTheme.onSurfaceFaint(ctx)))));

  Widget _spec(IconData icon, String text) => Builder(
      builder: (ctx) => Row(children: [
            Icon(icon, size: 14, color: AppTheme.onSurfaceMuted(ctx)),
            const SizedBox(width: 3),
            Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted(ctx))),
          ]));

  static String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// // lib/widgets/common_widgets.dart
// import 'package:flutter/material.dart';
// import '../models/models.dart';
// import '../utils/app_theme.dart';
//
// // Re-export models and constants so widgets file is a single import
// export '../models/models.dart';
// export '../utils/app_theme.dart';
//
// class AppTextField extends StatelessWidget {
//   final TextEditingController controller;
//   final String label;
//   final String? hint;
//   final bool obscureText;
//   final TextInputType? keyboardType;
//   final String? Function(String?)? validator;
//   final Widget? suffix;
//   final int maxLines;
//   final bool readOnly;
//   final VoidCallback? onTap;
//
//   const AppTextField({
//     super.key, required this.controller, required this.label,
//     this.hint, this.obscureText = false, this.keyboardType,
//     this.validator, this.suffix, this.maxLines = 1,
//     this.readOnly = false, this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) => Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
//       const SizedBox(height: 6),
//       TextFormField(
//         controller: controller, obscureText: obscureText,
//         keyboardType: keyboardType, validator: validator,
//         maxLines: maxLines, readOnly: readOnly, onTap: onTap,
//         decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
//       ),
//     ],
//   );
// }
//
// class AppDropdown<T> extends StatelessWidget {
//   final String label;
//   final T? value;
//   final List<DropdownMenuItem<T>> items;
//   final void Function(T?) onChanged;
//   final String? Function(T?)? validator;
//
//   const AppDropdown({super.key, required this.label, required this.value,
//     required this.items, required this.onChanged, this.validator});
//
//   @override
//   Widget build(BuildContext context) => Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
//       const SizedBox(height: 6),
//       DropdownButtonFormField<T>(
//         initialValue: value, items: items, onChanged: onChanged,
//         validator: validator, decoration: const InputDecoration(), isExpanded: true,
//       ),
//     ],
//   );
// }
//
// class StepperField extends StatelessWidget {
//   final String label;
//   final int value;
//   final void Function(int) onChanged;
//   final int min, max;
//
//   const StepperField({super.key, required this.label, required this.value,
//     required this.onChanged, this.min = 0, this.max = 20});
//
//   @override
//   Widget build(BuildContext context) => Row(children: [
//     Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark))),
//     Container(
//       decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(8)),
//       child: Row(mainAxisSize: MainAxisSize.min, children: [
//         IconButton(
//           icon: const Icon(Icons.remove, size: 18),
//           onPressed: value > min ? () => onChanged(value - 1) : null,
//           color: value > min ? AppTheme.primary : AppTheme.textLight,
//         ),
//         SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.center,
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
//         IconButton(
//           icon: const Icon(Icons.add, size: 18),
//           onPressed: value < max ? () => onChanged(value + 1) : null,
//           color: value < max ? AppTheme.primary : AppTheme.textLight,
//         ),
//       ]),
//     ),
//   ]);
// }
//
// class ToggleChip extends StatelessWidget {
//   final String label;
//   final bool selected;
//   final VoidCallback onTap;
//   final Color? selectedColor;
//
//   const ToggleChip({super.key, required this.label, required this.selected, required this.onTap, this.selectedColor});
//
//   @override
//   Widget build(BuildContext context) {
//     final color = selectedColor ?? AppTheme.primary;
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//         decoration: BoxDecoration(
//           color: selected ? color.withOpacity(0.12) : Colors.white,
//           border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 1),
//           borderRadius: BorderRadius.circular(24),
//         ),
//         child: Text(label, style: TextStyle(
//           color: selected ? color : AppTheme.textMid,
//           fontWeight: FontWeight.w500, fontSize: 13)),
//       ),
//     );
//   }
// }
//
// class SectionLabel extends StatelessWidget {
//   final String text;
//   final String? subtitle;
//   const SectionLabel(this.text, {super.key, this.subtitle});
//   @override
//   Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.only(bottom: 12),
//     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
//       if (subtitle != null) ...[
//         const SizedBox(height: 2),
//         Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
//       ],
//     ]),
//   );
// }
//
// class StepIndicator extends StatelessWidget {
//   final int current;
//   static const steps = ['Photos', 'Details', 'Platform', 'Caption'];
//   const StepIndicator({super.key, required this.current});
//
//   @override
//   Widget build(BuildContext context) => Container(
//     color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//     child: Row(children: List.generate(steps.length * 2 - 1, (i) {
//       if (i.isOdd) return Expanded(child: Container(height: 2,
//           color: (i ~/ 2) < current - 1 ? AppTheme.primary : AppTheme.border));
//       final step = i ~/ 2 + 1;
//       final done = step < current, active = step == current;
//       return Column(children: [
//         Container(width: 28, height: 28,
//           decoration: BoxDecoration(shape: BoxShape.circle,
//             color: done || active ? AppTheme.primary : Colors.white,
//             border: Border.all(color: done || active ? AppTheme.primary : AppTheme.border, width: 2)),
//           child: Center(child: done
//             ? const Icon(Icons.check, color: Colors.white, size: 14)
//             : Text('$step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
//                 color: active ? Colors.white : AppTheme.textLight)))),
//         const SizedBox(height: 4),
//         Text(steps[step - 1], style: TextStyle(fontSize: 10,
//           color: active ? AppTheme.primary : AppTheme.textMid,
//           fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
//       ]);
//     })),
//   );
// }
//
// class PostCard extends StatelessWidget {
//   final PostModel post;
//   final VoidCallback onTap;
//   final VoidCallback? onFavorite;
//   const PostCard({super.key, required this.post, required this.onTap, this.onFavorite});
//
//   @override
//   Widget build(BuildContext context) => Card(
//     margin: const EdgeInsets.only(bottom: 14),
//     child: InkWell(
//       onTap: onTap, borderRadius: BorderRadius.circular(14),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         ClipRRect(
//           borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
//           child: post.imageUrls.isNotEmpty
//               ? Image.network(post.imageUrls.first, height: 160, width: double.infinity, fit: BoxFit.cover,
//                   errorBuilder: (_, __, ___) => _placeholder())
//               : _placeholder(),
//         ),
//         Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Row(children: [
//             Expanded(child: Text(post.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textDark), maxLines: 1, overflow: TextOverflow.ellipsis)),
//             if (onFavorite != null) GestureDetector(
//               onTap: onFavorite,
//               child: Icon(post.status == 'favorite' ? Icons.favorite : Icons.favorite_border,
//                   color: post.status == 'favorite' ? Colors.red : AppTheme.textLight, size: 20),
//             ),
//           ]),
//           const SizedBox(height: 4),
//           Text('${AppConstants.formatPrice(post.price)}/${post.pricePeriod}',
//               style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
//           if (post.address != null) ...[
//             const SizedBox(height: 4),
//             Row(children: [
//               const Icon(Icons.location_on, size: 13, color: AppTheme.textMid),
//               const SizedBox(width: 3),
//               Expanded(child: Text(post.address!, style: const TextStyle(fontSize: 12, color: AppTheme.textMid), maxLines: 1, overflow: TextOverflow.ellipsis)),
//             ]),
//           ],
//           const SizedBox(height: 8),
//           Row(children: [
//             _spec(Icons.bed, '${post.bedrooms} bed'),
//             const SizedBox(width: 12),
//             _spec(Icons.bathtub, '${post.bathrooms} bath'),
//             const SizedBox(width: 12),
//             _spec(Icons.wc, '${post.toilets} WC'),
//           ]),
//         ])),
//       ]),
//     ),
//   );
//
//   Widget _placeholder() => Container(height: 160, color: AppTheme.background,
//       child: const Center(child: Icon(Icons.home_work, size: 40, color: AppTheme.textLight)));
//
//   Widget _spec(IconData icon, String text) => Row(children: [
//     Icon(icon, size: 14, color: AppTheme.textMid), const SizedBox(width: 3),
//     Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
//   ]);
// }
