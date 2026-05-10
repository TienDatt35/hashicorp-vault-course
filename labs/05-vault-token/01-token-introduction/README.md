---
title: Thực hành Vault Token
estMinutes: 20
---

# Thực hành Vault Token

## Mục tiêu

Sau khi hoàn thành bài này, bạn sẽ biết cách tạo, kiểm tra, gia hạn và thu hồi Vault token; phân biệt service token với batch token qua thực tế; và hiểu rõ hành vi của token giới hạn số lần dùng.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/05-vault-token/01-token-introduction/`.

## Nhiệm vụ của bạn

### Bước 1 — Kiểm tra token hiện tại

Xem thông tin chi tiết của token `root` đang được dùng. Chú ý đến các trường `type`, `policies`, `num_uses`, `orphan` và `renewable`.

### Bước 2 — Tạo service token

Tạo một service token mới với TTL là 1 giờ và policy `default`. Lưu chuỗi token vào biến môi trường để dùng ở bước tiếp theo. Xác nhận token bắt đầu bằng `hvs.` (hoặc `s.` nếu Vault < 1.10).

### Bước 3 — Dùng service token để đọc secret

Sử dụng service token vừa tạo (đặt vào biến `VAULT_TOKEN`) để kiểm tra nó có thể hoạt động bằng cách tra cứu chính nó qua `vault token lookup`. Sau đó trả lại quyền root bằng cách set `VAULT_TOKEN=root`.

### Bước 4 — Tạo batch token và thử gia hạn

Tạo một batch token với TTL 1 giờ. Xác nhận prefix của token là `hvb.` (hoặc `b.` nếu Vault < 1.10). Sau đó thử gia hạn batch token — quan sát kết quả lỗi và hiểu lý do.

### Bước 5 — Tạo token giới hạn số lần dùng

Tạo một token với `use-limit=3` và TTL 1 giờ. Dùng token đó 3 lần (ví dụ gọi `vault token lookup` 3 lần với token đó). Sau lần thứ 3, kiểm tra xem token còn hoạt động không.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
