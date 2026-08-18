import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Input estandarizado de Auth; gestiona su propio toggle de visibilidad de contraseña sin plumbing externo.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.icon,
    this.prefix,
    this.isPassword = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.focusNode,
    this.height = 48,
  }) : assert(icon != null || prefix != null, 'Provide either icon or prefix');

  final String label;
  final String hintText;
  final TextEditingController controller;

  final IconData? icon;

  /// Widget custom (p. ej. el selector de código de país); el assert del constructor garantiza que solo uno de [icon]/[prefix] se use.
  final Widget? prefix;

  final bool isPassword;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final double height;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: AppTextStyles.authFieldLabel),
        const SizedBox(height: 6),
        Container(
          constraints: BoxConstraints(minHeight: widget.height),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.settingsBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.authMuted.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              if (widget.prefix != null)
                widget.prefix!
              else
                Icon(widget.icon, size: 18, color: AppColors.primary500),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  obscureText: widget.isPassword && _obscureText,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.textCapitalization,
                  autofillHints: widget.autofillHints,
                  inputFormatters: widget.inputFormatters,
                  validator: widget.validator,
                  style: AppTextStyles.inputText.copyWith(
                    color: AppColors.authInk,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hintText,
                    hintStyle: AppTextStyles.inputText.copyWith(
                      color: AppColors.authPlaceholder,
                    ),
                    border: InputBorder.none,
                    errorMaxLines: 1,
                    errorStyle: AppTextStyles.errorText,
                  ),
                ),
              ),
              if (widget.isPassword)
                GestureDetector(
                  onTap: () => setState(() => _obscureText = !_obscureText),
                  child: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppColors.authMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
