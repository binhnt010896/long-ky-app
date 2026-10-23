import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_router.dart' show routeTelemetryObserverProvider;

/// Bubbled up by "Đọc thêm" (ExpandableDetails) when the reader opens it.
class DetailsOpenedNotification extends Notification {
  const DetailsOpenedNotification();
}

/// Wraps an event page's vertical scroll view and adds how far down the reader
/// got (`max_scroll_pct`, the share of the page that has been on screen) and
/// whether they opened "Đọc thêm" (`details_opened`) to that event's
/// `screen_leave` — see [RouteTelemetryObserver.annotate].
///
/// [current] is false for a pager neighbour that is only half on screen
/// mid-swipe: it keeps measuring, and reports once it becomes the page on
/// screen (by then the observer has started a fresh visit for it).
class EventReadingDepth extends ConsumerStatefulWidget {
  const EventReadingDepth({
    required this.eventId,
    required this.child,
    this.current = true,
    super.key,
  });

  final String eventId;
  final bool current;
  final Widget child;

  @override
  ConsumerState<EventReadingDepth> createState() => _EventReadingDepthState();
}

class _EventReadingDepthState extends ConsumerState<EventReadingDepth> {
  /// Where the reader is now, and the furthest point of this visit.
  int? _seen;
  int _visitMax = -1;

  @override
  void didUpdateWidget(EventReadingDepth old) {
    super.didUpdateWidget(old);
    if (widget.current && !old.current) {
      // A new visit: the observer cleared the last one's annotations.
      _visitMax = -1;
      final seen = _seen;
      if (seen != null) _reportScroll(seen);
    }
  }

  void _reportScroll(int pct) {
    if (pct <= _visitMax) return;
    _visitMax = pct;
    _annotate(<String, Object>{'max_scroll_pct': pct});
  }

  void _annotate(Map<String, Object> extras) {
    ref.read(routeTelemetryObserverProvider).annotate(
        'event_detail', <String, Object>{'event_id': widget.eventId}, extras);
  }

  static int _pct(ScrollMetrics m) {
    final total = m.maxScrollExtent + m.viewportDimension;
    if (total <= 0) return 0;
    return ((m.pixels + m.viewportDimension) / total * 100).round().clamp(0, 100);
  }

  bool _onNotification(Notification n) {
    final ScrollMetrics? metrics = switch (n) {
      ScrollNotification(:final metrics, :final depth) when depth == 0 => metrics,
      ScrollMetricsNotification(:final metrics, :final depth) when depth == 0 =>
        metrics,
      _ => null,
    };
    if (metrics != null && metrics.axis == Axis.vertical) {
      final pct = _pct(metrics);
      _seen = pct;
      if (widget.current) _reportScroll(pct);
    } else if (n is DetailsOpenedNotification && widget.current) {
      _annotate(<String, Object>{'details_opened': 1});
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<Notification>(onNotification: _onNotification, child: widget.child);
}
