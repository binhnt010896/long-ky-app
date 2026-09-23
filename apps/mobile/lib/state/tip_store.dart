import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// "Mời Long Ký một chén trà" — the single consumable tip product. A tip to the
/// developer through store billing (App Store Review Guideline 3.1.1; Google
/// Play Billing), never framed as a charity donation.
const String kTipProductId = 'long_ky_tea';

/// A loaded tip product: the store's localized price string (e.g. "25.000 ₫").
class TipOffer {
  const TipOffer({required this.price});
  final String price;
}

enum TipOutcome { thanked, pending, cancelled, failed }

/// The tip purchase seam — a real store in the app, a fake in tests.
abstract class TipStore {
  /// The offer, or null when the store or the product is unavailable (web, no
  /// Play services, product not yet created) — the UI then shows nothing.
  Future<TipOffer?> load();

  Future<void> buy();

  Stream<TipOutcome> get outcomes;

  void dispose() {}
}

/// Google Play Billing (and later App Store) via the official plugin.
class StoreTipStore implements TipStore {
  StoreTipStore() {
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object _) {
      _outcomes.add(TipOutcome.failed);
    });
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  final StreamController<TipOutcome> _outcomes =
      StreamController<TipOutcome>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _sub;
  ProductDetails? _product;

  @override
  Stream<TipOutcome> get outcomes => _outcomes.stream;

  @override
  Future<TipOffer?> load() async {
    try {
      if (!await _iap.isAvailable()) return null;
      final res = await _iap.queryProductDetails(<String>{kTipProductId});
      if (res.productDetails.isEmpty) return null;
      _product = res.productDetails.first;
      return TipOffer(price: _product!.price);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> buy() async {
    final product = _product;
    if (product == null) return;
    try {
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      _outcomes.add(TipOutcome.failed);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != kTipProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _outcomes.add(TipOutcome.pending);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _outcomes.add(TipOutcome.thanked);
        case PurchaseStatus.canceled:
          _outcomes.add(TipOutcome.cancelled);
        case PurchaseStatus.error:
          _outcomes.add(TipOutcome.failed);
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _outcomes.close();
  }
}

/// The tip store, or null where store billing doesn't exist (web).
final tipStoreProvider = Provider<TipStore?>((ref) {
  if (kIsWeb) return null;
  try {
    final store = StoreTipStore();
    ref.onDispose(store.dispose);
    return store;
  } catch (_) {
    // No billing platform registered (e.g. widget tests, desktop).
    return null;
  }
});

/// The loaded tip offer; null hides the tip row entirely.
final tipOfferProvider = FutureProvider<TipOffer?>((ref) async {
  final store = ref.watch(tipStoreProvider);
  return store?.load();
});
