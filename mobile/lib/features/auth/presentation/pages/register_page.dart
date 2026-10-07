import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────

class _T {
  static const bgPage  = Color(0xFFFAF9F7);
  static const bgPanel = Color(0xFFFFFFFF);
  static const bgInput = Color(0xFFF4F3F1);
  static const accent  = Color(0xFF7C3AED);
  static const ink     = Color(0xFF1A1714);
  static const inkMid  = Color(0xFF5C5550);
  static const inkSoft = Color(0xFF9A9390);
  static const border  = Color(0xFFE8E5E1);
  static const divider = Color(0xFFEFECE8);
  static const error   = Color(0xFFC0392B);
  static const success = Color(0xFF2D8A60);

  static const Gradient pageBg = LinearGradient(
    begin: Alignment.topCenter,
    end:   Alignment.bottomCenter,
    colors: [Color(0xFFFDFBF9), Color(0xFFF5F3EF)],
  );

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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey             = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController  = TextEditingController();
  final _emailController     = TextEditingController();
  final _phoneController     = TextEditingController();
  final _passwordController  = TextEditingController();
  final _companyController   = TextEditingController();

  bool    _obscurePassword = true;
  String? _selectedRole;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    Future.microtask(() { if (mounted) _fadeCtrl.forward(); });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.lightImpact();
    if (_formKey.currentState!.validate()) {
      String? companyId;
      if (_selectedRole == 'Business Owner') {
        companyId = _companyController.text.trim().isEmpty
            ? 'default-company-id'
            : _companyController.text.trim();
      }
      context.read<AuthBloc>().add(AuthRegisterRequested(
        firstName: _firstNameController.text.trim(),
        lastName:  _lastNameController.text.trim(),
        email:     _emailController.text.trim(),
        phone:     _phoneController.text.trim(),
        password:  _passwordController.text,
        companyId: companyId,
        roleName:  _selectedRole,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _T.bgPage,
        body: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthPhoneVerificationRequired) {
              _showError(context, 'Phone verification unavailable at this time.');
              context.go(RouteNames.login);
            } else if (state is AuthError) {
              _showError(context, state.message);
            } else if (state is AuthAuthenticated) {
              context.go(RouteNames.dashboard);
            }
          },
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Stack(
              children: [
                Positioned.fill(
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: _T.pageBg),
                  ),
                ),

                // Top accent bar
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(height: 3, color: _T.accent),
                ),

                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top navigation ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _T.bgPanel,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _T.border, width: 1.2),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: _T.ink,
                                  size: 16,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Logo
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _T.accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/images/logo/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.point_of_sale_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'POS App',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _T.ink,
                                  ),
                                ),
                                Text(
                                  'New account',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: _T.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Heading ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create account',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: _T.ink,
                                height: 1.1,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Fill in your details to get started',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: _T.inkMid,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Scrollable form ───────────────────────────────
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: _T.bgPanel,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // ── Account type ─────────────────────
                                  _GroupLabel('Account type'),
                                  const SizedBox(height: 10),
                                  _Dropdown(
                                    value:     _selectedRole,
                                    hint:      'Select account type',
                                    items:     const ['Personal', 'Business Owner'],
                                    onChanged: (val) => setState(() => _selectedRole = val),
                                  ),

                                  // ── Business name (conditional) ───────
                                  if (_selectedRole == 'Business Owner') ...[
                                    const SizedBox(height: 24),
                                    _GroupLabel('Business details'),
                                    const SizedBox(height: 10),
                                    _InputField(
                                      controller: _companyController,
                                      hint:       'Business or company name',
                                      icon:       Icons.storefront_outlined,
                                      validator:  Validators.required,
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  // ── Personal details ──────────────────
                                  _GroupLabel('Personal details'),
                                  const SizedBox(height: 10),

                                  // Name row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _InputField(
                                          controller: _firstNameController,
                                          hint:       'First name',
                                          icon:       Icons.person_outline_rounded,
                                          validator:  Validators.required,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _InputField(
                                          controller: _lastNameController,
                                          hint:       'Last name',
                                          icon:       Icons.person_outline_rounded,
                                          validator:  Validators.required,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  _InputField(
                                    controller:  _emailController,
                                    hint:        'Email address',
                                    icon:        Icons.mail_outline_rounded,
                                    validator:   Validators.email,
                                    keyboardType: TextInputType.emailAddress,
                                  ),

                                  const SizedBox(height: 12),

                                  _InputField(
                                    controller:  _phoneController,
                                    hint:        'Phone number',
                                    icon:        Icons.phone_outlined,
                                    validator:   Validators.phone,
                                    keyboardType: TextInputType.phone,
                                  ),

                                  const SizedBox(height: 12),

                                  _InputField(
                                    controller:  _passwordController,
                                    hint:        'Create password',
                                    icon:        Icons.lock_outline_rounded,
                                    obscureText: _obscurePassword,
                                    validator:   Validators.password,
                                    onFieldSubmitted: _submit,
                                    suffixIcon: _VisibilityToggle(
                                      obscure: _obscurePassword,
                                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Password hint
                                  Text(
                                    'Minimum 8 characters, including at least one number',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11.5,
                                      color: _T.inkSoft,
                                    ),
                                  ),

                                  const SizedBox(height: 30),

                                  // ── Submit ────────────────────────────
                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (context, state) => _SubmitButton(
                                      label:     'Create Account',
                                      isLoading: state is AuthLoading,
                                      onPressed: _submit,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Already have account
                                  Center(
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          color: _T.inkMid,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Already have an account? '),
                                          WidgetSpan(
                                            child: GestureDetector(
                                              onTap: () => context.go('/login'),
                                              child: Text(
                                                'Sign in',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: _T.accent,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Terms
                                  Center(
                                    child: Text(
                                      'By continuing you agree to our Terms of Service\nand Privacy Policy.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11.5,
                                        color: _T.inkSoft,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _T.inkSoft,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _T.divider, thickness: 1)),
      ],
    );
  }
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
    this.onFieldSubmitted,
    this.suffixIcon,
  }) : textInputAction = TextInputAction.next;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:       controller,
      obscureText:      obscureText,
      validator:        validator,
      keyboardType:     keyboardType,
      textInputAction:  textInputAction,
      onFieldSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted!() : null,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        color: _T.ink,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.dmSans(color: _T.inkSoft, fontSize: 14.5),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: _T.inkSoft, size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
        filled:    true,
        fillColor: _T.bgInput,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
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

class _Dropdown extends StatelessWidget {
  final String?         value;
  final String          hint;
  final List<String>    items;
  final ValueChanged<String?> onChanged;
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: _T.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.dmSans(color: _T.inkSoft, fontSize: 14.5),
          ),
          icon: const Icon(Icons.expand_more_rounded, color: _T.inkSoft, size: 20),
          items: items.map((r) => DropdownMenuItem(
                value: r,
                child: Text(
                  r,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _T.ink,
                  ),
                ),
              )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
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
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _T.accent,
          disabledBackgroundColor: _T.border,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}