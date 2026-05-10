---
title: Thực hành Vault Agent Auto-Auth
estMinutes: 25
---

# Thực hành Vault Agent Auto-Auth

## Mục tiêu

Trong bài thực hành này, bạn sẽ cấu hình Vault Agent sử dụng AppRole Auto-Auth để tự động lấy token và ghi vào sink file, sau đó xác nhận rằng ứng dụng có thể dùng token đó để đọc secret từ Vault.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này — Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được đặt sẵn.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/07-vault-agent/02-agent-auto-auth/`.

## Nhiệm vụ của bạn

### Bước 1 — Chuẩn bị AppRole

Sử dụng Vault CLI để bật AppRole auth method, tạo một role tên `lab-agent`, lấy `role_id`, tạo `secret_id`, rồi ghi hai giá trị đó vào các file riêng biệt trong thư mục làm việc.

Gợi ý: AppRole có thể chưa được bật trên dev server — bạn cần bật trước khi dùng.

### Bước 2 — Viết file cấu hình Agent

Tạo một file HCL tên `agent.hcl` trong thư mục làm việc. File này phải:

- Khai báo địa chỉ Vault server trong stanza `vault {}`.
- Khai báo `auto_auth {}` với:
  - `method {}` loại `approle`, trỏ tới hai file role_id và secret_id bạn vừa tạo. Đặt `remove_secret_id_file_after_reading = false` để có thể chạy lại Agent nhiều lần.
  - `sink {}` loại `file`, ghi token vào file `./vault-token-sink`.

### Bước 3 — Chạy Vault Agent

Vault Agent chạy ở foreground và chiếm terminal. Bạn có hai lựa chọn:

- **Lựa chọn A (khuyến nghị):** Mở terminal thứ hai trong Codespace, chạy Agent ở terminal đó, rồi quay lại terminal đầu tiên để thực hiện các bước tiếp theo.
- **Lựa chọn B:** Chạy Agent ở background bằng cách thêm `&` vào cuối lệnh và ghi log ra file.

Chạy Agent bằng lệnh `vault agent` với flag chỉ tới file config bạn vừa tạo.

### Bước 4 — Xác nhận token trong sink

Sau khi Agent khởi động thành công, file `./vault-token-sink` phải tồn tại và chứa một Vault token hợp lệ. Dùng Vault CLI để xác nhận token này có thể được dùng để tra cứu thông tin (ví dụ: `vault token lookup`).

### Bước 5 — Dùng token từ sink để đọc secret

Tạo một secret tại đường dẫn `secret/data/lab-test` với một key bất kỳ. Sau đó dùng token từ file sink (đặt vào biến môi trường hoặc truyền qua flag) để đọc lại secret đó.

Gợi ý: token trong sink là token được cấp cho AppRole role `lab-agent`. Bạn cần kiểm tra role đó có policy cho phép đọc path này không, và nếu chưa thì cần cấp thêm.

### Bước 6 — Tạo sink thứ hai với wrap_ttl

Dừng Agent (nếu đang chạy ở background, dùng `kill`). Chỉnh sửa `agent.hcl` để thêm một stanza `sink {}` thứ hai:

- Đường dẫn: `./vault-token-sink-wrapped`
- Đặt `wrap_ttl = "5m"`

Khởi động lại Agent. Xác nhận file `./vault-token-sink-wrapped` tồn tại và chứa một wrapping token (có thể kiểm tra bằng `vault unwrap` hoặc `vault token lookup` — wrapping token sẽ không tra cứu được như token thường).

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
