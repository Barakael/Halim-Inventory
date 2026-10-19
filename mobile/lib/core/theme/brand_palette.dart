import 'package:flutter/material.dart';

/// Brand color tokens for a selectable light theme preset.
class BrandPalette {
  const BrandPalette({
    required this.id,
    required this.primary,
    required this.primaryLt,
    required this.accent,
    required this.accentSoft,
    required this.cta,
    required this.ctaInk,
    required this.bg,
    required this.white,
    required this.ink,
    required this.inkMid,
    required this.border,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.warn,
  });

  final String id;
  final Color primary;
  final Color primaryLt;
  final Color accent;
  final Color accentSoft;
  /// Filled button / primary CTA color (yellow on classic).
  final Color cta;
  final Color ctaInk;
  final Color bg;
  final Color white;
  final Color ink;
  final Color inkMid;
  final Color border;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color warn;

  /// Web dashboard blue + mustard CTA (default).
  /// Matches frontend `--dark-blue` / `--primary-blue` / `--light-gray`.
  static const classic = BrandPalette(
    id: 'classic',
    primary: Color(0xFF0A58CA),
    primaryLt: Color(0xFF0D6EFD),
    accent: Color(0xFF0A58CA),
    accentSoft: Color(0x1A0A58CA),
    cta: Color(0xFFFFB800),
    ctaInk: Color(0xFF212529),
    bg: Color(0xFFF8F9FA),
    white: Color(0xFFFFFFFF),
    ink: Color(0xFF212529),
    inkMid: Color(0xFF6C757D),
    border: Color(0xFFDEE2E6),
    danger: Color(0xFFDC3545),
    dangerSoft: Color(0x1ADC3545),
    info: Color(0xFF0D6EFD),
    warn: Color(0xFFFFB800),
  );

  /// Dark navy + coral-orange (replaces warm).
  static const coral = BrandPalette(
    id: 'coral',
    primary: Color(0xFF082032),
    primaryLt: Color(0xFF2C394B),
    accent: Color(0xFFFF4C29),
    accentSoft: Color(0x1AFF4C29),
    cta: Color(0xFFFF4C29),
    ctaInk: Color(0xFFFFFFFF),
    bg: Color(0xFFF3F3F4),
    white: Color(0xFFFFFFFF),
    ink: Color(0xFF082032),
    inkMid: Color(0xFF334756),
    border: Color(0xFFD2D2D2),
    danger: Color(0xFFFF4C29),
    dangerSoft: Color(0x1AFF4C29),
    info: Color(0xFF2C394B),
    warn: Color(0xFFFFB800),
  );

  /// Muted slate greys (settings label: Slate; replaces grove).
  static const indigo = BrandPalette(
    id: 'indigo',
    primary: Color(0xFF1C2E35),
    primaryLt: Color(0xFF3D5259),
    accent: Color(0xFF778E9A),
    accentSoft: Color(0x1A778E9A),
    cta: Color(0xFF778E9A),
    ctaInk: Color(0xFFFFFFFF),
    bg: Color(0xFFF0F1F3),
    white: Color(0xFFFFFFFF),
    ink: Color(0xFF111D21),
    inkMid: Color(0xFF606B72),
    border: Color(0xFFB9BDC5),
    danger: Color(0xFFDC3B2E),
    dangerSoft: Color(0x1ADC3B2E),
    info: Color(0xFF778E9A),
    warn: Color(0xFFE8B84A),
  );

  static const all = <BrandPalette>[classic, coral, indigo];

  static BrandPalette byId(String? id) {
    final key = (id ?? '').toLowerCase().trim();
    // Legacy migrations
    if (key == 'warm') return coral;
    if (key == 'grove') return indigo;
    for (final p in all) {
      if (p.id == key) return p;
    }
    return classic;
  }

  Color primaryOpacity(double o) => primary.withValues(alpha: o);

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  List<BoxShadow> get floatShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.18),
          blurRadius: 28,
          offset: const Offset(0, 8),
        ),
      ];

  TextStyle ts(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        height: height,
        letterSpacing: letterSpacing,
      );
}

/// Provides [BrandPalette] down the tree.
class BrandPaletteScope extends InheritedWidget {
  const BrandPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final BrandPalette palette;

  static BrandPalette of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BrandPaletteScope>();
    return scope?.palette ?? BrandPalette.classic;
  }

  static BrandPalette read(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<BrandPaletteScope>();
    return scope?.palette ?? BrandPalette.classic;
  }

  @override
  bool updateShouldNotify(BrandPaletteScope oldWidget) =>
      oldWidget.palette.id != palette.id;
}

extension BrandPaletteX on BuildContext {
  BrandPalette get brand => BrandPaletteScope.of(this);
}

/// Updated whenever [ThemeCubit] changes so page token helpers can read live colors.
class BrandTokens {
  BrandTokens._();
  static BrandPalette current = BrandPalette.classic;
}
