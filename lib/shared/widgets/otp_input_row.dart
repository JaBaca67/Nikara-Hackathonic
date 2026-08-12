import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// A row of independent single-digit boxes for entering a verification
/// code — auto-advances focus forward as each digit is typed, and moves
/// focus back on backspace from an empty box (the standard OTP UX).
class OtpInputRow extends StatefulWidget {
  const OtpInputRow({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpInputRow> createState() => _OtpInputRowState();
}

class _OtpInputRowState extends State<OtpInputRow> {
  late final List<TextEditingController> _controllers = List.generate(
    widget.length,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focusNodes = List.generate(
    widget.length,
    (_) => FocusNode(),
  );
  // Ancestor listener nodes, deliberately NOT the same instance as
  // _focusNodes[i] — giving KeyboardListener and its child TextField the
  // same FocusNode crashes with "Tried to make a child into a parent of
  // itself" (both widgets attach a Focus to that node at different tree
  // depths). Key events still reach these because Flutter's Focus system
  // bubbles unhandled key events up from the focused descendant to its
  // ancestors' onKeyEvent handlers.
  late final List<FocusNode> _listenerNodes = List.generate(
    widget.length,
    (_) => FocusNode(skipTraversal: true, canRequestFocus: false),
  );

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final node in _listenerNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    widget.onChanged(_code);
    if (_code.length == widget.length) widget.onCompleted?.call(_code);
  }

  KeyEventResult _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      widget.onChanged(_code);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < widget.length; i++)
          SizedBox(
            width: 44,
            height: 52,
            child: KeyboardListener(
              focusNode: _listenerNodes[i],
              onKeyEvent: (event) => _onKeyEvent(i, event),
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.inputText.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surface100,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.wizardFocus,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) => _onChanged(i, value),
              ),
            ),
          ),
      ],
    );
  }
}
