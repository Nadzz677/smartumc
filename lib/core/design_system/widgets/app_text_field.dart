import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_spacing.dart';

/// Labelled input used by authentication and future SmartUMC forms.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.leadingAsset,
    this.trailing,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.obscureText = false,
    this.autocorrect = true,
    this.autofillHints,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? leadingAsset;
  final Widget? trailing;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autocorrect;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autocorrect: autocorrect,
          enableSuggestions: !obscureText,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: leadingAsset == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: SvgPicture.asset(
                      leadingAsset!,
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 52,
            ),
            suffixIcon: trailing,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}
