/// Service d'achats in-app — Story 3.4a.
///
/// Configure et orchestre le flux d'achat des packs de pièces via le
/// plugin [in_app_purchase] (Flutter official).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/constants.dart';
import '../data/app_database.dart';
import '../providers/player_profile_provider.dart';

// ── IDs produits ────────────────────────────────────────────────────────────

/// Ensemble des IDs produits consommables (packs de pièces).
const Set<String> kCoinPackProductIds = {
  'coins_small',
  'coins_medium',
  'coins_large',
};

// ── Service IAP ─────────────────────────────────────────────────────────────

/// Provider du service IAP. Initialise la connexion au store et expose les
/// produits. Se dispose automatiquement via [ref.onDispose].
final iapServiceProvider = Provider<IapService>((ref) {
  final service = IapService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider exposant les [ProductDetails] des packs de pièces une fois
/// chargés. Retourne une liste vide tant que le chargement n'est pas terminé.
final coinPackProductsProvider = Provider<List<ProductDetails>>((ref) {
  return ref.watch(iapServiceProvider).products;
});

/// Provider indiquant si le service IAP est disponible sur cet appareil.
final iapAvailableProvider = Provider<bool>((ref) {
  return ref.watch(iapServiceProvider).available;
});

class IapService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Map<String, Completer<PurchaseDetails?>> _pending = {};

  List<ProductDetails> _products = [];
  bool _available = false;

  /// Produits disponibles (mis en cache après [queryProductDetails]).
  List<ProductDetails> get products => List.unmodifiable(_products);

  /// true si le service IAP est disponible sur cet appareil.
  bool get available => _available;

  IapService() {
    _init();
  }

  Future<void> _init() async {
    final isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      debugPrint('[IAP] Service not available');
      return;
    }

    _available = true;

    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate);

    final response = await _iap.queryProductDetails(kCoinPackProductIds);
    _products = response.productDetails;

    debugPrint('[IAP] Products loaded: ${_products.length}');
    for (final p in _products) {
      debugPrint('[IAP]   - ${p.id} (${p.rawPrice})');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      final completer = _pending.remove(purchase.productID);
      if (completer == null) continue;

      if (purchase.status == PurchaseStatus.purchased) {
        debugPrint('[IAP] Purchase successful: ${purchase.productID}');
        completer.complete(purchase);
      } else {
        debugPrint('[IAP] Purchase failed/canceled: ${purchase.productID} '
            '(status: ${purchase.status})');
        completer.complete(null);
      }
    }
  }

  /// Lance un achat consommable pour le produit [productId].
  ///
  /// Retourne les [PurchaseDetails] si l'achat a réussi, `null` en cas
  /// d'échec ou d'annulation. Le caller doit ensuite créditer la récompense
  /// et appeler [completePurchase] sur les détails retournés.
  Future<PurchaseDetails?> purchase(String productId) async {
    if (!_available) return null;

    final product = _products.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    if (product == null) {
      debugPrint('[IAP] Product not found: $productId');
      return null;
    }

    final completer = Completer<PurchaseDetails?>();
    _pending[productId] = completer;

    try {
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      debugPrint('[IAP] Failed to initiate purchase: $e');
      _pending.remove(productId);
      return null;
    }

    return completer.future;
  }

  void dispose() {
    _subscription?.cancel();
    _pending.clear();
  }
}

// ── Fonction d'achat utilisable depuis l'UI ─────────────────────────────────

/// Achète le pack de pièces à l'index [packIndex] dans [kCoinPacks].
///
/// 1. Lance l'achat via le store natif.
/// 2. Si réussi, crédite les pièces et finalise la transaction.
/// 3. Retourne `true` si les pièces ont été créditées.
Future<bool> purchaseCoinPack(WidgetRef ref, int packIndex) async {
  if (packIndex < 0 || packIndex >= kCoinPacks.length) return false;

  final pack = kCoinPacks[packIndex];
  final iap = ref.read(iapServiceProvider);

  final purchase = await iap.purchase(pack.productId);
  if (purchase == null) return false;

  final db = ref.read(appDatabaseProvider);
  await addCoinsToProfile(db, pack.coins);

  if (purchase.pendingCompletePurchase) {
    await InAppPurchase.instance.completePurchase(purchase);
  }

  debugPrint('[IAP] Delivered ${pack.coins} coins for ${pack.productId}');
  return true;
}
