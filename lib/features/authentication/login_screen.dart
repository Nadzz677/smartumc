import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/authentication/auth_service.dart';
import '../../core/authentication/matric_identity.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radii.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/widgets/app_card.dart';
import '../../core/design_system/widgets/app_text_field.dart';
import '../../core/design_system/widgets/login_background.dart';

enum _LoginMode { student, staff }

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.authService, this.message, super.key});

  final AuthService authService;
  final String? message;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  _LoginMode _mode = _LoginMode.student;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  bool get _isStudent => _mode == _LoginMode.student;

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isStudent) {
        await widget.authService.loginStudent(
          matricNumber: _identityController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.authService.loginStaff(
          email: _identityController.text,
          password: _passwordController.text,
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to sign in with those credentials.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateIdentity(String? value) {
    if (_isStudent) {
      try {
        MatricIdentity.normalize(value ?? '');
      } on FormatException {
        return 'Enter a valid matric number.';
      }
      return null;
    }

    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your staff email.';
    if (!email.contains('@') || email.contains(' ')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  void _switchMode() {
    if (_busy) return;
    setState(() {
      _mode = _isStudent ? _LoginMode.staff : _LoginMode.student;
      _identityController.clear();
      _passwordController.clear();
      _error = null;
      _obscurePassword = true;
    });
    _formKey.currentState?.reset();
  }

  void _showRecoveryUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Password recovery is not available yet. Contact UMC Support.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoginBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topInset = MediaQuery.paddingOf(context).top;
              final headerTop = (67 - topInset).clamp(24.0, 67.0);
              final contentWidth = math.min(constraints.maxWidth, 440.0);

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: headerTop),
                          Center(
                            child: Image.asset(
                              'assets/design/login/crest.png',
                              width: 105,
                              height: 105,
                              fit: BoxFit.cover,
                              semanticLabel: 'SmartUMC crest',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'SmartUMC',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: const Color(0xFF163653),
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  height: 1.18,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Your campus, connected.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppColors.brandCyan,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          _loginCard(context),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _loginCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      color: AppColors.white.withValues(alpha: 0.48),
      borderRadius: AppRadii.card,
      blurSigma: 12,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isStudent ? 'Welcome Back' : 'Staff Sign In',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _isStudent
                    ? 'Log in to access your student portal.'
                    : 'Log in to access your lecturer dashboard.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: _isStudent ? 'Matric Number' : 'Staff Email',
                hint: _isStudent
                    ? 'Enter your matric number'
                    : 'Enter your staff email',
                controller: _identityController,
                leadingAsset: 'assets/design/login/user_icon.svg',
                keyboardType: _isStudent
                    ? TextInputType.text
                    : TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: _isStudent
                    ? const [AutofillHints.username]
                    : const [AutofillHints.email],
                validator: _validateIdentity,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                leadingAsset: 'assets/design/login/lock_icon.svg',
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                trailing: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() {
                    _obscurePassword = !_obscurePassword;
                  }),
                  icon: _obscurePassword
                      ? SvgPicture.asset(
                          'assets/design/login/eye_off.svg',
                          width: 20,
                          height: 44,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        )
                      : const Icon(Icons.visibility_outlined),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showRecoveryUnavailable,
                  child: const Text('Forgot Password?'),
                ),
              ),
              if (widget.message != null || _error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _errorMessage(context, _error ?? widget.message!),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Log In'),
                            const SizedBox(width: AppSpacing.xs),
                            SvgPicture.asset(
                              'assets/design/login/login_arrow.svg',
                              width: 19,
                              height: 19,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.body,
                    fontSize: 12,
                  ),
                  children: const [
                    TextSpan(text: 'Need help? Contact '),
                    TextSpan(
                      text: 'UMC Support',
                      style: TextStyle(
                        color: AppColors.actionBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                '05-7732 311 | 05-7732 601',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.body, fontSize: 11),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _switchMode,
                child: Text(
                  _isStudent ? 'Lecturer / staff sign-in' : 'Student sign-in',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorMessage(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}
