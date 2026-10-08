import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nikara_app/features/eco/domain/models/eco_moment_state.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

typedef SaveEcoMomentPolicy =
    Future<EcoMomentState> Function({
      required bool enabled,
      int? maxMessages,
      int? maxAccounts,
      int? maxPerAccount,
    });

class EcoMomentPolicySheet extends StatefulWidget {
  const EcoMomentPolicySheet({
    super.key,
    required this.state,
    required this.onSave,
  });
  final EcoMomentState state;
  final SaveEcoMomentPolicy onSave;

  @override
  State<EcoMomentPolicySheet> createState() => _EcoMomentPolicySheetState();
}

class _EcoMomentPolicySheetState extends State<EcoMomentPolicySheet> {
  final _form = GlobalKey<FormState>();
  late bool _enabled = widget.state.enabled;
  late final _messages = TextEditingController(
    text: widget.state.maxMessages?.toString() ?? '',
  );
  late final _accounts = TextEditingController(
    text: widget.state.maxAccounts?.toString() ?? '',
  );
  late final _perAccount = TextEditingController(
    text: widget.state.maxPerAccount?.toString() ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _messages.dispose();
    _accounts.dispose();
    _perAccount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onSave(
        enabled: _enabled,
        maxMessages: int.tryParse(_messages.text),
        maxAccounts: int.tryParse(_accounts.text),
        maxPerAccount: int.tryParse(_perAccount.text),
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'No se guardaron los cambios. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _limit(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Sin límite',
        helperText: 'Vacío = sin límite',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return null;
        final number = int.tryParse(value);
        return number == null || number < 1 || number > 2147483647
            ? 'Ingresa un número entre 1 y 2147483647'
            : null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Administrar Momentos', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Controla las publicaciones de participantes. Tus mensajes como administrador siguen habilitados.',
              style: AppTextStyles.settingsSubtitle,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir mensajes'),
              subtitle: Text(
                _enabled
                    ? 'Los participantes pueden compartir'
                    : 'Mensajes de participantes cerrados',
              ),
              value: _enabled,
              activeTrackColor: AppColors.primary500,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            _limit('Mensajes de participantes en total', _messages),
            _limit('Cuentas que pueden publicar', _accounts),
            _limit('Mensajes por cuenta', _perAccount),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Los límites cuentan mensajes y cuentas existentes. No borran publicaciones anteriores; eliminar un mensaje libera su cupo.',
              style: AppTextStyles.settingsSubtitle,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(_error!, style: AppTextStyles.settingsSubtitle),
              ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar configuración'),
            ),
          ],
        ),
      ),
    ),
  );
}
