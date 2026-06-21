/// Service d'achats in-app — Story 3.4a / 3.4b.
///
/// Configure et orchestre le flux d'achat des packs de pièces via le
/// plugin [in_app_purchase]. Gère les achats pending (Android),
/// le restore purchases (iOS) et les erreurs.
library;

import 'dart:async';
import 'dart:math';

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

// ── Résultat d'achat ────────────────────────────────────────────────────────

/// Résultat d'une tentative d'achat ou de restore.
enum IapResult {
  /// Achat réussi, pièces créditées.
  success,

  /// Achat annulé par l'utilisateur.
  canceled,

  /// Achat en attente de validation (Android — paiement différé).
  pending,

  /// Acheté précédemment et restauré (iOS).
  restored,

  /// Erreur technique.
  error,
}

// ── Service IAP ─────────────────────────────────────────────────────────────

/// Provider du service IAP. Initialise la connexion au store et expose les
/// produits. Se dispose automatiquement via [ref.onDispose].
final iapServiceProvider = Provider<IapService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final service = IapService(db: db);
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

/// Nombre d'achats en attente (pending Android).
final pendingPurchaseCountProvider = Provider<int>((ref) {
  return ref.watch(iapServiceProvider).pendingCount;
});

class IapService {
  final AppDatabase _db;
  final InAppPurchase _iap = InAppPurchase.instance;

  IapService({required AppDatabase db}) : _db = db {
    _init();
  }
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Map<String, Completer<IapResult>> _pendingCompleters = {};
  int _pendingCount = 0;
  List<ProductDetails> _products = [];
  bool _available = false;

  /// Produits disponibles (mis en cache après [queryProductDetails]).
  List<ProductDetails> get products => List.unmodifiable(_products);

  /// true si le service IAP est disponible sur cet appareil.
  bool get available => _available;

  /// Nombre d'achats pending en attente.
  int get pendingCount => _pendingCount;

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
      debugPrint('[IAP] Purchase update: ${purchase.productID} '
          '(status: ${purchase.status}, id: ${purchase.purchaseID})');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _handlePending(purchase);
        case PurchaseStatus.purchased:
          _handlePurchased(purchase);
        case PurchaseStatus.restored:
          _handleRestored(purchase);
        case PurchaseStatus.error:
          _handleError(purchase);
        case PurchaseStatus.canceled:
          _handleCanceled(purchase);
      }
    }
  }

  void _handlePending(PurchaseDetails purchase) {
    _pendingCount++;
    // Ne pas résoudre le completer — attendre le statut purchased final.
  }

  Future<void> _handlePurchased(PurchaseDetails purchase) async {
    _pendingCount = max(0, _pendingCount - 1);
    await _deliver(purchase);
  }

  Future<void> _handleRestored(PurchaseDetails purchase) async {
    _pendingCount = max(0, _pendingCount - 1);
    await _deliver(purchase);
  }

  void _handleError(PurchaseDetails purchase) {
    _pendingCount = max(0, _pendingCount - 1);
    _resolveCompleter(purchase.productID, IapResult.error);
  }

  void _handleCanceled(PurchaseDetails purchase) {
    _pendingCount = max(0, _pendingCount - 1);
    _resolveCompleter(purchase.productID, IapResult.canceled);
  }

  /// Livre la récompense et finalise la transaction.
  Future<void> _deliver(PurchaseDetails purchase) async {
    final pack = kCoinPacks.where(
      (p) => p.productId == purchase.productID,
    ).firstOrNull;

    if (pack != null) {
      await addCoinsToProfile(_db, pack.coins);
      debugPrint('[IAP] Delivered ${pack.coins} coins for ${pack.productId}');
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }

    _resolveCompleter(purchase.productID,
        pack != null ? IapResult.success : IapResult.error);
  }

  void _resolveCompleter(String productId, IapResult result) {
    final completer = _pendingCompleters.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  /// Lance un achat consommable pour le produit [productId].
  ///
  /// Retourne [IapResult.success] si l'achat a réussi, [IapResult.canceled]
  /// si l'utilisateur a annulé, [IapResult.pending] si le paiement est en
  /// attente (Android), ou [IapResult.error] en cas d'échec.
  Future<IapResult> purchase(String productId) async {
    if (!_available) return IapResult.error;

    final product = _products.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    if (product == null) {
      debugPrint('[IAP] Product not found: $productId');
      return IapResult.error;
    }

    if (_pendingCompleters.containsKey(productId)) {
      debugPrint('[IAP] Purchase already in progress for $productId');
      return IapResult.error;
    }

    final completer = Completer<IapResult>();
    _pendingCompleters[productId] = completer;

    try {
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      debugPrint('[IAP] Failed to initiate purchase: $e');
      _pendingCompleters.remove(productId);
      return IapResult.error;
    }

    return completer.future;
  }

  /// Restaure les achats précédents.
  ///
  /// Retourne `true` si la restauration a été initiée. Les produits
  /// restaurés sont livrés automatiquement via le purchaseStream.
  Future<bool> restorePurchases() async {
    if (!_available) return false;
    await _iap.restorePurchases();
    return true;
  }

  void dispose() {
    _subscription?.cancel();
    _pendingCompleters.clear();
  }
}

// ── Fonctions utilisables depuis l'UI ───────────────────────────────────────

/// Achète le pack de pièces à l'index [packIndex] dans [kCoinPacks].
///
/// Retourne le [IapResult] correspondant.
Future<IapResult> purchaseCoinPack(WidgetRef ref, int packIndex) async {
  if (packIndex < 0 || packIndex >= kCoinPacks.length) return IapResult.error;

  final pack = kCoinPacks[packIndex];
  final iap = ref.read(iapServiceProvider);

  return iap.purchase(pack.productId);
}

/// Restaure les achats précédents (bouton en bas de la boutique).
Future<bool> restoreAllPurchases(WidgetRef ref) async {
  final iap = ref.read(iapServiceProvider);
  return iap.restorePurchases();
}
