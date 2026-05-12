---
title: Xác thực vào Vault bằng Token
estMinutes: 20
---

# Xác thực vào Vault bằng Token

## Mục tiêu

Sau khi hoàn thành bài thực hành, bạn sẽ biết cách dùng Vault token để xác
thực — qua CLI, biến môi trường, và HTTP header — đồng thời hiểu rõ cách policy
gắn vào token kiểm soát quyền hạn: hành động nào được phép và hành động nào bị
từ chối.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này — Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR=http://127.0.0.1:8200` và `VAULT_TOKEN=root`
  đã được thiết lập sẵn.
- `curl` và `jq` đã có sẵn trong Codespace.

## Nhiệm vụ của bạn

### Phần 1 — Dùng token để xác thực

**Bước 1 — Xem thông tin token hiện tại**

Dùng `vault token lookup` để xem chi tiết về root token bạn đang dùng. Xác
định các trường: `id`, `policies`, `ttl`, `type`, `accessor`.

**Bước 2 — Thử với token không hợp lệ**

Đặt `VAULT_TOKEN=invalid` rồi gọi `vault token lookup`. Quan sát Vault phản hồi
như thế nào khi token sai.

**Bước 3 — Gọi API với X-Vault-Token header**

Đặt lại `VAULT_TOKEN=root`. Dùng `curl` với header `X-Vault-Token: root` để gọi
`GET /v1/auth/token/lookup-self`. Xác nhận response HTTP 200.

**Bước 4 — Gọi API không có token**

Gọi lại `GET /v1/auth/token/lookup-self` mà không truyền bất kỳ header nào.
Quan sát HTTP status code và nội dung response.

### Phần 2 — Cấp quyền qua policy và kiểm tra giới hạn

**Bước 5 — Chuẩn bị secret**

Dùng root token để tạo một KV secret tại `secret/data/team-a/config` với nội
dung `{"env": "production", "region": "us-east-1"}`.

Xác nhận secret đã được tạo bằng cách đọc lại.

**Bước 6 — Tạo policy giới hạn quyền**

Tạo một policy tên `team-a-readonly` chỉ cho phép:
- **Đọc** (`read`) tại `secret/data/team-a/*`

Không cho phép ghi, xóa, hay truy cập bất kỳ path nào khác.

**Bước 7 — Tạo token với policy vừa tạo**

Dùng root token tạo một token mới gắn policy `team-a-readonly` và TTL 1 giờ.
Lưu token vào biến `TEAM_TOKEN`.

Xác nhận token có đúng policy bằng `vault token lookup`.

**Bước 8 — Thực hiện hành động được phép**

Dùng `TEAM_TOKEN` để đọc secret tại `secret/data/team-a/config`. Xác nhận đọc
thành công và thấy được dữ liệu.

**Bước 9 — Thực hiện hành động bị cấm**

Dùng `TEAM_TOKEN` thử thực hiện các thao tác sau và quan sát kết quả:

- **Ghi** một secret mới vào `secret/data/team-a/config` (thay đổi dữ liệu)
- **Đọc** secret ở path khác: `secret/data/other/config`
- **Xem danh sách** auth methods bằng `vault auth list`

Tất cả ba thao tác trên phải bị từ chối. Vault trả về gì trong mỗi trường hợp?

**Bước 10 — Thu hồi token**

Dùng root token để revoke `TEAM_TOKEN`. Sau đó thử đọc lại secret bằng
`TEAM_TOKEN` — xác nhận token không còn dùng được.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
