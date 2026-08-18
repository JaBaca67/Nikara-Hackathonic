import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Campos compartidos por `CreateEcoActivityScreen` y `CreateOrganizationScreen`.
///
/// Usan deliberadamente los mismos tokens que `RegisterBusinessWizard`
/// (`wizardFieldLabel`/`wizardFieldValue`/`wizardFocus`, tarjeta blanca sobre
/// fondo crema, radio 20/14): registrar una jornada y registrar un negocio son
/// el mismo gesto para el usuario, así que se ven igual. Lo único propio del
/// módulo ECO es el verde [AppColors.ecoActive] en los acentos de estado.

/// Etiqueta encima de un campo. Recibe el texto en capitalización normal
/// ('Título') y lo pinta en mayúsculas, como los labels del wizard.
class EcoFieldLabel extends StatelessWidget {
  const EcoFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: AppTextStyles.wizardFieldLabel),
    );
  }
}

class EcoTextField extends StatelessWidget {
  const EcoTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
    this.prefixText,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  /// Ej. la arroba fija del campo "Handle", para dejar claro que no hay que escribirla.
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: AppTextStyles.wizardFieldValue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.wizardFieldHint,
        prefixText: prefixText,
        prefixStyle: AppTextStyles.wizardFieldValue.copyWith(
          color: AppColors.settingsTextMuted,
        ),
        filled: true,
        fillColor: AppColors.settingsBackground,
        contentPadding: const EdgeInsets.all(14),
        border: _border(AppColors.settingsTextDark.withValues(alpha: 0.07)),
        enabledBorder: _border(
          AppColors.settingsTextDark.withValues(alpha: 0.07),
        ),
        focusedBorder: _border(AppColors.wizardFocus, width: 1.5),
        errorBorder: _border(AppColors.formError),
        focusedErrorBorder: _border(AppColors.formError, width: 1.5),
        errorStyle: AppTextStyles.errorText.copyWith(fontSize: 11),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Tarjeta blanca que agrupa un bloque del formulario, idéntica a la del
/// wizard de negocios.
class EcoFormCard extends StatelessWidget {
  const EcoFormCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        border: Border.all(color: AppColors.mapControlBorder),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.detailCardGlow,
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Encabezado de sección sobre la tarjeta ("Sobre la jornada", "¿Dónde es?").
class EcoSectionIntro extends StatelessWidget {
  const EcoSectionIntro({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.wizardStepHeading),
          const SizedBox(height: 3),
          Text(subtitle, style: AppTextStyles.wizardStepSubtitle),
        ],
      ),
    );
  }
}

/// Barra superior del formulario: mismo layout que `_WizardHeader`.
class EcoFormHeader extends StatelessWidget {
  const EcoFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.profileDivider,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.settingsTextDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.wizardAppBarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.wizardCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface100,
                border: Border.all(color: AppColors.mapControlBorder),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Salir', style: AppTextStyles.detailPillAction),
            ),
          ),
        ],
      ),
    );
  }
}

class EcoPickerButton extends StatelessWidget {
  const EcoPickerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSet = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Ya tiene valor elegido: el borde y el ícono pasan al verde ECO.
  final bool isSet;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 16,
        color: isSet ? AppColors.ecoActive : AppColors.settingsTextMuted,
      ),
      label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.settingsTextDark,
        backgroundColor: AppColors.settingsBackground,
        textStyle: AppTextStyles.wizardChipLabel,
        side: BorderSide(
          color: isSet
              ? AppColors.ecoActive.withValues(alpha: 0.55)
              : AppColors.settingsTextDark.withValues(alpha: 0.07),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class EcoPrimaryButton extends StatelessWidget {
  const EcoPrimaryButton({
    super.key,
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.detailPrimaryButtonGlow,
            offset: Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isBusy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary500,
            foregroundColor: AppColors.settingsTextDark,
            disabledBackgroundColor: AppColors.primary500.withValues(
              alpha: 0.55,
            ),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTextStyles.wizardFooterPrimary,
          ),
          child: isBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.settingsTextDark,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}
