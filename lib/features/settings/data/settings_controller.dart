import 'package:flutter/foundation.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';

/// UI snapshot of preferences persisted in the current Supabase profile.
class SettingsController extends ChangeNotifier {
  SettingsController({AuthService? authService})
    : _authService = authService ?? AuthService();
  final AuthService _authService;
  bool _disposed = false;
  String name = '';
  String email = '';
  String phone = '';
  String username = '';
  UserRole role = UserRole.turista;
  bool tripAlerts = true;
  bool ecoCampaigns = true;
  bool offers = false;
  bool publicProfile = true;
  bool saving = false;
  String? error;

  Future<void> loadProfile() async {
    if (saving || _disposed) return;
    final id = _authService.currentAuthUser?.id;
    UserModel? profile;
    try {
      profile = await _authService.getCurrentProfile();
    } on AuthServiceException catch (e) {
      if (!_disposed) {
        error = e.message;
        notifyListeners();
      }
      return;
    }
    if (_disposed ||
        profile == null ||
        _authService.currentAuthUser?.id != id) {
      return;
    }
    name = profile.fullName;
    email = profile.email;
    phone = profile.phone;
    username = profile.username;
    role = profile.role;
    tripAlerts = profile.tripAlerts;
    ecoCampaigns = profile.ecoCampaigns;
    offers = profile.offers;
    publicProfile = profile.publicProfile;
    error = null;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? username,
  }) async {
    final id = _authService.currentAuthUser?.id;
    final profile = await _authService.updateAccountProfile(
      fullName: name,
      phone: phone,
      username: username,
    );
    if (_disposed || id != _authService.currentAuthUser?.id) return;
    this.name = profile.fullName;
    this.email = profile.email;
    this.phone = profile.phone;
    this.username = profile.username;
    notifyListeners();
  }

  Future<void> _save(String column, bool value, VoidCallback apply) async {
    if (saving) return;
    final id = _authService.currentAuthUser?.id;
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _authService.updatePreferences({column: value});
      if (!_disposed && id == _authService.currentAuthUser?.id) apply();
    } on AuthServiceException catch (e) {
      if (!_disposed) error = e.message;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setTripAlerts(bool value) =>
      _save('trip_alerts', value, () => tripAlerts = value);
  Future<void> setEcoCampaigns(bool value) =>
      _save('eco_campaigns', value, () => ecoCampaigns = value);
  Future<void> setOffers(bool value) =>
      _save('offers', value, () => offers = value);
  Future<void> setPublicProfile(bool value) =>
      _save('public_profile', value, () => publicProfile = value);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
