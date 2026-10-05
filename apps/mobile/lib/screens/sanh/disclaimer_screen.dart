import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../feedback/feedback.dart';
import '../../state/providers.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';

/// The disclaimer page's route.
const String kDisclaimerRoute = '/luu-y';

class _Note {
  const _Note(this.headingVi, this.headingEn, this.vi, this.en);
  final String headingVi;
  final String headingEn;
  final String vi;
  final String en;
}

const List<_Note> _notes = <_Note>[
  _Note(
    'Nhiều hình ảnh được tạo bằng AI',
    'Many images are made with AI',
    'Chân dung và cảnh về những người sống trước thời có nhiếp ảnh là tranh '
        'minh họa do AI tạo ra theo phong cách sơn mài. Tranh dựa trên những '
        'gì sử sách mô tả và không phải chân dung thật: không còn bức chân '
        'dung nào của những người này được lưu lại.',
    'Portraits and scenes of people from before photography are AI-generated '
        'illustrations in a lacquer-painting style. They are based on what '
        'the chronicles describe, and are not real likenesses: no portrait of '
        'these people survives.',
  ),
  _Note(
    'Ảnh tư liệu được phục chế với sự hỗ trợ của AI',
    'Archival photographs are restored with AI help',
    'Với những người từng được chụp ảnh, chúng tôi bắt đầu từ một bức ảnh '
        'thật. Màu sắc, độ nét, khung hình và phông nền được dựng lại, nên '
        'một số chi tiết có thể khác ảnh gốc. Khi ảnh quá hư hại để phục chế '
        'trung thực, chúng tôi để trống chân dung thay vì tự tạo ra một gương '
        'mặt.',
    'For people who were photographed, we start from a real photo. Colour, '
        'sharpness, framing and the background are reconstructed, so details '
        'may differ from the original. Where a photo was too damaged to '
        'restore faithfully, we show a blank portrait instead of inventing a '
        'face.',
  ),
  _Note(
    'Nội dung theo nguồn sử liệu được dẫn',
    'The text follows the cited sources',
    'Nội dung bám theo các nguồn được ghi ở cuối mỗi trang (xem mục Nguồn sử '
        'liệu trong Về Long Ký), nhưng vẫn có thể có sai sót.',
    'The text follows the sources cited at the foot of each page (see '
        'Sources in About Long Ký), but mistakes are possible.',
  ),
];

/// "Lưu ý về hình ảnh & nội dung" — how the images are made and how to report
/// a mistake. Reached from the Sảnh, the About page and the ⓘ beside an image
/// caption; never shown as a pop-up.
class DisclaimerScreen extends ConsumerWidget {
  const DisclaimerScreen({super.key});

  static const String titleVi = 'Lưu ý về hình ảnh & nội dung';
  static const String titleEn = 'About images & content';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              VSSpacing.screenEdge, VSSpacing.sm, VSSpacing.screenEdge, 48),
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleIconButton(
                  icon: Icons.arrow_back,
                  size: 34,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/sanh'),
                ),
                const Spacer(),
                const LangToggle(),
              ],
            ),
            const SizedBox(height: VSSpacing.xl),
            Text(en ? titleEn : titleVi, style: VSType.headline),
            const SizedBox(height: VSSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 40, height: 1, color: VSColors.goldBorder),
            ),
            for (final n in _notes) ...<Widget>[
              const SizedBox(height: VSSpacing.xl),
              Text(en ? n.headingEn : n.headingVi,
                  style: VSType.cardTitle.copyWith(color: VSColors.goldBright)),
              const SizedBox(height: VSSpacing.sm),
              Text(en ? n.en : n.vi, style: VSType.body),
            ],
            const SizedBox(height: VSSpacing.xl),
            Text(en ? 'Seen something wrong?' : 'Thấy điều gì chưa đúng?',
                style: VSType.cardTitle.copyWith(color: VSColors.goldBright)),
            const SizedBox(height: VSSpacing.sm),
            Text(
              en
                  ? 'Tap “Report a mistake” (the flag at the top of that page), '
                      'or email us:'
                  : 'Bấm “Báo sai sót” (lá cờ nhỏ ở đầu trang đó), hoặc gửi '
                      'email cho chúng tôi:',
              style: VSType.body,
            ),
            InkWell(
              key: const Key('disclaimer-email'),
              onTap: () => _email(context, ref, en),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: VSSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(kFeedbackEmail,
                          style:
                              VSType.body.copyWith(color: VSColors.goldBright)),
                    ),
                    const Icon(Icons.mail_outline,
                        size: 16, color: VSColors.gold),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _email(BuildContext context, WidgetRef ref, bool en) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await ref.read(urlOpenerProvider)(
          Uri(scheme: 'mailto', path: kFeedbackEmail));
    } catch (_) {}
    if (!opened) {
      messenger.showSnackBar(SnackBar(
        content: Text(en
            ? "Couldn't open a mail app. Address: $kFeedbackEmail"
            : 'Không mở được ứng dụng email. Địa chỉ: $kFeedbackEmail'),
      ));
    }
  }
}

/// The small ⓘ beside an image caption, leading to the disclaimer page.
class DisclaimerInfoButton extends ConsumerWidget {
  const DisclaimerInfoButton({super.key});

  static const Key buttonKey = Key('caption-disclaimer-info');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final en = ref.watch(langProvider) == Lang.en;
    return Semantics(
      button: true,
      label: en ? DisclaimerScreen.titleEn : DisclaimerScreen.titleVi,
      excludeSemantics: true,
      child: GestureDetector(
        key: buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(kDisclaimerRoute),
        // Padding widens the tap target well past the 14px glyph.
        child: const Padding(
          padding: EdgeInsets.all(VSSpacing.sm),
          child: Icon(Icons.info_outline, size: 14, color: VSColors.gold),
        ),
      ),
    );
  }
}
