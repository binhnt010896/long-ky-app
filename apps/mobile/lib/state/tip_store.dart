import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// "Mời Long Ký một chén trà" — three consumable tip sizes to the developer
/// through store billing (App Store Review Guideline 3.1.1; Google Play
/// Billing), never framed as a charity donation. Capped at three cups so
/// nobody overspends on a tip.
const List<String> kTipProductIds = <String>[
  'long_ky_tea', // Một chén trà — $0.99
  'long_ky_tea_2', // Hai chén trà — $1.99
  'long_ky_tea_3', // Ba chén trà — $2.99
];

/// A loaded tip size: the store's own localized price string (e.g.
/// "25.000 ₫") and how many cups it draws (1/2/3), which the UI uses to pick
/// the matching line icon and label.
class TipOffer {
  const TipOffer({required this.productId, required this.price, required this.cups});
  final String productId;
  final String price;
  final int cups;
}

enum TipOutcome { thanked, pending, cancelled, failed }

/// The tip purchase seam — a real store in the app, a fake in tests.
abstract class TipStore {
  /// The offers actually returned by the store, sorted by price (ascending).
  /// A product not yet created in the store (or the store being unavailable —
  /// web, no Play services) is simply missing from the list; an empty list
  /// hides the tip row entirely.
  Future<List<TipOffer>> load();

  Future<void> buy(String productId);

  Stream<TipOutcome> get outcomes;

  void dispose() {}
}

int _cupsFor(String productId) => switch (productId) {
      'long_ky_tea' => 1,
      'long_ky_tea_2' => 2,
      'long_ky_tea_3' => 3,
      _ => 1,
    };

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
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};

  @override
  Stream<TipOutcome> get outcomes => _outcomes.stream;

  @override
  Future<List<TipOffer>> load() async {
    try {
      if (!await _iap.isAvailable()) return const <TipOffer>[];
      final res = await _iap.queryProductDetails(kTipProductIds.toSet());
      for (final p in res.productDetails) {
        _products[p.id] = p;
      }
      final offers = <TipOffer>[
        for (final p in res.productDetails)
          TipOffer(productId: p.id, price: p.price, cups: _cupsFor(p.id)),
      ]..sort((a, b) => a.cups.compareTo(b.cups));
      return offers;
    } catch (_) {
      return const <TipOffer>[];
    }
  }

  @override
  Future<void> buy(String productId) async {
    final product = _products[productId];
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
      if (!kTipProductIds.contains(p.productID)) continue;
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

/// The loaded tip offers; an empty list hides the tip row entirely.
final tipOffersProvider = FutureProvider<List<TipOffer>>((ref) async {
  final store = ref.watch(tipStoreProvider);
  return store?.load() ?? const <TipOffer>[];
});
