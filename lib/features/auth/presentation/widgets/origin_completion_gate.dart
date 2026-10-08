import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/shared/widgets/origin_form_fields.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Compuerta común a login, OAuth, cambio de cuenta y sesión restaurada.
/// No monta las pestañas hasta confirmar los datos guardados en el servidor.
class OriginCompletionGate extends StatefulWidget {
  const OriginCompletionGate({super.key, required this.child});
  final Widget child;
  @override
  State<OriginCompletionGate> createState() => _OriginCompletionGateState();
}

class _OriginCompletionGateState extends State<OriginCompletionGate> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  StreamSubscription<AuthState>? _subscription;
  String? _userId;
  UserModel? _profile;
  UserOrigin _origin = const UserOrigin();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentAuthUser?.id;
    _subscription = _auth.authStateChanges.listen((_) {
      if (_userId == _auth.currentAuthUser?.id) return;
      _userId = _auth.currentAuthUser?.id;
      unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _profile = null;
    });
    try {
      final profile = await _auth.getCurrentProfile();
      if (!mounted || request != _request) return;
      setState(() {
        _profile = profile;
        _origin = profile?.origin ?? const UserOrigin();
        _loading = false;
        if (_auth.isLoggedIn && profile == null) {
          _error = 'No se pudo cargar tu perfil. Intenta de nuevo.';
        }
      });
    } on AuthServiceException catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = _userId;
    setState(() => _saving = true);
    try {
      final profile = await _auth.updatePublicProfile(origin: _origin);
      if (!mounted || userId != _userId) return;
      setState(() => _profile = profile);
    } on AuthServiceException catch (e) {
      if (mounted) AppSnackbar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      pushFadeThroughAndRemoveUntil(context, const LoginScreen());
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'No se pudo cerrar la sesión. Intenta de nuevo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && !_auth.isLoggedIn) return widget.child;
    if (!_loading && _error == null && _profile?.origin.isComplete == true) {
      return KeyedSubtree(key: ValueKey(_userId), child: widget.child);
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Completa tu procedencia',
                              style: AppTextStyles.sectionTitle.copyWith(
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_error != null) ...[
                              Text(_error!, style: AppTextStyles.body),
                              const SizedBox(height: 16),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.goldFill,
                                  foregroundColor: AppColors.neutral1100,
                                ),
                                onPressed: _load,
                                child: const Text('Reintentar'),
                              ),
                            ] else ...[
                              Text(
                                'Antes de continuar, cuéntanos de dónde vienes. Puedes cambiar esta información y su visibilidad desde tu perfil.',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.neutral800,
                                ),
                              ),
                              const SizedBox(height: 24),
                              OriginFormFields(
                                key: ValueKey(_userId),
                                initialValue: _origin,
                                onChanged: (value) => _origin = value,
                                enabled: !_saving,
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.goldFill,
                                  foregroundColor: AppColors.neutral1100,
                                ),
                                onPressed: _saving ? null : _save,
                                child: Text(
                                  _saving
                                      ? 'Guardando…'
                                      : 'Guardar y continuar',
                                ),
                              ),
                            ],
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.neutral1100,
                              ),
                              onPressed: _saving ? null : _signOut,
                              child: const Text('Cerrar sesión'),
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
