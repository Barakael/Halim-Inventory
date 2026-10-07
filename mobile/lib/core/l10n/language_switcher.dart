import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_strings.dart';
import 'locale_cubit.dart';
import '../theme/brand_palette.dart';

/// Compact English / Kiswahili language switcher.
class LanguageSwitcherTile extends StatelessWidget {
  const LanguageSwitcherTile({
    super.key,
    this.dense = false,
    this.tileColor,
  });

  final bool dense;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final locale = context.watch<LocaleCubit>().state;

    return Material(
      color: tileColor ?? Colors.transparent,
      child: Padding(
        padding: dense
            ? const EdgeInsets.symmetric(vertical: 8, horizontal: 4)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.language,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(t.languageHint,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'en', label: Text(t.english)),
                  ButtonSegment(value: 'sw', label: Text(t.swahili)),
                ],
                selected: {locale.languageCode == 'sw' ? 'sw' : 'en'},
                onSelectionChanged: (s) {
                  context.read<LocaleCubit>().setLocale(Locale(s.first));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small chip for login / splash toolbars.
class LanguageChip extends StatelessWidget {
  const LanguageChip({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isSw = context.watch<LocaleCubit>().isSwahili;

    return TextButton.icon(
      onPressed: () => context.read<LocaleCubit>().toggle(),
      icon: const Icon(Icons.translate_rounded, size: 18),
      label: Text(isSw ? t.swahili : t.english),
      style: TextButton.styleFrom(
        foregroundColor: BrandTokens.current.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}

/// Compact EN | SW toggle for dark app bars / dashboard headers.
class LanguageHeaderToggle extends StatelessWidget {
  const LanguageHeaderToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isSw = context.watch<LocaleCubit>().isSwahili;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: () => context.read<LocaleCubit>().toggle(),
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 6),
                _LangPill(label: 'EN', selected: !isSw),
                const SizedBox(width: 4),
                _LangPill(label: 'SW', selected: isSw),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
                  color: selected ? BrandTokens.current.primary : Colors.white70,
        ),
      ),
    );
  }
}
