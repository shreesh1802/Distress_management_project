import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/auth_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/Login/LoginPage.tsx
/// and LoginPage.css. Layout breakpoints (1024, 640) mirror the CSS media queries.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _showPassword = false;
  bool _isLoading = false;
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    final remembered = ref.read(authProvider).rememberedEmail;
    if (remembered != null) {
      _emailController.text = remembered;
      _rememberMe = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final newErrors = <String>[];

    if (email.isEmpty && password.isEmpty) {
      newErrors.add('Please enter both email address and password.');
    } else {
      if (email.isEmpty) newErrors.add('Email address is required.');
      if (password.isEmpty) newErrors.add('Password is required.');
    }

    final emailPattern = RegExp(r'^\S+@\S+\.\S+$');
    if (email.isNotEmpty && !emailPattern.hasMatch(email)) {
      newErrors.add(
        'Please enter a valid email address (e.g., user@example.com).',
      );
    }

    if (newErrors.isNotEmpty) {
      setState(() => _errors = newErrors);
      return;
    }

    setState(() {
      _errors = [];
      _isLoading = true;
    });

    // Mirrors the simulated 1-second initialization experience in LoginPage.tsx.
    await Future.delayed(const Duration(seconds: 1));

    final success = await ref
        .read(authProvider.notifier)
        .login(email: email, password: password, rememberMe: _rememberMe);

    if (!mounted) return;

    if (success) {
      setState(() => _isLoading = false);
      context.go(AppRoutes.survey);
    } else {
      setState(() {
        _isLoading = false;
        _errors = [
          'Invalid credentials. Please verify your email and password.',
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/highway_background.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.loginOverlayStart,
                      AppColors.loginOverlayEnd,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 1024;
                          final hideLeft = constraints.maxWidth < 640;

                          final rightCard = Center(
                            child: _GlassLoginCard(
                              emailController: _emailController,
                              passwordController: _passwordController,
                              rememberMe: _rememberMe,
                              showPassword: _showPassword,
                              errors: _errors,
                              isLoading: _isLoading,
                              onRememberMeChanged: (v) =>
                                  setState(() => _rememberMe = v),
                              onTogglePassword: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              onForgotPassword: () => setState(() {
                                _errors = [
                                  'Password reset is restricted. Contact network administrator for security keys.',
                                ];
                              }),
                              onSubmit: _handleSubmit,
                            ),
                          );

                          if (isNarrow) {
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (!hideLeft) ...[
                                    const _LoginLeftSection(centered: true),
                                    const SizedBox(height: 40),
                                  ],
                                  rightCard,
                                ],
                              ),
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                flex: 11,
                                child: _LoginLeftSection(centered: false),
                              ),
                              const SizedBox(width: 60),
                              Expanded(flex: 9, child: rightCard),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading) const _LoadingOverlay(),
          ],
        ),
      ),
    );
  }
}

class _LoginLeftSection extends StatelessWidget {
  const _LoginLeftSection({required this.centered});

  final bool centered;

  static const _features = [
    (
      icon: LucideIcons.map,
      title: 'Live GIS Monitoring',
      desc: 'Geospatial logging and location-tagged vehicle feeds.',
    ),
    (
      icon: LucideIcons.wrench,
      title: 'AI Maintenance Recommendations',
      desc: 'Automated maintenance job priorities and budgets.',
    ),
    (
      icon: LucideIcons.fileText,
      title: 'Automated PDF & Excel Reports',
      desc: 'Downloadable structured inspection summaries.',
    ),
    (
      icon: LucideIcons.barChart3,
      title: 'Road Health Analytics',
      desc: 'Aggregated severity distribution indexes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final crossAlign = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        _BrandTag(),
        const SizedBox(height: 16),
        Text(
          'Road Inspection Control Center',
          textAlign: textAlign,
          style: AppTextStyles.loginMainTitle,
        ),
        const SizedBox(height: 8),
        Text(
          'AUTHORIZED PERSONNEL ACCESS ONLY',
          textAlign: textAlign,
          style: AppTextStyles.loginSubtitle,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Text(
            'AI-Powered Road Distress Detection, GIS Mapping and Intelligent '
            'Maintenance Platform for Highway Infrastructure Monitoring. Developed to '
            'Ensure Safety, Track Performance, and Automate Asset Lifecycles.',
            textAlign: textAlign,
            style: AppTextStyles.loginDescription,
          ),
        ),
        const SizedBox(height: 32),
        const _RoadDivider(),
        const SizedBox(height: 26),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            for (final f in _features)
              _FeatureCard(icon: f.icon, title: f.title, desc: f.desc),
          ],
        ),
      ],
    );
  }
}

class _BrandTag extends StatelessWidget {
  const _BrandTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text('INFRASTRUCTURE PORTAL', style: AppTextStyles.loginBrandTag),
        ],
      ),
    );
  }
}

class _RoadDivider extends StatelessWidget {
  const _RoadDivider();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Container(
        width: double.infinity,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(size: Size.infinite, painter: _DashedLinePainter()),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 2;
    const dashWidth = 20.0;
    const gapWidth = 15.0;
    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentBlueHover.withValues(alpha: 0.3),
              border: Border.all(
                color: AppColors.accentBlueHover.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.warning),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.loginFeatureTitle),
                const SizedBox(height: 2),
                Text(desc, style: AppTextStyles.loginFeatureDesc),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassLoginCard extends StatelessWidget {
  const _GlassLoginCard({
    required this.emailController,
    required this.passwordController,
    required this.rememberMe,
    required this.showPassword,
    required this.errors,
    required this.isLoading,
    required this.onRememberMeChanged,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final bool showPassword;
  final List<String> errors;
  final bool isLoading;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.glassCardFill,
              border: Border.all(color: AppColors.glassCardBorder),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 35,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CardHeader(),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _ErrorBox(errors: errors),
                ],
                const SizedBox(height: 24),
                _LoginField(
                  label: 'Email Address',
                  controller: emailController,
                  icon: LucideIcons.mail,
                  hint: 'name@domain.com',
                  enabled: !isLoading,
                ),
                const SizedBox(height: 20),
                _LoginField(
                  label: 'Password',
                  controller: passwordController,
                  icon: LucideIcons.lock,
                  hint: '••••••••',
                  obscureText: !showPassword,
                  enabled: !isLoading,
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 16,
                      color: const Color(0xFFA0AEC0),
                    ),
                    onPressed: isLoading ? null : onTogglePassword,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 8,
                    children: [
                      GestureDetector(
                        onTap: isLoading
                            ? null
                            : () => onRememberMeChanged(!rememberMe),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: rememberMe
                                    ? AppColors.warning
                                    : const Color(0x590F172A),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: rememberMe
                                      ? AppColors.warning
                                      : Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: rememberMe
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Remember Me',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading ? null : onForgotPassword,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accentBlueHover,
                          AppColors.accentBlue,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: isLoading ? null : onSubmit,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              'Secure Login',
                              style: AppTextStyles.loginButtonLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Road Distress Management System • Version 1.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'POWERED BY THAPAR × AKCM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE2E8F0),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accentBlueHover, AppColors.accentBlue],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentBlueHover.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.shieldCheck,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Administrator Access', style: AppTextStyles.loginCardTitle),
        const SizedBox(height: 6),
        const Text(
          'Please sign in to continue.',
          style: AppTextStyles.loginCardSubtitle,
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.alertTriangle,
              size: 18,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Access Denied:',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFCA5A5),
                  ),
                ),
                if (errors.length == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      errors.first,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFFFCA5A5),
                        height: 1.4,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in errors)
                          Text(
                            '• $e',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFFFCA5A5),
                              height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.loginLabel),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          enabled: enabled,
          style: AppTextStyles.loginInputText,
          cursorColor: AppColors.warning,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 16,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0x590F172A),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.warning),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: const Color(0xF5081930),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.warning,
                    backgroundColor: Color(0x1AFFFFFF),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Initializing Road Inspection Control Center...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
