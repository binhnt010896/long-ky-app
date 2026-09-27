"""VI -> EN translations for the territory atlas's region/snapshot labels.

Shared by `gen_atlas.py` (a future regeneration against the Natural Earth
source) and the one-off `patch_atlas_i18n.py` (applied directly to the already
generated `territory_atlas_data.dart`, since the ne10m source file and
`shapely` aren't available in every environment this runs in). No external
dependencies, so both scripts can import it freely.

Translation rules (Cycle J, decision J2):
  - Vietnamese states/kingdoms keep their Vietnamese proper name, with
    diacritics (Văn Lang, Đại Việt, Đàng Trong, …) — this matches how
    `content/*.json`'s own `en` fields already translate era/period titles
    (e.g. "Nhà Trần" -> "The Trần Dynasty", not "the Chen dynasty").
  - Foreign dynasties/polities get their English name (Han, Tang, Song, Yuan,
    Ming, Qing; Champa, Chenla, Funan, Siam, Burma, Laos, Cambodia).
  - Vietnam's own official state names use their standard English form
    (Việt Nam -> Vietnam; Cộng hòa xã hội chủ nghĩa Việt Nam -> Socialist
    Republic of Vietnam) — this is the accepted English exonym, unlike the
    South China Sea islands (handled separately, kept Vietnamese in the app
    chrome — see [[modern-era-sourcing-gov-pov]]).
  - Everything else (captions, event subtitles) is translated in full.
"""

TRANSLATIONS = {
    'Ai Lao': 'Laos',
    'An Dương Vương': 'An Dương Vương',
    'An Nam đô hộ phủ': 'Protectorate of Annam',
    'Bắc thuộc': 'Chinese Domination',
    'Bắc thuộc (Đông Ngô)': 'Chinese Domination (Eastern Wu)',
    'Bắc triều': 'Northern Court',
    'Campuchia': 'Cambodia',
    'Cao Miên': 'Cambodia',
    'Chiêm Thành': 'Champa',
    'Chân Lạp': 'Chenla',
    'Chăm Pa': 'Champa',
    'Cộng hòa xã hội chủ nghĩa Việt Nam': 'Socialist Republic of Vietnam',
    'Gia Long': 'Gia Long',
    'Gia Long thống nhất': 'Gia Long unifies the country',
    'Gia Định': 'Gia Định',
    'Giao Châu': 'Giao Châu',
    'Giới tuyến quân sự tạm thời (vĩ tuyến 17)':
        'Provisional military demarcation line (17th parallel)',
    'Hai miền chia cắt': 'A country divided in two',
    'Họ Khúc': 'The Khúc clan',
    'Hồng Bàng': 'Hồng Bàng',
    'Hồng Đức': 'Hồng Đức',
    'Khmer': 'Khmer',
    'Kháng chiến chống Mỹ': 'The Resistance War Against America',
    'Kháng chiến chống Pháp': 'The Resistance War Against France',
    'Khúc Thừa Dụ': 'Khúc Thừa Dụ',
    'Khởi nghĩa Bà Triệu': 'The Lady Triệu Uprising',
    'Khởi nghĩa Hai Bà Trưng': 'The Trưng Sisters Uprising',
    'Liên bang Đông Dương': 'The Indochinese Union',
    'Lâm Ấp': 'Lâm Ấp',
    'Lê Lợi': 'Lê Lợi',
    'Lê Thái Tổ': 'Lê Thái Tổ',
    'Lê Thánh Tông': 'Lê Thánh Tông',
    'Lê sơ': 'Early Lê',
    'Lê Đại Hành': 'Lê Đại Hành',
    'Lê – Trịnh': 'Lê – Trịnh',
    'Lý Nam Đế': 'Lý Nam Đế',
    'Minh Mạng': 'Minh Mạng',
    'Miến Điện': 'Burma',
    'Miền Bắc': 'The North',
    'Miền Nam': 'The South',
    'Mê Linh': 'Mê Linh',
    'Mạc vs Lê–Trịnh': 'Mạc vs Lê–Trịnh',
    'Nam Hán': 'Southern Han',
    'Nam Kỳ': 'Nam Kỳ',
    'Nam Việt': 'Nam Việt',
    'Nam triều': 'Southern Court',
    'Nam – Bắc triều': 'Northern & Southern Courts',
    'Nguyễn Huệ': 'Nguyễn Huệ',
    'Nguyễn Huệ vs Nguyễn Ánh': 'Nguyễn Huệ vs Nguyễn Ánh',
    'Nguyễn bảo hộ': 'Nguyễn protectorate',
    'Nguyễn Ánh': 'Nguyễn Ánh',
    'Ngô Quyền': 'Ngô Quyền',
    'Nhà Hán': 'The Han Dynasty',
    'Nhà Lý': 'The Lý Dynasty',
    'Nhà Lương': 'The Liang Dynasty',
    'Nhà Minh': 'The Ming Dynasty',
    'Nhà Mạc': 'The Mạc Dynasty',
    'Nhà Nguyên': 'The Yuan Dynasty',
    'Nhà Nguyễn': 'The Nguyễn Dynasty',
    'Nhà Ngô': 'The Ngô Dynasty',
    'Nhà Thanh': 'The Qing Dynasty',
    'Nhà Triệu': 'The Triệu Dynasty',
    'Nhà Trần': 'The Trần Dynasty',
    'Nhà Tống': 'The Song Dynasty',
    'Nhà Đinh': 'The Đinh Dynasty',
    'Nhà Đường': 'The Tang Dynasty',
    'Nhà Đường đô hộ': 'Tang domination',
    'Nhật Nam': 'Nhật Nam',
    'Panduranga': 'Panduranga',
    'Pháp bảo hộ': 'French protectorate',
    'Pháp chiếm Nam Kỳ': 'France seizes Nam Kỳ',
    'Pháp thuộc': 'French Rule',
    'Phù Nam': 'Funan',
    'Sông Gianh': 'Sông Gianh',
    'Thiệu Trị': 'Thiệu Trị',
    'Thuộc địa Pháp': 'French colony',
    'Thống nhất': 'Reunification',
    'Tiền Lê': 'Tiền Lê',
    'Triệu Đà · Lưỡng Quảng': 'Triệu Đà · Lưỡng Quảng',
    'Trung Quốc': 'China',
    'Trung – Bắc Kỳ': 'Trung – Bắc Kỳ',
    'Trưng Vương': 'Trưng Vương',
    'Trấn Tây · Ai Lao': 'Trấn Tây · Laos',
    'Trịnh – Nguyễn': 'Trịnh – Nguyễn',
    'Tây Sơn': 'Tây Sơn',
    'Tĩnh Hải quân': 'Tĩnh Hải quân',
    'Tự chủ': 'Self-Rule',
    'Tự Đức': 'Tự Đức',
    'Việt Nam': 'Vietnam',
    'Việt Nam Cộng hoà': 'Republic of Vietnam',
    'Việt Nam Dân chủ Cộng hòa': 'Democratic Republic of Vietnam',
    'Vua Hùng': 'The Hùng Kings',
    'Văn Lang': 'Văn Lang',
    'Vạn Xuân': 'Vạn Xuân',
    'Xiêm': 'Siam',
    'chúa Nguyễn': 'Nguyễn lords',
    'vua Lê · chúa Trịnh': 'Lê kings · Trịnh lords',
    'Âu Lạc': 'Âu Lạc',
    'Đinh Tiên Hoàng': 'Đinh Tiên Hoàng',
    'Đàng Ngoài': 'Đàng Ngoài',
    'Đàng Ngoài & Đàng Trong': 'Đàng Ngoài & Đàng Trong',
    'Đàng Trong': 'Đàng Trong',
    'Đông Ngô': 'Eastern Wu',
    'Đại Cồ Việt': 'Đại Cồ Việt',
    'Đại Nam': 'Đại Nam',
    'Đại Nam cực thịnh': 'Đại Nam at its height',
    'Đại Việt': 'Đại Việt',
    'Đế quốc Khmer': 'Khmer Empire',
    'Độc lập · kháng chiến': 'Independence · resistance',
}


def translate(vi: str) -> str:
    """English for a Vietnamese atlas label. Raises if the string is unknown —
    a new region/snapshot label added to `gen_atlas.py` without its English
    counterpart here should fail loudly, not ship Vietnamese-only."""
    try:
        return TRANSLATIONS[vi]
    except KeyError:
        raise KeyError(
            f'No English translation for atlas label {vi!r} — add it to '
            'tool/geo/atlas_i18n.py.') from None
