/// Decides *when* a live content update (Cycle K5/K6) is safe to actually
/// apply — never mid-read, so era/event text can't change under someone's
/// eyes. Pure and synchronous: feed it [contentChanged] events (from
/// [FirestoreContentSource.changes]) and [routeChanged] events (from the
/// router), and it calls [onSwap] at the right moment — immediately if the
/// reader is already on Home, otherwise the next time they return to Home.
/// No banner, no prompt (per [[delicate-ui-no-nags]]).
class ContentSwapGate {
  ContentSwapGate({required this.onSwap});

  final void Function() onSwap;

  bool _onHome = true;
  bool _pending = false;

  /// A live source reported a change. Swaps at once if on Home now,
  /// otherwise marks the swap pending for the next [routeChanged] to Home.
  /// Several changes before the swap happens collapse into one — [onSwap]
  /// always re-reads whatever is current at the moment it actually fires.
  void contentChanged() {
    _pending = true;
    _maybeSwap();
  }

  /// Call on every route change, not just ones that matter — this is what
  /// decides whether "the reader is on Home right now" for [contentChanged].
  void routeChanged({required bool onHome}) {
    _onHome = onHome;
    _maybeSwap();
  }

  void _maybeSwap() {
    if (_pending && _onHome) {
      _pending = false;
      onSwap();
    }
  }
}
