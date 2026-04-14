---
title: Thực hành capabilities — wildcard, deny, và list trung gian
estMinutes: 15
---

# Thực hành capabilities: wildcard, deny, và list trung gian

## Mục tiêu

Qua bài thực hành này, bạn sẽ tự mình quan sát sự khác biệt giữa policy đúng và policy sai khi dùng wildcard `*`, capability `deny`, và capability `list` trên KV v2. Bạn sẽ tạo các token test với policy khác nhau để thấy rõ hành vi của Vault.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết "Capabilities trong Vault Policy".

## Nhiệm vụ của bạn

### Bước 1: Tạo secrets test

Tạo ba secrets trong KV v2 tại namespace `secret/apps/webapp/`:

- `secret/apps/webapp/api` với trường `url=http://api:8080`
- `secret/apps/webapp/db` với trường `host=db:5432`
- `secret/apps/webapp/super-secret` với trường `password=P@ssw0rd`

### Bước 2: Khám phá giới hạn của wildcard `*` và thiếu `list`

Tạo một file policy tên `webapp-wildcard.hcl` với nội dung: chỉ có rule cho `secret/data/apps/webapp/*` với capability `read`. Không thêm bất kỳ rule nào khác.

Tạo policy `webapp-wildcard` từ file đó, rồi tạo một token test được gắn policy này. Sử dụng token test để:

- Thử đọc `secret/apps/webapp/api` — quan sát kết quả.
- Thử liệt kê `secret/apps/webapp/` bằng lệnh `vault kv list` — quan sát kết quả và lý giải tại sao.

> Gợi ý: để dùng token khác với token hiện tại, bạn có thể đặt biến môi trường `VAULT_TOKEN=<token>` trước lệnh, hoặc dùng flag `-address` / `-token`. Hãy nhớ đặt lại token root sau khi test.

### Bước 3: Sửa policy để `list` hoạt động

Tạo một file policy mới tên `webapp-full.hcl`. Policy này phải:

- Giữ nguyên rule `read` cho `secret/data/apps/webapp/*`.
- Thêm rule `list` tại path `metadata` phù hợp để lệnh `vault kv list secret/apps/webapp/` hoạt động.

Tạo policy `webapp-full` từ file đó, rồi tạo token test mới với policy này. Xác nhận rằng lệnh `vault kv list secret/apps/webapp/` thành công với token mới.

### Bước 4: Dùng `deny` để chặn một path cụ thể

Tạo một file policy tên `webapp-deny-secret.hcl`. Policy này phải:

- Cấp `read` cho `secret/data/apps/webapp/*` (quyền rộng).
- Cấp `deny` cho `secret/data/apps/webapp/super-secret` (chặn path cụ thể).

Tạo policy `webapp-deny-secret` từ file đó, rồi tạo token test mới với policy này. Xác nhận rằng:

- Đọc `secret/apps/webapp/api` thành công.
- Đọc `secret/apps/webapp/super-secret` bị từ chối.

### Bước 5: Verify capabilities bằng lệnh CLI

Sử dụng lệnh `vault token capabilities` với root token (không phải token test) để kiểm tra capabilities của token test tạo ở Bước 4 tại hai path:

- `secret/data/apps/webapp/api`
- `secret/data/apps/webapp/super-secret`

So sánh output của hai lệnh và giải thích sự khác biệt.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
