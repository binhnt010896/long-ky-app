import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ui_kit/ui_kit.dart';

import '../screens/sanh/about_screen.dart' show kAppVersion;
import '../state/content_sync.dart';
import '../state/providers.dart';
import '../telemetry/telemetry.dart';
import '../widgets/circle_icon_button.dart';

/// The inbox for reader feedback. The disclaimer page shows it as a contact
/// address; the "Báo sai sót" sheet never uses it — reports go through
/// [kFeedbackApiUrl], whose server holds the destination.
const String kFeedbackEmail = 'help@long-ky.com';

/// What the reader says looks wrong.
enum FeedbackKind {
  image('Hình ảnh', 'Image'),
  text('Nội dung', 'Text'),
  other('Khác', 'Other');

  const FeedbackKind(this.vi, this.en);
  final String vi;
  final String en;

  String label(Lang lang) => lang == Lang.en ? en : vi;
}

/// The detail page a report is about: enough to find the item in the CMS.
@immutable
class FeedbackTarget {
  const FeedbackTarget({
    required this.type,
    required this.id,
    required this.title,
    required this.route,
  });

  /// `event` or `person`.
  final String type;
  final String id;

  /// The item's Vietnamese title (canonical, whatever the reader's language).
  final String title;

  /// The page's route, e.g. `/era/nha-tran/event/<id>`.
  final String route;
}

/// Everything about the app the report carries besides the reader's words.
@immutable
class FeedbackContext {
  const FeedbackContext({
    required this.contentVersion,
    required this.appVersion,
    required this.platform,
    required this.lang,
  });

  final int contentVersion;
  final String appVersion;
  final String platform;
  final Lang lang;
}

/// `web`, `android`, `ios`… — the platform name for a report.
String feedbackPlatform() => kIsWeb ? 'web' : defaultTargetPlatform.name;

/// `[Long Ký] Báo sai sót: <title> (<event|person> <id>)`.
String feedbackSubject(FeedbackTarget target) =>
    '[Long Ký] Báo sai sót: ${target.title} (${target.type} ${target.id})';

/// The prepared message: the reader's choice and note, then the page and
/// version details. Labels follow the reader's language.
String feedbackBody({
  required FeedbackTarget target,
  required FeedbackContext ctx,
  required FeedbackKind kind,
  String note = '',
}) {
  final en = ctx.lang == Lang.en;
  final trimmed = note.trim();
  return <String>[
    '${en ? 'What looks wrong' : 'Sai ở đâu'}: ${kind.label(ctx.lang)}',
    '${en ? 'Note' : 'Ghi chú'}: ${trimmed.isEmpty ? '-' : trimmed}',
    '',
    '---',
    '${en ? 'Page' : 'Trang'}: ${target.route}',
    '${en ? 'Content version' : 'Bản nội dung'}: ${ctx.contentVersion}',
    '${en ? 'App' : 'Ứng dụng'}: ${ctx.appVersion} (${ctx.platform})',
    '${en ? 'Language' : 'Ngôn ngữ'}: ${ctx.lang.name}',
  ].join('\n');
}

/// Where reports are posted. `services/feedback_api` emails them from
/// admin@long-ky.com to [kFeedbackEmail], so the reader never supplies an
/// address. Override per build with `--dart-define=FEEDBACK_API_URL=https://…`.
const String kFeedbackApiUrl = String.fromEnvironment(
  'FEEDBACK_API_URL',
  defaultValue: 'https://feedback.long-ky.com/feedback',
);

/// Posts one report; true once the server has sent it. A seam so tests never
/// touch the network.
final feedbackSenderProvider =
    Provider<Future<bool> Function(String subject, String body)>(
        (ref) => (subject, body) async {
              final res = await http
                  .post(
                    Uri.parse(kFeedbackApiUrl),
                    headers: const <String, String>{
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode(
                        <String, String>{'subject': subject, 'body': body}),
                  )
                  .timeout(const Duration(seconds: 15));
              return res.statusCode >= 200 && res.statusCode < 300;
            });

/// The quiet "Báo sai sót" button for a detail page's top bar.
class FeedbackButton extends ConsumerWidget {
  const FeedbackButton({required this.target, super.key});

  final FeedbackTarget target;

  static const Key buttonKey = Key('feedback-button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final en = ref.watch(langProvider) == Lang.en;
    return Semantics(
      button: true,
      label: en ? 'Report a mistake' : 'Báo sai sót',
      excludeSemantics: true,
      child: CircleIconButton(
        key: buttonKey,
        icon: Icons.outlined_flag,
        onTap: () => showFeedbackSheet(context, ref, target),
      ),
    );
  }
}

/// Opens the "What looks wrong?" sheet for [target].
Future<void> showFeedbackSheet(
    BuildContext context, WidgetRef ref, FeedbackTarget target) {
  ref.read(telemetryProvider).event('feedback_opened', <String, Object>{
    'type': target.type,
    'id': target.id,
  });
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VSColors.lacquerRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: VSRadii.card),
      side: BorderSide(color: VSColors.goldBorder),
    ),
    builder: (_) => FeedbackSheet(target: target),
  );
}

/// Pick what looks wrong, add an optional note, and send it. The report is
/// emailed by our server, so the reader needs no mail app and gives no address.
class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({required this.target, super.key});

  final FeedbackTarget target;

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final TextEditingController _note = TextEditingController();
  FeedbackKind? _kind;

  bool _sending = false;

  /// The last send failed; the form stays so the reader can try again.
  bool _failed = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send(Lang lang) async {
    final kind = _kind;
    if (kind == null) return;
    final ctx = FeedbackContext(
      contentVersion: ref.read(activeContentVersionProvider),
      appVersion: kAppVersion,
      platform: feedbackPlatform(),
      lang: lang,
    );
    final subject = feedbackSubject(widget.target);
    final body = feedbackBody(
        target: widget.target, ctx: ctx, kind: kind, note: _note.text);
    setState(() {
      _sending = true;
      _failed = false;
    });
    var sent = false;
    try {
      sent = await ref.read(feedbackSenderProvider)(subject, body);
    } catch (_) {}
    if (!mounted) return;
    if (sent) {
      ref.read(telemetryProvider).event('feedback_sent', <String, Object>{
        'type': widget.target.type,
        'id': widget.target.id,
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(
            lang == Lang.en ? 'Thanks, report sent' : 'Đã gửi, cảm ơn bạn'),
      ));
      Navigator.of(context).pop();
    } else {
      setState(() {
        _sending = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _form(lang, en),
          ),
        ),
      ),
    );
  }

  List<Widget> _form(Lang lang, bool en) {
    return <Widget>[
      Text(
        en ? 'Report a mistake' : 'Báo sai sót',
        style: VSType.title.copyWith(color: VSColors.goldBright, fontSize: 18),
      ),
      const SizedBox(height: VSSpacing.xxs),
      Text(
        en ? 'What looks wrong?' : 'Bạn thấy sai ở đâu?',
        style: VSType.caption.copyWith(color: VSColors.inkMuted),
      ),
      const SizedBox(height: VSSpacing.md),
      Wrap(
        spacing: VSSpacing.sm,
        runSpacing: VSSpacing.sm,
        children: <Widget>[
          for (final k in FeedbackKind.values)
            ChoiceChip(
              key: ValueKey<String>('feedback-kind-${k.name}'),
              label: Text(k.label(lang)),
              selected: _kind == k,
              onSelected: (_) => setState(() => _kind = k),
              selectedColor: VSColors.gold.withValues(alpha: 0.22),
              backgroundColor: VSColors.lacquer,
              side: const BorderSide(color: VSColors.goldBorder),
              labelStyle: VSType.label.copyWith(
                color: _kind == k ? VSColors.goldBright : VSColors.inkSecondary,
              ),
              showCheckmark: false,
            ),
        ],
      ),
      const SizedBox(height: VSSpacing.md),
      TextField(
        key: const Key('feedback-note'),
        controller: _note,
        minLines: 2,
        maxLines: 5,
        maxLength: 1000,
        style: VSType.body,
        decoration: InputDecoration(
          hintText: en ? 'Add a note (optional)' : 'Thêm ghi chú (không bắt buộc)',
          hintStyle: VSType.body.copyWith(color: VSColors.inkFaint),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: VSColors.goldBorder),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: VSColors.gold),
          ),
        ),
      ),
      if (_failed) ...<Widget>[
        const SizedBox(height: VSSpacing.sm),
        Text(
          key: const Key('feedback-error'),
          en
              ? "Couldn't send. Check your connection and try again."
              : 'Không gửi được. Hãy kiểm tra kết nối và thử lại.',
          style: VSType.bodySmall.copyWith(color: VSColors.inkMuted),
        ),
      ],
      const SizedBox(height: VSSpacing.sm),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const Key('feedback-send'),
          onPressed: _kind == null || _sending ? null : () => _send(lang),
          icon: Icon(Icons.send_outlined,
              size: 18,
              color: _kind == null || _sending
                  ? VSColors.inkFaint
                  : VSColors.goldBright),
          label: Text(
            _sending
                ? (en ? 'Sending…' : 'Đang gửi…')
                : (en ? 'Send' : 'Gửi'),
            style: VSType.label.copyWith(
              color: _kind == null || _sending
                  ? VSColors.inkFaint
                  : VSColors.goldBright,
            ),
          ),
        ),
      ),
    ];
  }
}
