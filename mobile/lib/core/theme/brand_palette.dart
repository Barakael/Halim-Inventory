import 'package:flutter/material.dart';

/// Brand color tokens for a selectable light theme preset.
class BrandPalette {
  const BrandPalette({
    required this.id,
    required this.primary,
    required this.primaryLt,
    required this.accent,
    required this.accentSoft,
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
  final Color bg;
  final Color white;
  final Color ink;
  final Color inkMid;
  final Color border;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color warn;

  static const classic = BrandPalette(
    id: 'classic',
    primary: Color(0xFF1E3A5F),
    primaryLt: Color(0xFF2B527A),
    accent: Color(0xFF00C896),
    accentSoft: Color(0x1A00C896),
    bg: Color(0xFFF5F6FA),
    white: Color(0xFFFFFFFF),
    ink: Color(0xFF1A2332),
    inkMid: Color(0xFF64748B),
    border: Color(0xFFE8EDF5),
    danger: Color(0xFFFF4D4D),
    dangerSoft: Color(0x1AFF4D4D),
    info: Color(0xFF3B82F6),
    warn: Color(0xFFFFA726),
  );

  static const warm = BrandPalette(
    id: 'warm',
    primary: Color(0xFF2C3E50),
    primaryLt: Color(0xFF3D5166),
    accent: Color(0xFFE8A838),
    accentSoft: Color(0x1AE8A838),
    bg: Color(0xFFF6F4F1),
    white: Color(0xFFFFFFFF),
    ink: Color(0xFF1F2933),
    inkMid: Color(0xFF6B7280),
    border: Color(0xFFE8E4DE),
    danger: Color(0xFFE05A4F),
    dangerSoft: Color(0x1AE05A4F),
    info: Color(0xFF4A7C9B),
    warn: Color(0xFFD4922A),
  );

  static const grove = BrandPalette(
    id: 'grove',
    primary: Color(0xFF2F4A3C),
    primaryLt: Color(0xFF3D5F4E),
    accent: Color(0xFF3D9B7A),
    accentSoft: Color(0x1A3D9B7A),
    bg: Color(0xFFF4F6F3),
    white: Color(0xFFFFFFFF),
    ink: Color(0xFF1C2B24),
    inkMid: Color(0xFF5F7168),
    border: Color(0xFFDDE5E0),
    danger: Color(0xFFD45B4A),
    dangerSoft: Color(0x1AD45B4A),
    info: Color(0xFF3B7A8C),
    warn: Color(0xFFC9A227),
  );

  static const all = <BrandPalette>[classic, warm, grove];

  static BrandPalette byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
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
