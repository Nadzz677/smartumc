import 'package:flutter/material.dart';

import '../../core/authentication/auth_service.dart';

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
      if (_mode == _LoginMode.student) {
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
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Unable to sign in with those credentials.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentMode = _mode == _LoginMode.student;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('SmartUMC', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('Sign in to continue'),
                      const SizedBox(height: 20),
                      SegmentedButton<_LoginMode>(
                        segments: const [
                          ButtonSegment(value: _LoginMode.student, label: Text('Student')),
                          ButtonSegment(value: _LoginMode.staff, label: Text('Lecturer / Super Admin')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: _busy
                            ? null
                            : (selection) => setState(() {
                                  _mode = selection.first;
                                  _identityController.clear();
                                  _error = null;
                                }),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _identityController,
                        keyboardType: studentMode ? TextInputType.text : TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: studentMode ? 'Matric number' : 'Staff email',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return studentMode ? 'Enter your matric number.' : 'Enter your staff email.';
                          }
                          if (!studentMode && (!value.contains('@') || value.contains(' '))) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Enter your password.' : null,
                      ),
                      if (widget.message != null || _error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error ?? widget.message!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'For demonstration accounts only. Student password recovery is not available.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
