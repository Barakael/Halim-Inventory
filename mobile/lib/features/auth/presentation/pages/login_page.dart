import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/language_switcher.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/utils/validators.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AnimationController _fadeCtrl;
  late final AnimationController _bgCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    Future.microtask(() {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.lightImpact();
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      context.read<AuthBloc>().add(AuthLoginRequested(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.brand;
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final wide = size.width >= 720;
    final panelWidth = wide ? 420.0 : double.infinity;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: p.bg,
        resizeToAvoidBottomInset: true,
        body: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            setState(() => _isLoading = state is AuthLoading);
            if (state is AuthAuthenticated) {
              context.go(RouteNames.dashboard);
            } else if (state is AuthUnauthenticated) {
              _showError(context, 'Invalid username or password.');
            } else if (state is AuthError) {
              _showError(context, state.message);
            } else if (state is AuthPhoneVerificationRequired) {
              _showError(
                context,
                'Phone verification unavailable at this time.',
              );
            }
          },
          child: AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) {
              final t = _bgCtrl.value;
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + t * 0.3, -1),
                          end: Alignment(1 - t * 0.2, 1),
                          colors: [
                            Color.lerp(p.primary, p.bg, 0.88)!,
                            p.bg,
                            Color.lerp(p.accent, p.bg, 0.92)!,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Soft brand glow — grounds the page without floating chrome.
                  Positioned(
                    top: -80,
                    right: -60,
                    child: IgnorePointer(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.accent.withValues(alpha: 0.10 + t * 0.06),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    left: -40,
                    child: IgnorePointer(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.primary.withValues(alpha: 0.07 + (1 - t) * 0.04),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 32 : 20,
                        8,
                        wide ? 32 : 20,
                        12 + viewInsets.bottom,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: LanguageChip(),
                              ),
                              Expanded(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: panelWidth,
                                    ),
                                    child: Material(
                                      color: p.white,
                                      elevation: 0,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: p.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: p.border.withValues(
                                              alpha: 0.9,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: p.primary.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 28,
                                              offset: const Offset(0, 12),
                                            ),
                                          ],
                                        ),
                                        padding: EdgeInsets.fromLTRB(
                                          wide ? 32 : 22,
                                          wide ? 28 : 24,
                                          wide ? 32 : 22,
                                          wide ? 28 : 24,
                                        ),
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                'POS App',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w800,
                                                  color: p.ink,
                                                  letterSpacing: -0.5,
                                                  height: 1.15,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                context.t.signInSubtitle,
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 14,
                                                  height: 1.35,
                                                  color: p.inkMid,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const SizedBox(height: 28),
                                              _FieldLabel(
                                                context.t.username,
                                                p,
                                              ),
                                              const SizedBox(height: 8),
                                              _InputField(
                                                palette: p,
                                                controller:
                                                    _usernameController,
                                                hint: 'admin',
                                                icon: Icons
                                                    .person_outline_rounded,
                                                keyboardType:
                                                    TextInputType.text,
                                                validator:
                                                    Validators.username,
                                                textInputAction:
                                                    TextInputAction.next,
                                              ),
                                              const SizedBox(height: 18),
                                              _FieldLabel(
                                                context.t.password,
                                                p,
                                              ),
                                              const SizedBox(height: 8),
                                              _InputField(
                                                palette: p,
                                                controller:
                                                    _passwordController,
                                                hint: '••••••••',
                                                icon: Icons
                                                    .lock_outline_rounded,
                                                obscureText:
                                                    _obscurePassword,
                                                validator:
                                                    Validators.password,
                                                textInputAction:
                                                    TextInputAction.done,
                                                onFieldSubmitted: _submit,
                                                suffixIcon:
                                                    _VisibilityToggle(
                                                  palette: p,
                                                  obscure: _obscurePassword,
                                                  onTap: () => setState(
                                                    () =>
                                                        _obscurePassword =
                                                            !_obscurePassword,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: TextButton(
                                                  onPressed: () {},
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 4,
                                                      vertical: 4,
                                                    ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: Text(
                                                    context.t.forgotPassword,
                                                    style:
                                                        GoogleFonts.dmSans(
                                                      color: p.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              _SubmitButton(
                                                palette: p,
                                                label: context.t.signIn,
                                                isLoading: _isLoading,
                                                onPressed: _submit,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Contact your shop owner for account access.',
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.dmSans(
                                                  color: p.inkMid
                                                      .withValues(alpha: 0.8),
                                                  fontSize: 12.5,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '© 2026 POS App',
                                style: GoogleFonts.dmSans(
                                  color: p.inkMid.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext ctx, String msg) {
    final p = context.brand;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: p.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final BrandPalette palette;
  const _FieldLabel(this.text, this.palette);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.ink,
          letterSpacing: 0.1,
        ),
      );
}

class _InputField extends StatelessWidget {
  final BrandPalette palette;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final VoidCallback? onFieldSubmitted;
  final Widget? suffixIcon;

  const _InputField({
    required this.palette,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final radius = BorderRadius.circular(12);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted:
          onFieldSubmitted != null ? (_) => onFieldSubmitted!() : null,
      style: GoogleFonts.dmSans(
        fontSize: 15.5,
        color: p.ink,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          color: p.inkMid.withValues(alpha: 0.55),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: p.inkMid, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        // Muted fill so fields sit inside the white panel (not floating).
        fillColor: p.bg,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: p.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: p.danger, width: 1.6),
        ),
        errorStyle: GoogleFonts.dmSans(color: p.danger, fontSize: 12),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final BrandPalette palette;
  final bool obscure;
  final VoidCallback onTap;
  const _VisibilityToggle({
    required this.palette,
    required this.obscure,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: palette.inkMid,
          size: 20,
        ),
      );
}

class _SubmitButton extends StatelessWidget {
  final BrandPalette palette;
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _SubmitButton({
    required this.palette,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: p.cta,
          foregroundColor: p.ctaInk,
          disabledBackgroundColor: p.inkMid.withValues(alpha: 0.28),
          disabledForegroundColor: p.ctaInk.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: p.ctaInk,
                  strokeWidth: 2.4,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20, color: p.ctaInk),
                ],
              ),
      ),
    );
  }
}
