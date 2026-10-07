import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/app_strings.dart';
import 'brand_palette.dart';
import 'theme_cubit.dart';

/// Compact Classic / Warm / Grove theme picker.
class ThemeSwitcherTile extends StatelessWidget {
  const ThemeSwitcherTile({
    super.key,
    this.dense = false,
    this.tileColor,
  });

  final bool dense;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final selected = context.watch<ThemeCubit>().state;

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
                Icon(Icons.palette_outlined, color: selected.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.theme,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(t.themeHint,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final p in BrandPalette.all) ...[
                  Expanded(
                    child: _ThemeSwatch(
                      palette: p,
                      label: switch (p.id) {
                        'warm' => t.themeWarm,
                        'grove' => t.themeGrove,
                        _ => t.themeClassic,
                      },
                      selected: selected.id == p.id,
                      onTap: () => context.read<ThemeCubit>().setTheme(p.id),
                    ),
                  ),
                  if (p != BrandPalette.all.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final BrandPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
