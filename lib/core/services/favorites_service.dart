import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/core/services/remote_user_data_service.dart';

class FavoritesServiceException implements Exception {
  const FavoritesServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Private account rows in Supabase, with no disk cache or guest favorites.
class FavoritesService {
  factory FavoritesService() => instance;
  FavoritesService._internal()
    : _remote = RemoteUserDataService(),
      _realtime = true;
  @visibleForTesting
  FavoritesService.forTesting(SupabaseClient client)
    : _remote = RemoteUserDataService(client: client),
      _realtime = false;
  static final FavoritesService instance = FavoritesService._internal();
  final RemoteUserDataService _remote;
  final bool _realtime;
  final idsNotifier = ValueNotifier<Set<String>>(<String>{});
  static final businessCountsRevision = ValueNotifier<int>(0);
  static const loadFailedMessage =
      'No se pudieron cargar tus favoritos. Verifica tu internet e intenta de nuevo.';
  static const offlineToggleMessage =
      'Sin conexión. No se pudo actualizar tu favorito.';
  @visibleForTesting
  int preloadCallCount = 0;
  String? _owner;
  int _generation = 0;
  Future<bool>? _loading;
  Future<void> _writes = Future.value();
  Future<void> Function()? _unsubscribe;

  Future<bool> preload() async {
    preloadCallCount++;
    final id = _remote.client.auth.currentUser?.id;
    if (_owner != id) invalidate();
    if (id == null) return true;
    _owner = id;
    if (_realtime) {
      _unsubscribe ??= _remote.subscribe(['user_favorites'], () {
        unawaited(preload());
        businessCountsRevision.value++;
      });
    }
    final pending = _loading;
    if (pending != null) return pending;
    final generation = _generation;
    late final Future<bool> future;
    future = _read(id, generation).whenComplete(() {
      if (identical(_loading, future)) _loading = null;
    });
    _loading = future;
    return future;
  }

  Future<bool> _read(String userId, int generation) async {
    try {
      final rows = await _remote.client
          .from('user_favorites')
          .select('item_id')
          .eq('user_id', userId)
          .eq('item_type', 'business');
      if (generation != _generation ||
          _remote.client.auth.currentUser?.id != userId) {
        return false;
      }
      final ids = rows.map((r) => r['item_id'] as String).toSet();
      if (!setEquals(ids, idsNotifier.value)) idsNotifier.value = ids;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Set<String>> getFavoriteIds() async {
    if (!await preload()) {
      throw const FavoritesServiceException(loadFailedMessage);
    }
    return Set.unmodifiable(idsNotifier.value);
  }

  Future<bool> isFavorite(String id) async =>
      (await getFavoriteIds()).contains(id);

  Future<bool> toggleFavorite(String id) {
    final caller = _remote.client.auth.currentUser?.id;
    final result = _writes.then((_) => _toggle(id, caller));
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> setFavorite(String id, bool favorite) {
    final caller = _remote.client.auth.currentUser?.id;
    final result = _writes.then((_) => _toggle(id, caller, favorite: favorite));
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _toggle(String id, String? caller, {bool? favorite}) async {
    if (caller == null) {
      throw const FavoritesServiceException(
        'Inicia sesión para guardar favoritos.',
      );
    }
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FavoritesServiceException(
        'Este lugar no está disponible para guardar.',
      );
    }
    if (_remote.client.auth.currentUser?.id != caller) {
      throw const FavoritesServiceException(
        'La cuenta cambió. Intenta de nuevo.',
      );
    }
    final ids = favorite == null ? await getFavoriteIds() : idsNotifier.value;
    if (_remote.client.auth.currentUser?.id != caller) {
      throw const FavoritesServiceException(
        'La cuenta cambió. Intenta de nuevo.',
      );
    }
    final desired = favorite ?? !ids.contains(id);
    try {
      final saved = await _remote.client.rpc(
        'set_business_favorite',
        params: {'p_business_id': id, 'p_favorite': desired},
      );
      if (saved != desired) {
        throw const FavoritesServiceException(
          'No se pudo confirmar el favorito.',
        );
      }
      if (_remote.client.auth.currentUser?.id == caller) {
        _generation++;
        _loading = null;
        final updated = {...idsNotifier.value};
        if (desired) {
          updated.add(id);
        } else {
          updated.remove(id);
        }
        idsNotifier.value = updated;
      }
      businessCountsRevision.value++;
      return desired;
    } on FavoritesServiceException {
      rethrow;
    } on PostgrestException {
      throw const FavoritesServiceException(
        'No se pudo actualizar el favorito. Intenta de nuevo.',
      );
    } catch (_) {
      throw const FavoritesServiceException(offlineToggleMessage);
    }
  }

  Future<int> countFavoritesForBusiness(String businessId) async {
    try {
      final result = await _remote.client.rpc(
        'business_favorite_count',
        params: {'p_business_id': businessId},
      );
      return (result as num).toInt();
    } catch (_) {
      throw const FavoritesServiceException(
        'No se pudo consultar el total de favoritos.',
      );
    }
  }

  @visibleForTesting
  void resetForTesting() {
    invalidate();
    _writes = Future.value();
  }

  void invalidate() {
    _generation++;
    _owner = null;
    _loading = null;
    final stop = _unsubscribe;
    _unsubscribe = null;
    if (stop != null) unawaited(stop());
    if (idsNotifier.value.isNotEmpty) idsNotifier.value = <String>{};
  }
}
