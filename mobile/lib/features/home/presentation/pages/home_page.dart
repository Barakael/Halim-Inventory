import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/services/pos_device_service.dart';

// ── White professional palette ────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFFF7F8FA);
  static const white = Color(0xFFFFFFFF);
  static const navy = Color(0xFF1E3A5F);
  static const navyMid = Color(0xFF2B527A);
  static const teal = Color(0xFF00C896);
  static const tealSoft = Color(0x1400C896);
  static const gold = Color(0xFFFFB020);
  static const ink = Color(0xFF1A2332);
  static const inkSoft = Color(0xFF64748B);
  static const line = Color(0xFFE8EDF5);
  static const mist = Color(0xFFF1F4F9);

  static TextStyle display(
    double size, {
    FontWeight w = FontWeight.w700,
    Color color = ink,
    double height = 1.2,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: w,
        color: color,
        height: height,
        letterSpacing: -0.35,
      );

  static TextStyle body(
    double size, {
    Color color = inkSoft,
    FontWeight w = FontWeight.w400,
  }) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: w,
        color: color,
        height: 1.5,
      );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> glow(Color c, double strength) => [
        BoxShadow(
          color: c.withValues(alpha: strength),
          blurRadius: 28,
          spreadRadius: 1,
          offset: const Offset(0, 10),
        ),
      ];
}

class _Assets {
  static const hero = 'assets/images/home/hero_pos.jpg';
  static const checkout = 'assets/images/home/card_checkout.jpg';
  static const inventory = 'assets/images/home/card_inventory.jpg';
  static const receipt = 'assets/images/home/card_receipt.jpg';
  static const logo = 'assets/images/logo/logo.png';
}

// ═════════════════════════════════════════════════════════════════════════════
// HOME
// ═════════════════════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _float;
  late final AnimationController _pulse;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  final _scroll = ScrollController();
  bool _showTop = false;
  double _heroParallax = 0;
  final _featuresKey = GlobalKey();

  bool get _isH10 => PosDeviceService.instance.isH10Series;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _enter.forward();
    _scroll.addListener(() {
      final v = _scroll.offset > 560;
      if (v != _showTop) setState(() => _showTop = v);
      final p = (_scroll.offset / 6).clamp(0.0, 24.0);
      if (p != _heroParallax) setState(() => _heroParallax = p);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _enter.dispose();
    _float.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _signIn() {
    HapticFeedback.mediumImpact();
    context.go(RouteNames.login);
  }

  void _toFeatures() {
    HapticFeedback.selectionClick();
    final ctx = _featuresKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
        alignment: 0.06,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: _HeroHeader(
                        topPad: top,
                        floatAnim: _float,
                        pulseAnim: _pulse,
                        parallax: _heroParallax,
                        isH10: _isH10,
                        onSignIn: _signIn,
                        onExplore: _toFeatures,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -28),
                    child: _FeatureCards(floatAnim: _float),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: _RevealOnScroll(
                      controller: _scroll,
                      child: const _StatsRow(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                    child: KeyedSubtree(
                      key: _featuresKey,
                      child: _RevealOnScroll(
                        controller: _scroll,
                        child: const _WhyCards(),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 44, 0, 0),
                    child: _RevealOnScroll(
                      controller: _scroll,
                      child: const _TestimonialCarousel(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
                    child: _RevealOnScroll(
                      controller: _scroll,
                      child: const _StepsCard(),
                    ),
                  ),
                ),
                if (_isH10)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      child: _RevealOnScroll(
                        controller: _scroll,
                        child: const _DeviceCard(),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: _RevealOnScroll(
                      controller: _scroll,
                      child: const _TrustCard(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: _RevealOnScroll(
                      controller: _scroll,
                      child: _CtaCard(onSignIn: _signIn, pulseAnim: _pulse),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 36, 20, bottom + 28),
                    child: _Footer(isH10: _isH10),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: bottom + 18,
              child: IgnorePointer(
                ignoring: !_showTop,
                child: AnimatedSlide(
                  offset: _showTop ? Offset.zero : const Offset(0, 0.6),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showTop ? 1 : 0,
                    child: _PressScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _scroll.animateTo(
                          0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Material(
                        color: _C.white,
                        elevation: 2,
                        shadowColor: _C.navy.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: _C.navy,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS — press feedback, shimmer, reveal, stagger, counters
// ═════════════════════════════════════════════════════════════════════════════

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.onTap}) : scale = 0.96;

  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Shimmering placeholder while a local asset decodes onto the first frame.
class _ShimmerImage extends StatefulWidget {
  const _ShimmerImage(this.path) : fit = BoxFit.cover;

  final String path;
  final BoxFit fit;

  @override
  State<_ShimmerImage> createState() => _ShimmerImageState();
}

class _ShimmerImageState extends State<_ShimmerImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      widget.path,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => Container(
        color: _C.mist,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: _C.inkSoft, size: 28),
      ),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) => ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-1 + _shimmerCtrl.value * 3, 0),
              end: Alignment(0 + _shimmerCtrl.value * 3, 0),
              colors: const [_C.mist, _C.line, _C.mist],
            ).createShader(rect),
            child: Container(color: _C.mist),
          ),
        );
      },
    );
  }
}

/// Reveal-on-scroll: fades, slides, and gently scales a child into view once
/// it enters the viewport.
class _RevealOnScroll extends StatefulWidget {
  const _RevealOnScroll({
    required this.child,
    required this.controller,
    this.delay = Duration.zero,
  });

  final Widget child;
  final ScrollController controller;
  final Duration delay;

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll> {
  final _key = GlobalKey();
  bool _triggered = false;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_triggered || !mounted) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    if (box.localToGlobal(Offset.zero).dy <
        MediaQuery.sizeOf(context).height - 40) {
      _triggered = true;
      widget.controller.removeListener(_check);
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _shown ? Offset.zero : const Offset(0, 0.05),
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: _shown ? 1 : 0.97,
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Convenience: staggers a list of children under one reveal trigger.
class _Stagger extends StatelessWidget {
  const _Stagger({
    required this.controller,
    required this.children,
    this.spacing = 12,
    this.step = const Duration(milliseconds: 90),
  });

  final ScrollController controller;
  final List<Widget> children;
  final double spacing;
  final Duration step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          _RevealOnScroll(
            controller: controller,
            delay: step * i,
            child: children[i],
          ),
        ],
      ],
    );
  }
}

/// Counts up from 0 to [value] once visible.
class _CountUp extends StatefulWidget {
  const _CountUp({
    required this.value,
    required this.controller,
    this.suffix = '',
    this.style,
    this.decimals = 0,
  });

  final double value;
  final String suffix;
  final ScrollController controller;
  final TextStyle? style;
  final int decimals;

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp> {
  final _key = GlobalKey();
  bool _triggered = false;
  double _current = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_triggered || !mounted) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    if (box.localToGlobal(Offset.zero).dy <
        MediaQuery.sizeOf(context).height - 40) {
      _triggered = true;
      widget.controller.removeListener(_check);
      setState(() => _current = widget.value);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _current),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, v, __) => Text(
          '${v.toStringAsFixed(widget.decimals)}${widget.suffix}',
          style: widget.style,
        ),
      ),
    );
  }
}

// ── Shared white card shell ───────────────────────────────────────────────────

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  }) : radius = 18;

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _C.line),
        boxShadow: _C.cardShadow,
      ),
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HERO
// ═════════════════════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.topPad,
    required this.floatAnim,
    required this.pulseAnim,
    required this.parallax,
    required this.isH10,
    required this.onSignIn,
    required this.onExplore,
  });

  final double topPad;
  final Animation<double> floatAnim;
  final Animation<double> pulseAnim;
  final double parallax;
  final bool isH10;
  final VoidCallback onSignIn;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 48),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft floating brand blobs for depth
          AnimatedBuilder(
            animation: floatAnim,
            builder: (_, __) => Positioned(
              top: -30 + floatAnim.value * 14,
              right: -50,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.teal.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: floatAnim,
            builder: (_, __) => Positioned(
              top: 220 - floatAnim.value * 10,
              left: -60,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.navy.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      _Assets.logo,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _C.mist,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.point_of_sale_rounded,
                          color: _C.navy,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tera POS',
                    style: _C.display(18, w: FontWeight.w800, color: _C.navy),
                  ),
                  const Spacer(),
                  _PressScale(
                    onTap: onSignIn,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _C.mist,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Sign in',
                        style: _C.body(13, color: _C.navy, w: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              // Animated trust badge
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Opacity(
                  opacity: 0.85 + pulseAnim.value * 0.15,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _C.tealSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _C.teal.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: _C.gold, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        '4.9/5 · 2,000+ shops onboard',
                        style: _C.body(11.5, color: _C.teal, w: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Tera POS',
                style: _C.display(34, w: FontWeight.w800, color: _C.navy),
              ),
              const SizedBox(height: 10),
              Text(
                'Professional point of sale for Tanzanian shops.',
                style: _C.display(18, w: FontWeight.w600, color: _C.navyMid),
              ),
              const SizedBox(height: 10),
              Text(
                'Simple receipts, live inventory, and fast checkout — on phone, tablet, or H10S.',
                style: _C.body(15),
              ),
              const SizedBox(height: 22),

              // Hero image — Ken Burns drift + parallax on scroll
              AnimatedBuilder(
                animation: floatAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, floatAnim.value * 4 - 2 - parallax),
                  child: child,
                ),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _C.line),
                    boxShadow: _C.cardShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _KenBurnsImage(_Assets.hero, floatAnim: floatAnim),
                ),
              ),

              const SizedBox(height: 22),
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _C.glow(_C.navy, 0.10 + pulseAnim.value * 0.08),
                  ),
                  child: child,
                ),
                child: _PressScale(
                  onTap: onSignIn,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.navy,
                        foregroundColor: _C.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Open your shop',
                        style: _C.display(15, w: FontWeight.w700, color: _C.white),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _PressScale(
                onTap: onExplore,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onExplore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.navy,
                      side: const BorderSide(color: _C.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Explore features',
                      style: _C.body(14, color: _C.navy, w: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              if (isH10) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    _PulsingDot(pulseAnim: pulseAnim),
                    const SizedBox(width: 8),
                    Text(
                      'H10S ready — scanner & printer connected',
                      style: _C.body(12, color: _C.teal, w: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.pulseAnim});

  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _C.teal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _C.teal.withValues(alpha: 0.5 * pulseAnim.value),
              blurRadius: 6 + pulseAnim.value * 4,
              spreadRadius: pulseAnim.value * 1.5,
            ),
          ],
        ),
      ),
    );
  }
}

/// Slow continuous scale + pan on a static image for a subtle "alive" hero.
class _KenBurnsImage extends StatelessWidget {
  const _KenBurnsImage(this.path, {required this.floatAnim});

  final String path;
  final Animation<double> floatAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatAnim,
      builder: (_, child) {
        final scale = 1.06 + floatAnim.value * 0.03;
        final dx = (floatAnim.value - 0.5) * 6;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: _ShimmerImage(path),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FLOATING FEATURE IMAGE CARDS
// ═════════════════════════════════════════════════════════════════════════════

class _FeatureCards extends StatefulWidget {
  const _FeatureCards({required this.floatAnim});

  final Animation<double> floatAnim;

  @override
  State<_FeatureCards> createState() => _FeatureCardsState();
}

class _FeatureCardsState extends State<_FeatureCards> {
  final _pageCtrl = PageController(viewportFraction: 0.42);
  double _page = 0;

  static const _items = [
    (_Assets.checkout, 'Checkout', 'Fast till flow'),
    (_Assets.inventory, 'Inventory', 'Live stock levels'),
    (_Assets.receipt, 'Receipts', 'Clean thermal prints'),
    (_Assets.hero, 'Any device', 'Phone to H10S'),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl.addListener(() {
      setState(() => _page = _pageCtrl.page ?? 0);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 208,
          child: AnimatedBuilder(
            animation: widget.floatAnim,
            builder: (_, __) {
              final t = widget.floatAnim.value;
              return PageView.builder(
                controller: _pageCtrl,
                padEnds: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final dist = (_page - i).abs().clamp(0.0, 1.0);
                  final scale = 1 - dist * 0.12;
                  final dy = ((t + i * 0.2) % 1.0) * 8 - 4;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: 1 - dist * 0.35,
                          child: _ImageFeatureCard(
                            image: item.$1,
                            title: item.$2,
                            subtitle: item.$3,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: (_page.round() == i) ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: (_page.round() == i) ? _C.navy : _C.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ImageFeatureCard extends StatelessWidget {
  const _ImageFeatureCard({
    required this.image,
    required this.title,
    required this.subtitle,
  });

  final String image;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
        boxShadow: _C.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _ShimmerImage(image)),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _C.display(13, w: FontWeight.w700, color: _C.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: _C.body(11, w: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STATS ROW — count-up numbers, social proof
// ═════════════════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final controller = Scrollable.of(context).widget.controller;
    return _WhiteCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Row(
        children: [
          _StatItem(
            value: 2000,
            suffix: '+',
            label: 'Active shops',
            controller: controller,
          ),
          _divider(),
          _StatItem(
            value: 500,
            suffix: 'K+',
            label: 'Receipts printed',
            controller: controller,
          ),
          _divider(),
          _StatItem(
            value: 4.9,
            decimals: 1,
            suffix: '★',
            label: 'Average rating',
            controller: controller,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: _C.line);
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.suffix,
    required this.controller,
    this.decimals = 0,
  });

  final double value;
  final String label;
  final String suffix;
  final int decimals;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? ScrollController();
    return Expanded(
      child: Column(
        children: [
          _CountUp(
            value: value,
            suffix: suffix,
            decimals: decimals,
            controller: ctrl,
            style: _C.display(18, w: FontWeight.w800, color: _C.teal),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: _C.body(10.5, w: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WHY / CAPABILITY CARDS — staggered reveal with icon pop
// ═════════════════════════════════════════════════════════════════════════════

class _WhyCards extends StatelessWidget {
  const _WhyCards();

  static const _rows = [
    (
      Icons.bolt_rounded,
      'Checkout that keeps queues short',
      'Tap, search, or scan — cash and mobile money in one sale.',
    ),
    (
      Icons.inventory_2_outlined,
      'Stock you can trust',
      'Live levels, low-stock alerts, and barcodes that stick.',
    ),
    (
      Icons.receipt_long_outlined,
      'Receipts customers can keep',
      'Clean thermal prints from H10S or Bluetooth.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scrollCtrl = Scrollable.of(context).widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Built for the counter',
          style: _C.display(24, w: FontWeight.w800, color: _C.navy),
        ),
        const SizedBox(height: 8),
        Text(
          'Everything between the first scan and the last receipt.',
          style: _C.body(14),
        ),
        const SizedBox(height: 18),
        if (scrollCtrl != null)
          _Stagger(
            controller: scrollCtrl,
            children: [
              for (var i = 0; i < _rows.length; i++)
                _WhyRow(
                  icon: _rows[i].$1,
                  title: _rows[i].$2,
                  body: _rows[i].$3,
                  accent: i == 0,
                ),
            ],
          )
        else
          Column(
            children: [
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _WhyRow(
                  icon: _rows[i].$1,
                  title: _rows[i].$2,
                  body: _rows[i].$3,
                  accent: i == 0,
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _WhyRow extends StatefulWidget {
  const _WhyRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool accent;

  @override
  State<_WhyRow> createState() => _WhyRowState();
}

class _WhyRowState extends State<_WhyRow> with SingleTickerProviderStateMixin {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        child: _WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(
                  scale: v,
                  child: child,
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.accent ? _C.tealSoft : _C.mist,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.accent ? _C.teal : _C.navy,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: _C.display(15, w: FontWeight.w700, color: _C.navy),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.body, style: _C.body(13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TESTIMONIALS — auto-advancing carousel
// ═════════════════════════════════════════════════════════════════════════════

class _TestimonialCarousel extends StatefulWidget {
  const _TestimonialCarousel();

  @override
  State<_TestimonialCarousel> createState() => _TestimonialCarouselState();
}

class _TestimonialCarouselState extends State<_TestimonialCarousel> {
  final _pageCtrl = PageController(viewportFraction: 0.86);
  int _page = 0;

  static const _quotes = [
    (
      'Neema M.',
      'Mini-mart owner, Dar es Salaam',
      'Checkout lines got so much shorter. My cashiers scan and print without thinking twice.',
    ),
    (
      'Juma A.',
      'Hardware shop, Mwanza',
      'I finally know what\'s actually on my shelves. Low-stock alerts have saved me twice this month.',
    ),
    (
      'Fatma S.',
      'Boutique owner, Arusha',
      'Switched from paper receipts to Tera in an afternoon. Customers trust the printed slip now.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl.addListener(() {
      final p = _pageCtrl.page?.round() ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Loved by shop owners across Tanzania',
            style: _C.display(20, w: FontWeight.w800, color: _C.navy),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 176,
          child: PageView.builder(
            controller: _pageCtrl,
            physics: const BouncingScrollPhysics(),
            itemCount: _quotes.length,
            itemBuilder: (context, i) {
              final q = _quotes[i];
              return AnimatedBuilder(
                animation: _pageCtrl,
                builder: (context, child) {
                  double dist = 0;
                  try {
                    dist = ((_pageCtrl.page ?? _page.toDouble()) - i).abs();
                  } catch (_) {}
                  final scale = (1 - dist * 0.06).clamp(0.9, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _C.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _C.line),
                    boxShadow: _C.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (_) => const Icon(Icons.star_rounded,
                              color: _C.gold, size: 15),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          '"${q.$3}"',
                          style: _C.body(13.5, color: _C.ink, w: FontWeight.w500),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q.$1,
                        style: _C.display(13, w: FontWeight.w700, color: _C.navy),
                      ),
                      Text(q.$2, style: _C.body(11, color: _C.inkSoft)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _quotes.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? _C.navy : _C.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STEPS CARD — animated growing connector line
// ═════════════════════════════════════════════════════════════════════════════

class _StepsCard extends StatelessWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('01', 'Sign in', 'Use the staff account from your shop owner.'),
      ('02', 'Ring sales', 'Add items by tap, search, or hardware scan.'),
      ('03', 'Hand a receipt', 'Print on device or share a clean PDF.'),
    ];

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Up and selling in minutes',
            style: _C.display(20, w: FontWeight.w800, color: _C.navy),
          ),
          const SizedBox(height: 6),
          Text(
            'No complicated setup — open the app and go to work.',
            style: _C.body(13),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) ...[
              Padding(
                padding: const EdgeInsets.only(left: 15, top: 2, bottom: 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 400 + i * 200),
                  curve: Curves.easeOut,
                  builder: (context, v, __) => Container(
                    width: 2,
                    height: 14 * v,
                    color: _C.teal.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 350 + i * 150),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset((1 - v.clamp(0, 1)) * 14, 0),
                  child: child,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      steps[i].$1,
                      style: _C.display(13, w: FontWeight.w800, color: _C.teal),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$2,
                          style: _C.display(14,
                              w: FontWeight.w700, color: _C.navy),
                        ),
                        const SizedBox(height: 2),
                        Text(steps[i].$3, style: _C.body(13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DEVICE / TRUST / CTA CARDS
// ═════════════════════════════════════════════════════════════════════════════

class _DeviceCard extends StatefulWidget {
  const _DeviceCard();

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen;

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _sheen,
              builder: (context, __) => ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(-1 + _sheen.value * 3, -1),
                  end: Alignment(0 + _sheen.value * 3, 1),
                  colors: const [_C.mist, _C.white, _C.mist],
                ).createShader(rect),
                blendMode: BlendMode.srcATop,
                child: Container(
                  width: 48,
                  height: 48,
                  color: _C.mist,
                  child: const Icon(Icons.hardware_rounded,
                      color: _C.navy, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your H10S is ready',
                  style: _C.display(15, w: FontWeight.w700, color: _C.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  'Built-in scanner and thermal printer work out of the box.',
                  style: _C.body(13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard();

  static const _checks = [
    'Printed shop receipts',
    'Encrypted cloud backup',
    'Role-based staff access',
  ];

  @override
  Widget build(BuildContext context) {
    final scrollCtrl = Scrollable.of(context).widget.controller;
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.tealSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: _C.teal,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Built for everyday shop work',
            style: _C.display(18, w: FontWeight.w800, color: _C.navy),
          ),
          const SizedBox(height: 8),
          Text(
            'Secure roles, cloud sync, and simple receipts — so every sale is accountable.',
            style: _C.body(14),
          ),
          const SizedBox(height: 16),
          if (scrollCtrl != null)
            _Stagger(
              controller: scrollCtrl,
              spacing: 8,
              step: const Duration(milliseconds: 100),
              children: [
                for (final c in _checks) _CheckLine(label: c),
              ],
            )
          else
            Column(
              children: [
                for (final c in _checks) _CheckLine(label: c),
              ],
            ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: _C.tealSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: _C.teal, size: 13),
        ),
        const SizedBox(width: 10),
        Text(label, style: _C.body(13, color: _C.ink, w: FontWeight.w500)),
      ],
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({required this.onSignIn, required this.pulseAnim});

  final VoidCallback onSignIn;
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: _C.glow(_C.teal, 0.06 + pulseAnim.value * 0.06),
        ),
        child: child,
      ),
      child: _WhiteCard(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _C.tealSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'FREE SETUP THIS WEEK',
                style: _C.body(10.5, color: _C.teal, w: FontWeight.w800)
                    .copyWith(letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ready for today\'s first sale?',
              style: _C.display(22, w: FontWeight.w800, color: _C.navy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in and open the register in seconds.',
              style: _C.body(14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            _PressScale(
              onTap: onSignIn,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.navy,
                    foregroundColor: _C.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Sign in to sell',
                    style: _C.display(15, w: FontWeight.w700, color: _C.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.isH10});

  final bool isH10;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isH10
              ? 'Running on ${PosDeviceService.instance.info.displayName}'
              : 'Phones · tablets · H10S terminals',
          style: _C.body(13, w: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Trusted in Dar es Salaam · Mwanza · Arusha · Dodoma',
          style: _C.body(11.5, color: _C.inkSoft.withValues(alpha: 0.85)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          '© 2026 Tera POS',
          style: _C.body(12, color: _C.inkSoft.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}