import 'package:core_domain/core_domain.dart' show Lang;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../state/narration_controller.dart';
import '../state/providers.dart';

/// The play/pause chrome button for a page's spoken narration, with a progress
/// ring. Putting it on a page is what makes that page narrated: it registers
/// the page with the [narrationProvider] (autoplaying on a first visit) and
/// releases it when the page goes away. Vietnamese only for now, and it hides
/// itself when no clip exists for the page.
class NarrationButton extends ConsumerStatefulWidget {
  const NarrationButton({required this.kind, required this.id, super.key});

  final NarrationKind kind;
  final String id;

  @override
  ConsumerState<NarrationButton> createState() => _NarrationButtonState();
}

class _NarrationButtonState extends ConsumerState<NarrationButton> {
  late final NarrationController _ctl;
  bool _entered = false;

  String get _key => narrationKey(widget.kind, widget.id);

  @override
  void initState() {
    super.initState();
    _ctl = ref.read(narrationProvider.notifier);
    if (ref.read(langProvider) == Lang.vi) _enter();
  }

  @override
  void didUpdateWidget(NarrationButton old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind || old.id != widget.id) {
      _leave(narrationKey(old.kind, old.id));
      if (ref.read(langProvider) == Lang.vi) _enter();
    }
  }

  @override
  void dispose() {
    _leave(_key);
    super.dispose();
  }

  // Provider state must not change while the tree is building or tearing down.
  void _enter() {
    _entered = true;
    final key = _key;
    Future<void>.microtask(() => _ctl.enter(key));
  }

  void _leave(String key) {
    if (!_entered) return;
    _entered = false;
    Future<void>.microtask(() => _ctl.leave(key));
  }

  Future<void> _askKeepAutoplay() async {
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSColors.lacquer,
        title: Text('Tự phát lời kể?', style: VSType.body),
        content: Text(
          'Lần sau vào một trang mới, Long Ký có tự đọc lời kể không? '
          'Bạn có thể đổi lại trong Sảnh.',
          style: VSType.bodySmall,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tắt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Giữ'),
          ),
        ],
      ),
    );
    // Dismissing the dialog counts as keeping the default.
    await _ctl.answerAutoplay(keep ?? true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Lang>(langProvider, (prev, next) {
      if (next == Lang.vi) {
        if (!_entered) _enter();
      } else {
        _leave(_key);
      }
    });
    ref.listen<bool>(narrationProvider.select((s) => s.askPending),
        (prev, ask) {
      if (ask) _askKeepAutoplay();
    });
    final s = ref.watch(narrationProvider);
    if (ref.watch(langProvider) != Lang.vi || s.key != _key || s.failed) {
      return const SizedBox.shrink();
    }
    const size = 34.0;
    return Semantics(
      button: true,
      label: s.playing ? 'Tạm dừng lời kể' : 'Nghe lời kể',
      child: GestureDetector(
        key: const Key('narration-button'),
        behavior: HitTestBehavior.opaque,
        onTap: _ctl.toggle,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSColors.lacquer.withValues(alpha: 0.4),
                  border: Border.all(
                      color: VSColors.inkPrimary.withValues(alpha: 0.28)),
                ),
                child: s.loading
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: VSColors.gold),
                      )
                    : Icon(s.playing ? Icons.pause : Icons.play_arrow,
                        size: size * 0.5, color: VSColors.inkPrimary),
              ),
              if (s.playing || s.progress > 0)
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: s.progress,
                    strokeWidth: 2,
                    color: VSColors.goldBright,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
