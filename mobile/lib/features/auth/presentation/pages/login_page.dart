import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/language_switcher.dart';
import '../../../../core/router/route_names.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/utils/validators.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
// Warm minimal palette: cream whites, charcoal ink, terracotta accent

class _T {
  // Backgrounds
  static const bgPage   = Color(0xFFFAF9F7);   // warm off-white
  static const bgPanel  = Color(0xFFFFFFFF);   // pure white card
  static const bgInput  = Color(0xFFF4F3F1);   // warm light grey input

  // Brand / Accent — purple
  static const accent   = Color(0xFF7C3AED);   // purple primary
  static const accentLt = Color(0xFFA78BFA);   // lighter purple
  static const accentBg = Color(0xFFF3F0FF);   // tint for focus rings

  // Text
  static const ink      = Color(0xFF1A1714);   // near-black
  static const inkMid   = Color(0xFF5C5550);   // medium grey-brown
  static const inkSoft  = Color(0xFF9A9390);   // soft placeholder

  // Structure
  static const border   = Color(0xFFE8E5E1);   // warm border
  static const divider  = Color(0xFFEFECE8);   // subtle divider
  static const error    = Color(0xFFC0392B);   // clear red error

  // Gradient — subtle warm paper gradient for page bg
  static const Gradient pageBg = LinearGradient(
    begin: Alignment.topCenter,
    end:   Alignment.bottomCenter,
    colors: [Color(0xFFFBFAF8), Color(0xFFF1EFEA)],
  );

  // Shadow
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF1A1714).withValues(alpha: 0.06),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF1A1714).withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}

// ── Page ──────────────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading       = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
    );
    Future.microtask(() { if (mounted) _fadeCtrl.forward(); });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.lightImpact();
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      context.read<AuthBloc>().add(AuthLoginRequested(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isWebView = size.width > 900;
    
    // Responsive values
    final logoSize = isSmallScreen ? 42.0 : 56.0;
    final logoPadding = isSmallScreen ? 12.0 : 16.0;
    final titleFontSize = isSmallScreen ? 28.0 : 36.0;
    final subtitleFontSize = isSmallScreen ? 14.0 : 16.0;
    final descriptionFontSize = isSmallScreen ? 16.0 : 18.0;
    final horizontalPadding = isSmallScreen ? 24.0 : 40.0;
    final cardMaxWidth = isWebView ? 480.0 : double.infinity;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _T.bgPage,
        body: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            setState(() => _isLoading = state is AuthLoading);
            if (state is AuthAuthenticated) {
              context.go(RouteNames.dashboard);
            } else if (state is AuthUnauthenticated) {
              _showError(context, 'Invalid email or password.');
            } else if (state is AuthError) {
              _showError(context, state.message);
            } else if (state is AuthPhoneVerificationRequired) {
              _showError(context, 'Phone verification unavailable at this time.');
            }
          },
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Stack(
              children: [
                // Warm page gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(gradient: _T.pageBg),
                  ),
                ),

                // Subtle top accent bar
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 3,
                    color: _T.accent,
                  ),
                ),

                SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isWebView ? 1000 : double.infinity,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: isSmallScreen ? 16 : 24),

                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          context.go(RouteNames.home),
                                      icon: const Icon(Icons.arrow_back_rounded),
                                      color: _T.inkMid,
                                      tooltip: 'Back to home',
                                      style: IconButton.styleFrom(
                                        backgroundColor: _T.bgInput,
                                        padding: const EdgeInsets.all(10),
                                      ),
                                    ),
                                    const Spacer(),
                                    const LanguageChip(),
                                  ],
                                ),

                                SizedBox(height: isSmallScreen ? 24 : 40),

                              // Logo + Title
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(logoPadding),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: _T.border, width: 1.2),
                                      boxShadow: _T.cardShadow,
                                    ),
                                    child: Image.asset(
                                      'assets/images/logo/logo.png',
                                      width: logoSize,
                                      height: logoSize,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.point_of_sale_rounded,
                                        color: _T.accent,
                                        size: logoSize,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isSmallScreen ? 16 : 24),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tera VFD',
                                          style: TextStyle(
                                            fontSize: titleFontSize,
                                            fontWeight: FontWeight.w800,
                                            color: _T.ink,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        Text(
                                          context.t.appTagline,
                                          style: TextStyle(
                                            fontSize: subtitleFontSize,
                                            color: _T.inkMid,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: isSmallScreen ? 50 : 70),

                              // Description
                              const SizedBox(height: 8),
                              Text(
                                context.t.signInSubtitle,
                                style: TextStyle(
                                  fontSize: descriptionFontSize,
                                  color: _T.inkMid,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              SizedBox(height: isSmallScreen ? 40 : 60),

                                // Login Card - Centered on wide screens
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: cardMaxWidth,
                                    ),
                                  child: Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 30,
                                          offset: const Offset(0, 15),
                                        ),
                                      ],
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: _FieldLabel(context.t.emailAddress),
                                          ),   
                                          const SizedBox(height: 8),
                                          _InputField(
                                            controller: _emailController,
                                            hint: 'you@business.com',
                                            icon: Icons.alternate_email_rounded,
                                            keyboardType: TextInputType.emailAddress,
                                            validator: Validators.email,
                                            textInputAction: TextInputAction.next,
                                          ),

                                          SizedBox(height: isSmallScreen ? 20 : 28),

                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: _FieldLabel(context.t.password),
                                          ),
                                          const SizedBox(height: 8),
                                          _InputField(
                                            controller: _passwordController,
                                            hint: '••••••••',
                                            icon: Icons.lock_outline_rounded,
                                            obscureText: _obscurePassword,
                                            validator: Validators.password,
                                            textInputAction: TextInputAction.done,
                                            onFieldSubmitted: _submit,
                                            suffixIcon: _VisibilityToggle(
                                              obscure: _obscurePassword,
                                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                            ),
                                          ),

                                          SizedBox(height: isSmallScreen ? 10 : 12),

                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () {},
                                              child: Text(
                                                context.t.forgotPassword,
                                                style: const TextStyle(
                                                  color: Color(0xFF3B82F6),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),

                                          SizedBox(height: isSmallScreen ? 24 : 32),

                                          _SubmitButton(
                                            label: context.t.signIn,
                                            isLoading: _isLoading,
                                            onPressed: _submit,
                                          ),

                                          SizedBox(height: isSmallScreen ? 20 : 28),

                                          Text(
                                            'Contact your shop owner for account access.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.black45,
                                              fontSize: isSmallScreen ? 13 : 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: isSmallScreen ? 30 : 50),

                              Center(
                                child: Text(
                                  '© 2026 Tera POS',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: isSmallScreen ? 11 : 12,
                                  ),
                                ),
                              ),

                              SizedBox(height: isSmallScreen ? 20 : 32),
                              ],
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
        ),
      ),
    );
  }

  void _showError(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
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
        backgroundColor: _T.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _T.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/logo/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.point_of_sale_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _T.inkMid,
        ),
      );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String   hint;
  final IconData icon;
  final bool     obscureText;
  final String?  Function(String?)? validator;
  final TextInputType   keyboardType;
  final TextInputAction textInputAction;
  final VoidCallback?  onFieldSubmitted;
  final Widget?        suffixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.validator,
    this.keyboardType    = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted!() : null,
      style: TextStyle(fontSize: isSmallScreen ? 15 : 16, color: _T.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: _T.inkSoft, fontSize: isSmallScreen ? 14 : 15),
        prefixIcon: Icon(icon, color: _T.inkSoft),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _T.bgInput,
        contentPadding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 18, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _T.error, width: 1.8),
        ),
        errorStyle: GoogleFonts.dmSans(color: _T.error, fontSize: 12),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final bool       obscure;
  final VoidCallback onTap;
  const _VisibilityToggle({required this.obscure, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _T.inkSoft,
          size: 18,
        ),
      );
}

class _SubmitButton extends StatelessWidget {
  final String       label;
  final bool         isLoading;
  final VoidCallback onPressed;
  const _SubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: isSmallScreen ? 56 : 60,
        decoration: BoxDecoration(
          gradient: isLoading
              ? const LinearGradient(colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)])
              : const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 16 : 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                  ],
                ),
        ),
      ),
    );
  }
}