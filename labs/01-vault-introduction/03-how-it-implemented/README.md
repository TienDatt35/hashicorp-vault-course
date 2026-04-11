---
title: "Khám phá giới hạn của Vault Community Edition"
estMinutes: 15
---

# Khám phá giới hạn của Vault Community Edition

## Mục tiêu

Trong bài thực hành này, bạn sẽ kiểm tra trực tiếp những tính năng có và không có trong Vault Community Edition đang chạy trong Codespace. Qua đó, bạn hiểu rõ hơn sự khác biệt thực tế giữa OSS và Enterprise mà lý thuyết đã đề cập.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/01-vault-introduction/03-how-it-implemented/`.

## Nhiệm vụ của bạn

1. Kiểm tra phiên bản Vault đang chạy bằng lệnh `vault version` và `vault status`. Xác nhận rằng output của `vault version` **không** chứa `+ent` — đây là dấu hiệu đang dùng Community Edition.

2. Thử tạo một namespace tên `test` bằng lệnh `vault namespace create test`. Quan sát thông báo lỗi trả về. Đây không phải lỗi cấu hình — OSS không hỗ trợ Namespaces.

3. Xem danh sách secrets engines đang được bật bằng lệnh `vault secrets list`. Xác nhận rằng các engine cơ bản như `cubbyhole/`, `identity/`, `secret/`, và `sys/` có mặt.

4. Bật auth method `userpass` và tạo user `testuser` với password `testpass`. Bước này xác nhận OSS có đầy đủ tính năng auth method.

5. Bật KV v2 secrets engine tại path `demo/`. Bước này xác nhận OSS có đầy đủ secrets engines.

6. Ghi secret `key=value` vào `demo/test`, sau đó đọc lại để xác nhận dữ liệu được lưu đúng.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
