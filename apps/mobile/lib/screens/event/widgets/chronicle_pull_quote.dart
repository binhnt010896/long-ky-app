import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// The italic chronicle pull-quote — the app's recurring signature beat.
class ChroniclePullQuote extends StatelessWidget {
  const ChroniclePullQuote({
    required this.quote,
    required this.lang,
    super.key,
  });

  final PullQuote quote;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 4, 0, 4),
      decoration: const Border(
        left: BorderSide(color: VSColors.gold, width: 2),
      ).toDecoration(),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: -8,
            top: -18,
            child: Text(
              '“',
              style: VSType.hub.copyWith(
                fontSize: 44,
                height: 1,
                color: VSColors.gold.withValues(alpha: 0.4),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(quote.text.resolve(lang), style: VSType.pullQuote),
              if (quote.attribution != null) ...<Widget>[
                const SizedBox(height: VSSpacing.sm),
                Text(
                  '— ${quote.attribution!.resolve(lang)}',
                  style: VSType.caption.copyWith(
                    color: VSColors.inkMuted,
                    letterSpacing: VSType.track(0.1, 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

extension on Border {
  BoxDecoration toDecoration() => BoxDecoration(border: this);
}
