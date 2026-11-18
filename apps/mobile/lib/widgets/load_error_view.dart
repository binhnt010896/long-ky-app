import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../state/providers.dart';
import 'circle_icon_button.dart';
import 'pressable.dart';

/// What a screen shows when its content could not be loaded: a plain sentence
/// in the reading language, a way to try again, and a way back — never the raw
/// exception (that only shows in a debug build, small, under the button).
class LoadErrorView extends ConsumerWidget {
  const LoadErrorView({
    required this.onRetry,
    this.error,
    this.messageVi = 'Chưa tải được nội dung.',
    this.messageEn = 'This couldn’t be loaded.',
    this.showBack = true,
    super.key,
  });

  /// Re-runs the load — usually `ref.invalidate(<provider>)`.
  final VoidCallback onRetry;
  final Object? error;
  final String messageVi;
  final String messageEn;

  /// A back button in the top-left corner, for a screen that has somewhere to
  /// go back to (everything but Home).
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final en = ref.watch(langProvider) == Lang.en;
    return SafeArea(
      child: Stack(
        children: <Widget>[
          if (showBack)
            Padding(
              padding: const EdgeInsets.all(VSSpacing.md),
              child: CircleIconButton.back(
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(VSSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.cloud_off_outlined,
                      size: 36, color: VSColors.inkMuted),
                  const SizedBox(height: VSSpacing.md),
                  Text(
                    en ? messageEn : messageVi,
                    textAlign: TextAlign.center,
                    style: VSType.cardTitle,
                  ),
                  const SizedBox(height: VSSpacing.xs),
                  Text(
                    en
                        ? 'Check your connection and try again.'
                        : 'Hãy kiểm tra kết nối rồi thử lại.',
                    textAlign: TextAlign.center,
                    style: VSType.bodySmall,
                  ),
                  const SizedBox(height: VSSpacing.lg),
                  Pressable(
                    key: const ValueKey<String>('load-error-retry'),
                    onTap: onRetry,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: VSSpacing.xl, vertical: VSSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: VSRadii.pillAll,
                        border: Border.all(
                            color: VSColors.gold.withValues(alpha: 0.6)),
                        color: VSColors.goldWash,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.refresh,
                              size: 18, color: VSColors.goldBright),
                          const SizedBox(width: VSSpacing.sm),
                          Text(
                            en ? 'Try again' : 'Thử lại',
                            style: VSType.label.copyWith(
                              color: VSColors.inkPrimary,
                              letterSpacing: VSType.track(0.1, 14),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (kDebugMode && error != null) ...<Widget>[
                    const SizedBox(height: VSSpacing.lg),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: VSType.provenance,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
