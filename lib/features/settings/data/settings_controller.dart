import 'package:flutter/foundation.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';

/// Estado compartido por el menú de Ajustes y las vistas de cada categoría.
///
/// Vive en la pantalla principal (no en las vistas) para que lo que la persona
/// cambió en una categoría siga ahí al volver al menú y al reabrirla. Es estado
/// local de la visita a Ajustes: los interruptores y la edición de perfil no se
/// persisten, igual que antes de separar las categorías, y por eso no es un
/// singleton — al salir de Ajustes (o cambiar de cuenta) no debe sobrevivir.
class SettingsController extends ChangeNotifier {
  SettingsController({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;
  bool _disposed = false;

  String name = '';
  String email = '';
  String phone = '';
  UserRole role = UserRole.turista;

  bool tripAlerts = true;
  bool ecoCampaigns = true;
  bool offers = false;
  bool publicProfile = true;
  bool shareLocation = false;

  Future<void> loadProfile() async {
    final profile = await _authService.getCurrentProfile();
    if (_disposed || profile == null) return;
    name = profile.fullName;
    email = profile.email;
    phone = profile.phone;
    role = profile.role;
    notifyListeners();
  }

  void updateProfile({
    required String name,
    required String email,
    required String phone,
  }) {
    this.name = name;
    this.email = email;
    this.phone = phone;
    notifyListeners();
  }

  void setTripAlerts(bool value) {
    tripAlerts = value;
    notifyListeners();
  }

  void setEcoCampaigns(bool value) {
    ecoCampaigns = value;
    notifyListeners();
  }

  void setOffers(bool value) {
    offers = value;
    notifyListeners();
  }

  void setPublicProfile(bool value) {
    publicProfile = value;
    notifyListeners();
  }

  void setShareLocation(bool value) {
    shareLocation = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
