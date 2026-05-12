---
title: Quản lý Vault Token bằng CLI
estMinutes: 25
---

# Quản lý Vault Token bằng CLI

## Mục tiêu

Thực hành toàn bộ vòng đời của một Vault token: tạo token với policy và TTL, tra cứu metadata, kiểm tra quyền trên các path cụ thể, gia hạn, và cuối cùng thu hồi.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/05-vault-token/04-token-manage/`.

## Nhiệm vụ của bạn

### Bước 1 — Tạo policy `lab-policy`

Viết policy cho phép đọc và liệt kê secret tại path `secret/data/lab/*`. Lưu policy vào file tạm rồi nạp vào Vault.

Gợi ý: policy cần cấp capabilities `["read", "list"]` cho path `secret/data/lab/*`.

### Bước 2 — Tạo token với policy và TTL

Tạo một token mới với các thuộc tính sau:

- Gán policy `lab-policy`
- TTL là 30 phút
- Explicit-max-ttl là 2 giờ
- Display name là `lab-token`

Lưu token vừa tạo vào biến môi trường `LAB_TOKEN`.

### Bước 3 — Tra cứu metadata của token

Dùng `vault token lookup` để xem thông tin token vừa tạo. Quan sát các field:
- `ttl` — số giây còn lại
- `policies` — danh sách policy được gán
- `explicit_max_ttl` — trần cứng
- `display_name` — tên hiển thị

### Bước 4 — Kiểm tra quyền trên các path

Dùng `vault token capabilities` để kiểm tra:

- Quyền của `$LAB_TOKEN` trên path `secret/data/lab/test` — phải thấy `read` trong danh sách
- Quyền của `$LAB_TOKEN` trên path `secret/data/other` — phải thấy `deny`

### Bước 5 — Gia hạn token

Gia hạn `$LAB_TOKEN` với increment 15 phút. Dùng `vault token renew` với flag `-increment`.

Sau khi gia hạn, lookup lại token để xác nhận TTL đã được cập nhật.

### Bước 6 — Thu hồi token và xác nhận

Thu hồi `$LAB_TOKEN` bằng `vault token revoke`. Sau đó thử lookup token đó để xác nhận token đã không còn hiệu lực (lệnh sẽ trả về lỗi).

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
