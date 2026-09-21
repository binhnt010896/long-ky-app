import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../widgets/circle_icon_button.dart';

/// One karaoke line: the second into the anthem at which it becomes current.
class AnthemLine {
  const AnthemLine(this.at, this.text);
  final double at; // seconds
  final String text;
}

/// "Chào cờ" — an online flag salute: the waving national flag, the anthem
/// (Tiến quân ca) with simple transport controls, and karaoke lyrics that
/// highlight and auto-scroll as the song plays. Assets are bundled under
/// assets/content/chao-co/. Line timings are approximate and easy to tune.
class ChaoCoScreen extends StatefulWidget {
  const ChaoCoScreen({super.key});

  static const String flagAsset = 'assets/content/chao-co/quoc-ky.gif';
  static const String audioAsset = 'assets/content/chao-co/tien-quan-ca.mp3';
  static const String backgroundAsset =
      'assets/content/chao-co/background.png';

  // Tiến quân ca, lời 1 (Quốc ca nước Cộng hòa xã hội chủ nghĩa Việt Nam).
  // Timings hand-calibrated to the bundled recording via the tap-to-sync tool
  // (the tune icon in the header). A line's `at` is the second it becomes
  // current.
  static const List<AnthemLine> lyrics = <AnthemLine>[
    AnthemLine(1.9, 'Đoàn quân Việt Nam đi'),
    AnthemLine(5.2, 'Chung lòng cứu quốc'),
    AnthemLine(8.2, 'Bước chân dồn vang trên đường gập ghềnh xa'),
    AnthemLine(13.2, 'Cờ in máu chiến thắng mang hồn nước'),
    AnthemLine(18.9, 'Súng ngoài xa chen khúc quân hành ca'),
    AnthemLine(24.6, 'Đường vinh quang xây xác quân thù'),
    AnthemLine(30.4, 'Thắng gian lao cùng nhau lập chiến khu'),
    AnthemLine(36.2, 'Vì nhân dân chiến đấu không ngừng'),
    AnthemLine(41.8, 'Tiến mau ra sa trường'),
    AnthemLine(46.1, 'Tiến lên! Cùng tiến lên!'),
    AnthemLine(53.7, 'Nước non Việt Nam ta vững bền'),
  ];

  @override
  State<ChaoCoScreen> createState() => _ChaoCoScreenState();
}

class _ChaoCoScreenState extends State<ChaoCoScreen> {
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _lyricsCtrl = ScrollController();
  final List<GlobalKey> _lineKeys =
      List<GlobalKey>.generate(ChaoCoScreen.lyrics.length, (_) => GlobalKey());

  bool _ready = false;
  bool _failed = false;
  int _current = -1;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<ProcessingState>? _stateSub;

  // Calibration mode: play the anthem and tap once as each line begins; the
  // captured seconds are printed as an AnthemLine list to paste back.
  bool _calib = false;
  double _posSec = 0;
  final List<double> _caps = <double>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setAsset(ChaoCoScreen.audioAsset);
      _posSub = _player.positionStream.listen(_onPosition);
      // When the anthem finishes, just_audio leaves the player parked at the
      // end in the "completed" state, where a plain play() is a no-op. Reset it
      // to a clean ready-at-zero so the Play button restarts the song.
      _stateSub = _player.processingStateStream.listen((s) async {
        if (s == ProcessingState.completed) {
          await _player.pause();
          await _player.seek(Duration.zero);
          if (mounted) setState(() => _current = -1);
        }
      });
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onPosition(Duration pos) {
    final s = pos.inMilliseconds / 1000.0;
    // In calibration mode the highlight is driven by the user's taps, not the
    // clock; we still track the live position for the readout.
    if (_calib) {
      setState(() => _posSec = s);
      return;
    }
    var idx = -1;
    for (var i = 0; i < ChaoCoScreen.lyrics.length; i++) {
      if (ChaoCoScreen.lyrics[i].at <= s) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _current || s != _posSec) {
      setState(() {
        _current = idx;
        _posSec = s;
      });
      if (idx != _current) _scrollToCurrent();
    }
  }

  // Records the current playback time for the next line and advances.
  void _tapLine() {
    if (_caps.length >= ChaoCoScreen.lyrics.length) return;
    setState(() {
      _caps.add(double.parse(_posSec.toStringAsFixed(2)));
      _current = _caps.length - 1;
    });
    _scrollToCurrent();
  }

  void _resetCalib() => setState(() {
        _caps.clear();
        _current = -1;
      });

  String _capsList() {
    final b = StringBuffer();
    for (var i = 0; i < ChaoCoScreen.lyrics.length; i++) {
      final t = i < _caps.length ? _caps[i].toStringAsFixed(1) : '?';
      b.writeln("AnthemLine($t, '${ChaoCoScreen.lyrics[i].text}'),");
    }
    return b.toString();
  }

  void _scrollToCurrent() {
    if (_current < 0) return;
    final ctx = _lineKeys[_current].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          alignment: 0.5,
          curve: Curves.easeInOut);
    }
  }

  Future<void> _restart() async {
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> _stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    if (mounted) setState(() => _current = -1);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _lyricsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Solemn backdrop: a bundled image dimmed by a black overlay.
          Image.asset(
            ChaoCoScreen.backgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: VSColors.lacquer),
          ),
          Container(color: Colors.black.withValues(alpha: 0.5)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  VSSpacing.xl, VSSpacing.sm, VSSpacing.xl, 0),
              child: Row(
                children: <Widget>[
                  Builder(
                    builder: (context) => CircleIconButton(
                      icon: Icons.arrow_back,
                      onTap: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                  ),
                  const SizedBox(width: VSSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('CHÀO CỜ',
                          style: VSType.overline.copyWith(
                            color: VSColors.goldBright,
                            letterSpacing: VSType.track(0.3, 10),
                            fontSize: 10,
                          )),
                      const SizedBox(height: 2),
                      Text('Tiến quân ca',
                          style: VSType.title.copyWith(fontSize: 18)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _calib = !_calib;
                      _resetCalib();
                    }),
                    child: Icon(_calib ? Icons.close : Icons.tune,
                        color: _calib ? VSColors.goldBright : VSColors.gold,
                        size: 22),
                  ),
                ],
              ),
            ),
            // Waving flag.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  VSSpacing.xl, VSSpacing.lg, VSSpacing.xl, VSSpacing.md),
              child: ClipRRect(
                borderRadius: VSRadii.cardAll,
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: Image.asset(
                    ChaoCoScreen.flagAsset,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFB01E1E),
                      child: Center(
                        child: Icon(Icons.star,
                            color: Color(0xFFFFD200), size: 72),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Transport controls (icon-only).
            _Controls(
              player: _player,
              ready: _ready,
              failed: _failed,
              onRestart: _restart,
              onStop: _stop,
            ),
            const SizedBox(height: VSSpacing.sm),
            // Calibration panel: play the anthem, tap TAP as each line begins.
            if (_calib)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    VSSpacing.xl, 0, VSSpacing.xl, VSSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    GestureDetector(
                      onTap: _tapLine,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: VSRadii.cardAll,
                          color: VSColors.gold.withValues(alpha: 0.18),
                          border: Border.all(color: VSColors.goldBright),
                        ),
                        child: Text(
                          'TAP  ·  ${_posSec.toStringAsFixed(1)}s'
                          '  ·  ${_caps.length}/${ChaoCoScreen.lyrics.length}',
                          textAlign: TextAlign.center,
                          style: VSType.title.copyWith(
                              color: VSColors.goldBright, fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: VSSpacing.xs),
                    Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: _resetCalib,
                          child: const Text('Reset',
                              style: TextStyle(color: VSColors.gold)),
                        ),
                        const Spacer(),
                        Text('Tap as each line starts, then copy below',
                            style: VSType.body.copyWith(
                                color: VSColors.inkMuted, fontSize: 11)),
                      ],
                    ),
                    if (_caps.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: VSSpacing.xs),
                        padding: const EdgeInsets.all(VSSpacing.sm),
                        decoration: BoxDecoration(
                          borderRadius: VSRadii.cardAll,
                          color: Colors.black.withValues(alpha: 0.35),
                          border: Border.all(color: VSColors.goldBorder),
                        ),
                        child: SelectableText(
                          _capsList(),
                          style: const TextStyle(
                              color: VSColors.inkSecondary,
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
            // Karaoke lyrics.
            Expanded(
              child: SingleChildScrollView(
                controller: _lyricsCtrl,
                padding: const EdgeInsets.fromLTRB(
                    VSSpacing.xl, VSSpacing.md, VSSpacing.xl, VSSpacing.xxl),
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < ChaoCoScreen.lyrics.length; i++)
                      Padding(
                        key: _lineKeys[i],
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          textAlign: TextAlign.center,
                          style: VSType.title.copyWith(
                            fontSize: i == _current ? 20 : 17,
                            height: 1.3,
                            color: i == _current
                                ? VSColors.goldBright
                                : VSColors.inkMuted,
                            fontWeight: i == _current
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          child: Text(ChaoCoScreen.lyrics[i].text,
                              textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.player,
    required this.ready,
    required this.failed,
    required this.onRestart,
    required this.onStop,
  });

  final AudioPlayer player;
  final bool ready;
  final bool failed;
  final Future<void> Function() onRestart;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: VSSpacing.md),
        child: Text('Không tải được bản nhạc.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VSColors.inkMuted)),
      );
    }
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        final completed = snap.data?.processingState == ProcessingState.completed;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _CtrlButton(
              icon: Icons.replay,
              enabled: ready,
              onTap: onRestart,
            ),
            const SizedBox(width: VSSpacing.lg),
            _CtrlButton(
              icon: (playing && !completed) ? Icons.pause : Icons.play_arrow,
              big: true,
              enabled: ready,
              onTap: () async {
                if (completed) {
                  await onRestart();
                } else if (playing) {
                  await player.pause();
                } else {
                  await player.play();
                }
              },
            ),
            const SizedBox(width: VSSpacing.lg),
            _CtrlButton(
              icon: Icons.stop,
              enabled: ready,
              onTap: onStop,
            ),
          ],
        );
      },
    );
  }
}

class _CtrlButton extends StatelessWidget {
  const _CtrlButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final bool enabled;
  final Future<void> Function() onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 64.0 : 48.0;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? () => onTap() : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: big
                ? VSColors.gold.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
                color: big ? VSColors.goldBright : VSColors.goldBorder,
                width: big ? 1.5 : 1),
          ),
          child: Icon(icon,
              color: big ? VSColors.goldBright : VSColors.gold,
              size: big ? 34 : 24),
        ),
      ),
    );
  }
}
