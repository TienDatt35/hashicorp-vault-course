---
title: "Thực hành workflow: authenticate, token lookup và revoke"
estMinutes: 20
---

# Thực hành workflow: authenticate, token lookup và revoke

## Mục tiêu

Bạn sẽ thực hành toàn bộ workflow end-to-end của Vault: từ bật auth method, tạo
user, authenticate để nhận token, kiểm tra thông tin token, đọc secret, cho đến
revoke token và xác nhận rằng token đã bị vô hiệu hóa.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được set sẵn trong Codespace.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/01-vault-introduction/03-how-it-work/`.

## Nhiệm vụ của bạn

### Bước 1 — Kiểm tra Vault dev server

Chạy lệnh kiểm tra trạng thái Vault và xác nhận server đang chạy ở chế độ dev
(Initialized: true, Sealed: false).

### Bước 2 — Bật auth method userpass

Enable auth method `userpass` trên Vault. Nếu đã enable rồi thì không cần
enable lại.

### Bước 3 — Tạo user alice

Tạo user với username `alice`, password `alice-password`, và gán policy
`default`.

### Bước 4 — Login bằng alice và lưu token

Login vào Vault bằng alice. Lưu giá trị token nhận được vào biến shell
`ALICE_TOKEN` để dùng cho các bước tiếp theo.

> Gợi ý: thêm flag `-format=json` vào lệnh login để lấy output dạng JSON,
> sau đó dùng `jq` để parse token ra.

### Bước 5 — Xem chi tiết token của alice

Dùng `ALICE_TOKEN` để xem thông tin chi tiết của token đó: TTL còn lại,
danh sách policies đang áp dụng, và accessor.

### Bước 6 — Kiểm tra capabilities tại một path

Kiểm tra những capabilities nào token của alice có tại path
`secret/data/myapp/config`.

### Bước 7 — Ghi và đọc secret

Dùng root token để ghi secret vào `secret/myapp/config` với giá trị
`env=production`. Sau đó dùng `ALICE_TOKEN` để đọc lại secret đó và xác nhận
dữ liệu trả về đúng.

> Lưu ý: `secret/` là KV v2 mount mặc định trong Vault dev mode — bạn không
> cần enable riêng.

### Bước 8 — Revoke token và xác nhận bị từ chối

Dùng root token để revoke `ALICE_TOKEN`. Sau đó thử dùng `ALICE_TOKEN` để
thực hiện bất kỳ lệnh nào — bạn phải nhận lỗi "bad token" hoặc "permission
denied".

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với
> phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
