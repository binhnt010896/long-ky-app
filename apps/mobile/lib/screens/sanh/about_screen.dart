import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/content_sync.dart';
import '../../state/providers.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';

/// App version shown on the About page (mirrors pubspec `version`).
const String kAppVersion = '1.0.0';

/// A paragraph as segments; `true` marks the title of a cited work, which is
/// highlighted.
typedef _Para = List<(String, bool)>;

class _Section {
  const _Section(this.headingVi, this.headingEn, this.vi, this.en);
  final String headingVi;
  final String headingEn;
  final _Para vi;
  final _Para en;
}

const List<_Section> _sections = <_Section>[
  _Section('LONG KÝ', 'LONG KÝ', <(String, bool)>[
    ('Long Ký kể lại nghìn năm sử Việt qua từng kỷ nguyên, sự kiện và nhân '
        'vật, để lịch sử dân tộc được đọc như một câu chuyện liền mạch, từ '
        'thuở dựng nước đến hôm nay.', false),
  ], <(String, bool)>[
    ('Long Ký retells a thousand years of Vietnamese history, era by era, '
        'event by event, figure by figure, so the nation’s story reads as one '
        'continuous chronicle, from its founding to the present day.', false),
  ]),
  _Section('NGUỒN SỬ LIỆU', 'SOURCES', <(String, bool)>[
    ('Từ thời dựng nước đến thời Nam – Bắc triều, Long Ký bám sát ', false),
    ('Đại Việt sử ký toàn thư', true),
    ('. Thời Tây Sơn và nhà Nguyễn dựa trên các bộ sử của Quốc sử quán triều '
        'Nguyễn, trước hết là ', false),
    ('Đại Nam thực lục', true),
    ('. Các kỷ nguyên cận hiện đại dựa trên các công trình chính thống: bộ ',
        false),
    ('Lịch sử Việt Nam', true),
    (' của Viện Sử học, ', false),
    ('Lịch sử Đảng Cộng sản Việt Nam', true),
    (', ', false),
    ('Lịch sử Quân đội nhân dân Việt Nam', true),
    (' và ', false),
    ('Hồ Chí Minh Toàn tập', true),
    ('. Chi tiết truyền thuyết, dân gian luôn được ghi rõ là truyền thuyết, '
        'không gán cho chính sử. Mỗi sự kiện đều ghi nguồn ở cuối trang.',
        false),
  ], <(String, bool)>[
    ('From the founding to the Southern and Northern Dynasties, Long Ký '
        'follows the ', false),
    ('Đại Việt sử ký toàn thư', true),
    ('. The Tây Sơn and Nguyễn eras draw on the histories of the Nguyễn '
        'National History Office, above all the ', false),
    ('Đại Nam thực lục', true),
    ('. The modern eras draw on official works: the Institute of History’s ',
        false),
    ('Lịch sử Việt Nam', true),
    (', the ', false),
    ('History of the Communist Party of Vietnam', true),
    (', the ', false),
    ('History of the Vietnam People’s Army', true),
    (', and the ', false),
    ('Complete Works of Hồ Chí Minh', true),
    ('. Legendary and folk details are always marked as legend, never '
        'attributed to the chronicles. Every event cites its source at the '
        'foot of the page.', false),
  ]),
  _Section('HÌNH ẢNH', 'IMAGES', <(String, bool)>[
    ('Tranh theo phong cách sơn mài là tranh minh họa, không phải tư liệu. Ảnh '
        'tư liệu thời cận hiện đại được phục chế màu, giữ nguyên gương mặt và '
        'chi tiết của ảnh gốc.', false),
  ], <(String, bool)>[
    ('Lacquer-style paintings are illustrations, not historical records. '
        'Modern archival photographs are colour-restored, keeping the faces '
        'and details of the originals.', false),
  ]),
  _Section('MIỄN PHÍ, KHÔNG QUẢNG CÁO', 'FREE, NO ADS', <(String, bool)>[
    ('Long Ký là ứng dụng miễn phí do người Việt, vì người Việt và sẽ không '
        'bao giờ có quảng cáo.', false),
  ], <(String, bool)>[
    ('Long Ký is a free app, made by Vietnamese people for Vietnamese people, '
        'and it will never carry ads.', false),
  ]),
];

/// Về Long Ký — mission, sources, the art/photo note, and the version.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final en = ref.watch(langProvider) == Lang.en;
    final version = ref.watch(activeContentVersionProvider);
    final work = VSType.body.copyWith(
      color: VSColors.goldBright,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
    );

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
            Text(en ? 'About Long Ký' : 'Về Long Ký', style: VSType.headline),
            const SizedBox(height: VSSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 40, height: 1, color: VSColors.goldBorder),
            ),
            for (final s in _sections) ...<Widget>[
              const SizedBox(height: VSSpacing.xl),
              Text(en ? s.headingEn : s.headingVi, style: VSType.overline),
              const SizedBox(height: VSSpacing.sm),
              Text.rich(
                TextSpan(
                  style: VSType.body,
                  children: <InlineSpan>[
                    for (final (text, isWork) in en ? s.en : s.vi)
                      TextSpan(text: text, style: isWork ? work : null),
                  ],
                ),
              ),
            ],
            const SizedBox(height: VSSpacing.xl),
            Text(en ? 'VERSION' : 'PHIÊN BẢN', style: VSType.overline),
            const SizedBox(height: VSSpacing.sm),
            Text(
              en
                  ? 'Content: version $version · App: $kAppVersion'
                  : 'Nội dung: bản $version · Ứng dụng: $kAppVersion',
              style: VSType.body,
            ),
          ],
        ),
      ),
    );
  }
}
