---
title: Thực hành nhận diện Vault Agent và Proxy
estMinutes: 20
---

# Thực hành nhận diện Vault Agent và Proxy

## Mục tiêu

Bạn sẽ khám phá giao diện CLI của Vault Agent và Vault Proxy, viết hai file cấu hình HCL tối giản cho mỗi daemon, rồi so sánh cấu trúc của chúng để hiểu sự khác biệt về thiết kế.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/07-vault-agent/01-agent-introduction/`.

## Nhiệm vụ của bạn

**Bước 1: Khám phá CLI của Vault Agent và Vault Proxy**

Chạy lệnh help để xem các flag và mô tả của từng daemon:

```bash
vault agent --help
vault proxy --help
```

Quan sát và ghi nhớ: hai lệnh này khác nhau như thế nào? Mỗi lệnh nhận những flag nào?

**Bước 2: Viết file cấu hình Agent tối giản**

Tạo file `/tmp/lab-agent.hcl` với cấu hình Agent gồm đủ 4 stanza cốt lõi:
- `vault {}` — địa chỉ Vault server
- `auto_auth {}` — cấu hình xác thực, dùng method `approle`, chỉ định đường dẫn file cho `role_id_file_path` và `secret_id_file_path`; thêm `sink` loại `file` ghi token ra `/tmp/lab-vault-token`
- `cache {}` — bật cache (để trống stanza là đủ)
- `template {}` — chỉ định `source` và `destination` (có thể dùng đường dẫn giả, không cần file thực tồn tại)

> Gợi ý: file cấu hình này chỉ để luyện tập viết cú pháp HCL — bạn chưa cần chạy Agent thực sự trong bài này. Tham khảo cấu trúc stanza trong bài lý thuyết nếu cần.

**Bước 3: Viết file cấu hình Proxy tối giản**

Tạo file `/tmp/lab-proxy.hcl` với cấu hình Proxy gồm các stanza bắt buộc:
- `vault {}` — địa chỉ Vault server
- `auto_auth {}` — cấu hình xác thực, dùng method `approle`, thêm `sink` loại `file` ghi token ra `/tmp/lab-proxy-token`
- `listener "tcp" {}` — mở listener tại `127.0.0.1:8100`, tắt TLS
- `api_proxy {}` — bật proxy mode với `use_auto_auth_token = true`
- `cache {}` — bật cache

**Bước 4: So sánh hai file config**

Chạy lệnh sau để xem nội dung song song:

```bash
echo "=== Agent config ===" && cat /tmp/lab-agent.hcl && echo && echo "=== Proxy config ===" && cat /tmp/lab-proxy.hcl
```

Ghi nhận ít nhất 3 điểm khác biệt giữa hai file cấu hình.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra sau khi hoàn thành cả 4 bước:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
