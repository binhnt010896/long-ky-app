# Long Ký — Play Console release notes

Paste the block for a version into **Release → (track) → Create release →
"What's new in this release"**. Play wants each language wrapped in its tag
and allows **500 characters per language**; the character counts below were
checked. Newest version first.

## 1.2.0 (11)

Builds on 1.1.2 (10) (already uploaded). The text lists what is new since then
(it covers 1.1.2 (10) → 1.2.0 (11) and the content shipped over the air since).

```
<vi-VN>
Mới: hướng dẫn nhanh khi mở Bản đồ đường phố và Bản đồ lãnh thổ lần đầu. Bản đồ đường phố mở nhanh hơn. Hơn 150 nhân vật mới có trang riêng, kèm tên đường tương ứng. Nội dung và hình ảnh tự cập nhật khi có bản mới, không cần cài lại ứng dụng. Thêm nút "Báo sai sót" trên trang chi tiết và trang lưu ý về hình ảnh, nội dung. Chỉnh lại nội dung thời Gia Long theo nguồn Viện Sử học; chân dung toàn thân các nhân vật thời Hồng Bàng – Bắc thuộc nay khớp với ảnh đại diện.
</vi-VN>
<en-US>
New: a quick first-time guide on the Street map and the Territory atlas. The street map opens faster. Over 150 more figures now have their own pages, with their matching streets. Content and images update on their own when new ones are out, with no reinstall. Added a "Report an error" button on detail pages, plus a notice page on images and content. Gia Long-era content revised against Viện Sử học sources; full-body portraits from Hồng Bàng to the Northern rule now match their avatars.
</en-US>
```

Character counts: vi-VN 467, en-US 490 (limit 500 each).

### Notes for the console (not for users)

- The first-time guides show once per screen and are remembered separately for
  the street map and the territory atlas.
- Content packs are published over the air (latest `20261008073511`); the
  app adopts a new pack as soon as it finishes downloading and re-checks when
  the app returns to the foreground, so reviewers see current content without
  a store update.
- "Báo sai sót" opens the reader's mail app (or shows the address with a Copy
  button); no text is logged.

## 1.1.2 (10)

Builds on 1.1.0 (8) and 1.1.1 (9) (both already uploaded); only the new items
are listed — Play shows this text for this release only.

```
<vi-VN>
Thêm liên kết "Chính sách quyền riêng tư" trong mục Về Long Ký. Sửa lỗi hiển thị số phiên bản ở mục Về Long Ký.
</vi-VN>
<en-US>
Added a "Privacy policy" link in About Long Ký. Fixed the app version number shown in About Long Ký.
</en-US>
```

## 1.1.0 (8)

```
<vi-VN>
Mới: "Đường phố mang tên sử" — bản đồ những con đường ở TP.HCM mang tên người và sự kiện trong sử Việt. Chạm vào một con đường để biết nó mang tên ai, rồi mở thẳng trang nhân vật hay sự kiện. Có bản đồ nền, các địa danh (Chợ Bến Thành, Dinh Độc Lập, Nhà thờ Đức Bà…) và ô tìm tên đường. Trang nhân vật và sự kiện cũng cho biết con đường tương ứng. Màn hình mở đầu mới với rồng vàng và mây sơn mài.
</vi-VN>
<en-US>
New: "Streets named for history" — a map of the streets in Ho Chi Minh City named after people and events in Vietnamese history. Tap a street to see who or what it honours, then jump straight to that figure or event. Includes a base map, landmarks (Bến Thành Market, Independence Palace, Notre-Dame Cathedral…) and street search. Figure and event pages now show matching streets. Plus a new opening screen with a gilded dragon among lacquer clouds.
</en-US>
```

Character counts: vi-VN 397, en-US 448 (limit 500 each).

Where to open the map: Sảnh (the seal at the top right of Home) → "Đường phố
mang tên sử".

### Notes for the console (not for users)

- Closed-testing track; the previous build there is `1.0.3 (6)`. `1.1.0 (7)`
  was built but not released — `1.1.0 (8)` supersedes it.
- The street map needs a network connection the first time (the street lines
  and the base map download from the content CDN, then cache).
