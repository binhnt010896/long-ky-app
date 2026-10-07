# Street colors by period: plan (item 2)

Status: **built, tried on a phone, and reverted** · 2026-10-07

> **Outcome:** with 17 period colors the map looked like a rainbow (the owner's
> verdict on a real phone), at odds with the app's restrained lacquer look.
> Both commits were reverted (`8420fb0`, `e6d7342`). If this is ever retried:
> use few families (not one hue per period), or color only a highlighted
> period against the old gold, never all 17 at once.

## What changes

Today every street on the map is one faded gold. Each street gets the color of
the **period** its person or event belongs to, so the map reads as a timeline:
west to east, Hùng Vương to Võ Nguyên Giáp.

## Locked decisions (from you)

- Color by **period** (the 17 dynasty groups), not by each of the 38 eras.
- Colors are **map-tuned from each period's accent**, not the raw accents.

## Why not the raw accents

Measured on the map's dark ground: the 17 accents are dark (lightness 33–47 of
100), so thin lines vanish, and several pairs are near-identical
(Nhà Trần / Kháng chiến chống Mỹ, Đổi Mới / Kỷ nguyên mới, Tây Sơn / Kháng
chiến chống Pháp: all closer than 10 on a scale where ~20 is "clearly
different"). The proposed colors keep each accent's hue family (within ±24°),
lift them to a lacquer-friendly light-muted range, and nudge the clashing ones
apart. The weakest pair is now 14; the legend (below) covers the rest.

Preview, accent swatch on the left, proposed line on the right:
[street-period-palette.png](street-period-palette.png)

| Period | Accent | Map color |
|---|---|---|
| Hồng Bàng – Âu Lạc | `#5f8f74` | `#94d1b2` |
| Nhà Triệu | `#8a5a3b` | `#c8b97e` |
| Bắc thuộc & Khởi nghĩa | `#7c3b34` | `#d29a93` |
| Ngô – Đinh – Tiền Lê | `#b3532b` | `#db6b74` |
| Nhà Lý | `#b8863a` | `#dada8b` |
| Nhà Trần | `#9c3a2f` | `#dcab89` |
| Nhà Hậu Lê | `#1c7a54` | `#6adc93` |
| Nam–Bắc triều · Trịnh–Nguyễn | `#5f6b86` | `#7eb2c8` |
| Nhà Tây Sơn | `#c0392b` | `#dc6a8d` |
| Nhà Nguyễn | `#cf9b2e` | `#dca86a` |
| Pháp thuộc & Phong trào yêu nước | `#3f6d8c` | `#7ec8c8` |
| Kháng chiến chống Pháp | `#b23a2e` | `#d97d6d` |
| Kháng chiến chống Mỹ, cứu nước | `#8a2f2a` | `#db8aa6` |
| Thống nhất | `#c08a2e` | `#dc926b` |
| Chiến tranh biên giới | `#5e6b3a` | `#a9c87e` |
| Đổi Mới | `#c9a227` | `#dcbe6a` |
| Kỷ nguyên mới | `#e0b43c` | `#cddc6a` |

## The data gap: 158 of 285 streets have no era

Their person or event stands alone (no era roster), so there is nothing to take
a period from. Proposal: add an optional **`period`** to those street targets
in `content/streets/hcm.json` (one file, already hand-edited and preserved by
the street tool), validated against the real period ids. A standalone target
with no period is a validator warning and draws in the old neutral gold, so a
new street never breaks the map.

**Assignment rule used for the draft below:** take the year the person was
about 35 (or the year they died, if earlier), and pick the period containing
it; where periods overlap, the shorter one wins (so Pháp thuộc beats Nhà
Nguyễn after 1897). Events use their own year.

Rows marked ⚠ need your eye: **long-life** (a lifespan that crosses several
periods, e.g. someone who served in both wars), **overlap** (the rule had to
choose between periods), or **no dates** (I did not guess; they need a period
from you).

| Street | Person / event | Lifespan | Proposed period | |
|---|---|---|---|---|
| An Tư Công Chúa | An Tư công chúa | — | **?** | ⚠ no dates |
| Bế Văn Đàn | Bế Văn Đàn | 1931 – 1953 | Kháng chiến chống Pháp | ⚠ long-life |
| Bùi Thị Xuân | Bùi Thị Xuân | 1752 – 1802 | Nhà Tây Sơn |  |
| Bùi Viện | Bùi Viện | 1839 – 1878 | Nhà Nguyễn |  |
| Cao Bá Quát | Cao Bá Quát | ? – 1855 | Nhà Nguyễn |  |
| Cao Thắng | Cao Thắng | 1864 – 1893 | Nhà Nguyễn |  |
| Châu Văn Liêm | Châu Văn Liêm | 1902 – 1930 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Châu Vĩnh Tế | Đào kênh Vĩnh Tế | 1819 | Nhà Nguyễn |  |
| Chử Đồng Tử | Chử Đồng Tử | — | **?** | ⚠ no dates |
| Chu Văn An | Chu Văn An | 1292 – 1370 | Nhà Trần |  |
| Công chúa Ngọc Hân | Ngọc Hân | 1770 – 1799 | Nhà Tây Sơn |  |
| Cù Chính Lan | Cù Chính Lan | 1930 – 1951 | Kháng chiến chống Pháp | ⚠ long-life |
| Dã Tượng | Dã Tượng | — | **?** | ⚠ no dates |
| Đàm Thận Huy | Đàm Thận Huy | 1463 – 1526 | **?** |  |
| Đặng Dung | Đặng Dung | 1373 – 1414 | **?** |  |
| Đặng Nguyên Cẩn | Đặng Nguyên Cẩn | 1867 – 1923 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Đặng Như Mai | Đặng Như Mai | — | **?** | ⚠ no dates |
| Đặng Tất | Đặng Tất | 1357 – 1409 | Nhà Trần |  |
| Đặng Thái Thân | Đặng Thái Thân | 1874 – 1910 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Đinh Công Tráng | Đinh Công Tráng | 1842 – 1887 | Nhà Nguyễn |  |
| Đinh Lễ | Đinh Lễ | ? – 1427 | Nhà Hậu Lê |  |
| Đinh Liệt | Đinh Liệt | 1400 – 1471 | Nhà Hậu Lê |  |
| Giang Văn Minh | Giang Văn Minh | 1573 – 1638 | Nam–Bắc triều · Trịnh–Nguyễn |  |
| Hà Huy Giáp | Hà Huy Giáp | 1908 – 1995 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Hà Huy Tập | Hà Huy Tập | 1906 – 1941 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Hải Thượng Lãn Ông | Hải Thượng Lãn Ông | 1724 – 1791 | **?** |  |
| Hàn Thuyên | Hàn Thuyên | — | **?** | ⚠ no dates |
| Hồ Huấn Nghiệp | Hồ Huấn Nghiệp | 1829 – 1864 | Nhà Nguyễn |  |
| Hồ Tùng Mậu | Hồ Tùng Mậu | 1896 – 1951 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Hoàng Diệu | Hoàng Diệu | 1829 – 1882 | Nhà Nguyễn |  |
| Hoàng Kế Viêm | Hoàng Kế Viêm | 1820 – 1909 | Nhà Nguyễn |  |
| Hoàng Quốc Việt | Hoàng Quốc Việt | 1905 – 1992 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Hoàng Văn Thái | Hoàng Văn Thái | 1915 – 1986 | Kháng chiến chống Pháp | ⚠ long-life |
| Hoàng Văn Thụ | Hoàng Văn Thụ | 1909 – 1944 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Huyền Trân Công Chúa | Huyền Trân công chúa | 1287 – 1340 | Nhà Trần |  |
| Huỳnh Mẫn Đạt | Huỳnh Mẫn Đạt | 1807 – 1882 | Nhà Nguyễn |  |
| Huỳnh Tấn Phát | Huỳnh Tấn Phát | 1913 – 1989 | Kháng chiến chống Pháp | ⚠ long-life |
| Huỳnh Thúc Kháng | Huỳnh Thúc Kháng | 1876 – 1947 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Kim Đồng | Kim Đồng | 1929 – 1943 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Ký Con | Ký Con | 1908 – 1931 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Kỳ Đồng | Kỳ Đồng | 1875 – 1929 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Lê Anh Xuân | Lê Anh Xuân | 1940 – 1968 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Lê Đức Thọ | Lê Đức Thọ | 1911 – 1990 | Kháng chiến chống Pháp | ⚠ long-life |
| Lê Hồng Phong | Lê Hồng Phong | 1902 – 1942 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Lê Ngân | Lê Ngân | ? – 1437 | Nhà Hậu Lê |  |
| Lê Quang Đạo | Lê Quang Đạo | 1921 – 1999 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Lê Quang Định | Lê Quang Định | 1759 – 1813 | Nhà Tây Sơn |  |
| Lê Quý Đôn | Lê Quý Đôn | 1726 – 1784 | **?** |  |
| Lê Sát | Lê Sát | ? – 1437 | Nhà Hậu Lê |  |
| Lê Thận | Lê Thận | ? – 1448 | Nhà Hậu Lê |  |
| Lê Thị Riêng | Lê Thị Riêng | 1925 – 1968 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Lê Trung Đình | Lê Trung Đình | 1863 – 1885 | Nhà Nguyễn |  |
| Lê Văn Hưu | Lê Văn Hưu | 1230 – 1322 | Nhà Trần |  |
| Lê Văn Thịnh | Lê Văn Thịnh | 1038 – 1096 | Nhà Lý |  |
| Lương Ngọc Quyến | Lương Ngọc Quyến | 1885 – 1917 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Lương Thế Vinh | Lương Thế Vinh | 1441 – 1496 | Nhà Hậu Lê |  |
| Lưu Hữu Phước | Lưu Hữu Phước | 1921 – 1989 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Lưu Nhân Chú | Lưu Nhân Chú | ? – 1433 | Nhà Hậu Lê |  |
| Lũy Bán Bích | Đắp lũy Bán Bích | 1772 | Nhà Tây Sơn |  |
| Lý Chính Thắng | Lý Chính Thắng | 1917 – 1946 | Kháng chiến chống Pháp | ⚠ long-life |
| Lý Phục Man | Lý Phục Man | ? – 547 | Bắc thuộc & Khởi nghĩa |  |
| Lý Tự Trọng | Lý Tự Trọng | 1914 – 1931 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Lý Văn Phức | Lý Văn Phức | 1785 – 1849 | Nhà Nguyễn |  |
| Mạc Cửu | Mạc Cửu | 1655 – 1735 | **?** |  |
| Mạc Đĩnh Chi | Mạc Đĩnh Chi | 1272 – 1346 | Nhà Trần |  |
| Mạc Thiên Tích | Mạc Thiên Tích | ? – 1780 | Nhà Tây Sơn |  |
| Mai Chí Thọ | Mai Chí Thọ | 1922 – 2007 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Mai Xuân Thưởng | Mai Xuân Thưởng | 1860 – 1887 | Nhà Nguyễn |  |
| Ngô Đức Kế | Ngô Đức Kế | 1878 – 1929 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Ngô Gia Tự | Ngô Gia Tự | 1908 – 1935 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Ngô Nhân Tịnh | Ngô Nhân Tịnh | 1761 – 1813 | Nhà Tây Sơn |  |
| Ngô Văn Sở | Ngô Văn Sở | ? – 1795 | Nhà Tây Sơn |  |
| Nguyễn An Ninh | Nguyễn An Ninh | 1900 – 1943 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Nguyễn Biểu | Nguyễn Biểu | 1350 – 1413 | Nhà Trần |  |
| Nguyễn Bỉnh Khiêm | Nguyễn Bỉnh Khiêm | 1491 – 1585 | **?** |  |
| Nguyễn Chí Thanh | Nguyễn Chí Thanh | 1914 – 1967 | Kháng chiến chống Pháp | ⚠ long-life |
| Nguyễn Cơ Thạch | Nguyễn Cơ Thạch | 1921 – 1998 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Nguyễn Cư Trinh | Nguyễn Cư Trinh | 1716 – 1767 | **?** |  |
| Nguyễn Cửu Đàm | Nguyễn Cửu Đàm | ? – 1777 | Nhà Tây Sơn |  |
| Nguyễn Cửu Vân | Nguyễn Cửu Vân | — | **?** | ⚠ no dates |
| Nguyễn Đình Chiểu | Nguyễn Đình Chiểu | 1822 – 1888 | Nhà Nguyễn |  |
| Nguyễn Du | Nguyễn Du | 1766 – 1820 | Nhà Tây Sơn |  |
| Nguyễn Đức Cảnh | Nguyễn Đức Cảnh | 1908 – 1932 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Nguyễn Duy Hiệu | Nguyễn Duy Hiệu | 1847 – 1887 | Nhà Nguyễn |  |
| Nguyễn Hữu Cảnh | Nguyễn Hữu Cảnh | 1650 – 1700 | **?** |  |
| Nguyễn Hữu Thọ | Nguyễn Hữu Thọ | 1910 – 1996 | Kháng chiến chống Pháp | ⚠ overlap |
| Nguyễn Khắc Nhu | Nguyễn Khắc Nhu | 1882 – 1930 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Nguyễn Khoái | Nguyễn Khoái | khoảng 1240 – 1300 | Nhà Trần |  |
| Nguyễn Lương Bằng | Nguyễn Lương Bằng | 1904 – 1979 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Nguyễn Nhữ Lãm | Nguyễn Nhữ Lãm | 1378 – 1437 | **?** |  |
| Nguyễn Phúc Chu | Nguyễn Phúc Chu | 1675 – 1725 | **?** |  |
| Nguyễn Quang Bích | Nguyễn Quang Bích | 1832 – 1890 | Nhà Nguyễn |  |
| Nguyễn Thị Thập | Nguyễn Thị Thập | 1908 – 1996 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Nguyễn Thượng Hiền | Nguyễn Thượng Hiền | 1868 – 1925 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Nguyễn Trường Tộ | Nguyễn Trường Tộ | 1830 – 1871 | Nhà Nguyễn |  |
| Nguyễn Văn Cừ | Nguyễn Văn Cừ | 1912 – 1941 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Nguyễn Văn Quá | Nguyễn Văn Quá | — | **?** | ⚠ no dates |
| Nguyễn Văn Tố | Nguyễn Văn Tố | 1889 – 1947 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Nguyễn Văn Trỗi | Nguyễn Văn Trỗi | 1940 – 1964 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Nguyễn Viết Xuân | Nguyễn Viết Xuân | 1933 – 1964 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Nguyễn Xuân Ôn | Nguyễn Xuân Ôn | 1825 – 1889 | Nhà Nguyễn |  |
| Phạm Bành | Phạm Bành | 1827 – 1887 | Nhà Nguyễn |  |
| Phạm Hồng Thái | Phạm Hồng Thái | 1896 – 1924 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Phạm Hùng | Phạm Hùng | 1912 – 1988 | Kháng chiến chống Pháp | ⚠ long-life |
| Phạm Ngọc Thạch | Phạm Ngọc Thạch | 1909 – 1968 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Phạm Ngũ Lão | Phạm Ngũ Lão | 1255 – 1320 | Nhà Trần |  |
| Phạm Phú Thứ | Phạm Phú Thứ | 1821 – 1882 | Nhà Nguyễn |  |
| Phạm Văn Xảo | Phạm Văn Xảo | ? – 1430 | Nhà Hậu Lê |  |
| Phan Bá Vành | Phan Bá Vành | ? – 1827 | Nhà Nguyễn |  |
| Phan Đăng Lưu | Phan Đăng Lưu | 1902 – 1941 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Phan Huy Chú | Phan Huy Chú | 1782 – 1840 | Nhà Nguyễn |  |
| Phan Huy Ích | Phan Huy Ích | 1751 – 1822 | Nhà Tây Sơn |  |
| Phan Văn Hớn | Phan Văn Hớn | 1830 – 1886 | Nhà Nguyễn |  |
| Phan Văn Trị | Phan Văn Trị | 1830 – 1910 | Nhà Nguyễn |  |
| Phan Văn Trường | Phan Văn Trường | 1875 – 1933 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Phó Đức Chính | Phó Đức Chính | 1907 – 1930 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Phùng Chí Kiên | Phùng Chí Kiên | 1901 – 1941 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Phùng Khắc Khoan | Phùng Khắc Khoan | 1528 – 1613 | Nam–Bắc triều · Trịnh–Nguyễn |  |
| Rừng Sác | Đặc công Rừng Sác | 1966 | Kháng chiến chống Mỹ, cứu nước |  |
| Tạ Quang Bửu | Tạ Quang Bửu | 1910 – 1986 | Kháng chiến chống Pháp | ⚠ overlap |
| Tăng Bạt Hổ | Tăng Bạt Hổ | 1858 – 1906 | Nhà Nguyễn |  |
| Thái Phiên | Thái Phiên | 1882 – 1916 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Thích Quảng Đức | Thích Quảng Đức | 1897 – 1963 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Thiên Hộ Dương | Thiên Hộ Dương | 1827 – 1866 | Nhà Nguyễn |  |
| Thoại Ngọc Hầu | Thoại Ngọc Hầu | 1761 – 1829 | Nhà Tây Sơn |  |
| Thủ Khoa Huân | Thủ Khoa Huân | 1830 – 1875 | Nhà Nguyễn |  |
| Tô Hiệu | Tô Hiệu | 1912 – 1944 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Tô Vĩnh Diện | Tô Vĩnh Diện | 1924 – 1954 | Kháng chiến chống Pháp | ⚠ overlap |
| Tôn Đản | Tôn Đản | — | **?** | ⚠ no dates |
| Tôn Thất Đạm | Tôn Thất Đàm | 1864 – 1888 | Nhà Nguyễn |  |
| Tôn Thất Thiệp | Tôn Thất Tiệp | 1870 – 1888 | Nhà Nguyễn |  |
| Tống Duy Tân | Tống Duy Tân | 1837 – 1892 | Nhà Nguyễn |  |
| Trần Bạch Đằng | Trần Bạch Đằng | 1926 – 2007 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Trần Bình Trọng | Trần Bình Trọng | 1259 – 1285 | Nhà Trần |  |
| Trần Cao Vân | Trần Cao Vân | 1866 – 1916 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Trần Đại Nghĩa | Trần Đại Nghĩa | 1913 – 1997 | Kháng chiến chống Pháp | ⚠ long-life |
| Trần Huy Liệu | Trần Huy Liệu | 1901 – 1969 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Trần Khắc Chân | Trần Khát Chân | 1370 – 1399 | Nhà Trần |  |
| Trần Nguyên Đán | Trần Nguyên Đán | 1325 – 1390 | Nhà Trần |  |
| Trần Nguyên Hãn | Trần Nguyên Hãn | 1390 – 1429 | Nhà Hậu Lê |  |
| Trần Quang Diệu | Trần Quang Diệu | 1746 – 1802 | Nhà Tây Sơn |  |
| Trần Quý Cáp | Trần Quý Cáp | 1870 – 1908 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Trần Tấn | Trần Tấn | ? – 1874 | Nhà Nguyễn |  |
| Trần Thánh Tông | Trần Thánh Tông | 1240 – 1290 | Nhà Trần |  |
| Trần Văn Giàu | Trần Văn Giàu | 1911 – 2010 | Kháng chiến chống Pháp | ⚠ long-life |
| Trần Văn Kỷ | Trần Văn Kỷ | ? – 1801 | Nhà Tây Sơn |  |
| Trần Văn Ơn | Trần Văn Ơn | 1931 – 1950 | Kháng chiến chống Pháp | ⚠ long-life |
| Trịnh Hoài Đức | Trịnh Hoài Đức | 1765 – 1825 | Nhà Tây Sơn |  |
| Trịnh Văn Cấn | Trịnh Văn Cấn | 1881 – 1918 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Tuệ Tĩnh | Tuệ Tĩnh | — | **?** | ⚠ no dates |
| Út Tịch | Út Tịch | 1931 – 1968 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Văn Cao | Văn Cao | 1923 – 1995 | Kháng chiến chống Mỹ, cứu nước | ⚠ long-life |
| Võ Chí Công | Võ Chí Công | 1912 – 2011 | Kháng chiến chống Pháp | ⚠ long-life |
| Võ Thị Sáu | Võ Thị Sáu | 1933 – 1952 | Kháng chiến chống Pháp | ⚠ long-life |
| Võ Trường Toản | Võ Trường Toản | 1709 – 1792 | **?** |  |
| Võ Văn Tần | Võ Văn Tần | 1891 – 1941 | Pháp thuộc & Phong trào yêu nước | ⚠ overlap |
| Vũ Hữu | Vũ Hữu | ? – 1511 | **?** |  |
| Xuân Thủy | Xuân Thủy | 1912 – 1985 | Kháng chiến chống Pháp | ⚠ long-life |

## What the map will do

- One line layer per period color (built once, so ~1,300 lines still cost
  nothing extra).
- The **selected** street keeps a thick bright line with a light halo, since
  gold no longer means "selected".
- A slim **legend**, collapsed by default (the app's delicate-UI rule): a
  time-ordered strip of period dots. Tapping a dot shows only that period's
  streets and dims the rest, so you can walk through time.
- Street card: a small dot in the street's period color next to its name.

## Steps

1. You review the table above (fix any ⚠ row; answer the questions below).
2. Add `period` to the targets, with the validator rule and a test; run the
   validator and the street tests.
3. Map: color table, per-color layers, selected-street halo, tests.
4. Legend with the highlight-by-period interaction, tests.
5. Check on your phone (colors against the real base map, legend usability).
6. Commit, then a CMS publish. The mapping ships in the content pack, so no
   app update is needed for the data; the colors and legend need a new app build.

## Questions

1. Is the **palette** above acceptable, or should any period be nudged?
2. For long-life people (e.g. Phạm Hùng, 1912 – 1988), is "the period of their
   mature years (about 35)" the right rule, or should it be the period they are
   best known for?
3. Streets whose person never got a period (a new street added later):
   neutral gold fallback, as proposed?
