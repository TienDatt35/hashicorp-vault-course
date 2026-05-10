---
title: Chọn Token Phù Hợp — Best Practice
estMinutes: 20
---

# Chọn Token Phù Hợp — Best Practice

Trong bài này, bạn sẽ đối mặt với 4 yêu cầu vận hành thực tế và tự quyết định
loại token nào phù hợp, sau đó tạo và kiểm tra từng loại.

## Mục tiêu

Sau khi hoàn thành bài thực hành, bạn sẽ biết cách tạo và xác minh periodic
token, use-limit token, orphan token, và batch token; đồng thời quan sát sự
khác biệt về metadata giữa các loại.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/05-vault-token/05-token-best-practice/`.

## Nhiệm vụ của bạn

### Bước 1 — Tạo policy cho bài thực hành

Tạo một policy tên `best-practice-policy` cho phép đọc secret trong path
`secret/data/app/*`. Policy này sẽ được gán cho tất cả token tạo trong bài.

### Bước 2 — Tạo periodic token

**Yêu cầu vận hành:** App chạy 24/7, cần token sống vô hạn, không muốn xoay
token mới. App sẽ tự renew token trước khi hết hạn.

Tạo một periodic token với `period=1h` và gán `best-practice-policy`. Sau khi
tạo, dùng `vault token lookup` để kiểm tra metadata và xác nhận token có
`period` và không có `explicit_max_ttl`.

### Bước 3 — Tạo use-limit token (3 lần dùng)

**Yêu cầu vận hành:** Phân phối secret một lần cho script bootstrap. Token chỉ
được dùng tối đa 3 lần rồi tự hủy, dù TTL còn hay không.

Tạo một use-limit token với `use-limit=3`, `ttl=1h`, và gán
`best-practice-policy`. Kiểm tra metadata để xác nhận `num_uses=3`.

### Bước 4 — Tạo orphan token

**Yêu cầu vận hành:** Background job cần token không bị ảnh hưởng khi token
của session cha hết hạn.

Tạo một orphan token với `ttl=1h` và gán `best-practice-policy`. Kiểm tra
metadata để xác nhận `orphan=true`.

### Bước 5 — Tạo batch token và thử renew

**Yêu cầu vận hành:** Hàng nghìn CI/CD job ngắn hạn chạy đồng thời, cần token
nhẹ không tạo áp lực lên storage.

Tạo một batch token với `ttl=1h` và gán `best-practice-policy`. Sau đó thử
renew batch token vừa tạo. Quan sát thông báo lỗi — đây là hành vi đặc trưng
của batch token.

> Gợi ý: mỗi bước có một loại token và flag CLI tương ứng trong bài lý thuyết.
> Hãy tự suy nghĩ trước khi mở `solution.md`.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
