---
title: Thực hành viết policy với path và capabilities
estMinutes: 15
---

# Thực hành viết policy với path và capabilities

## Mục tiêu

Sau khi hoàn thành bài thực hành này, bạn sẽ biết cách viết policy HCL với path đúng cho từng loại resource (KV v2, dynamic credentials, quản lý policies), đăng ký policy lên Vault, và xác minh policy hoạt động đúng.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng về cú pháp path và capabilities.

## Nhiệm vụ của bạn

### Bước 1 — Viết và đăng ký policy cho Jenkins (KV v2)

Tạo file `jenkins-dev.hcl` với nội dung policy cho phép:
- Đọc, ghi, cập nhật, xóa secret tại `secret/data/apps/jenkins` (chỉ path cụ thể này, không dùng wildcard)
- List metadata tại `secret/metadata/apps/jenkins`

Sau khi tạo file, đăng ký policy lên Vault với tên `jenkins-dev`.

### Bước 2 — Viết và đăng ký policy lấy AWS dynamic credentials

Tạo file `aws-consumer.hcl` với nội dung policy cho phép lấy AWS dynamic credentials từ role `webapp-role`. Lưu ý capability phù hợp với thao tác `vault read`.

Sau khi tạo file, đăng ký policy lên Vault với tên `aws-consumer`.

### Bước 3 — Viết và đăng ký policy quản lý policies

Tạo file `policy-admin.hcl` với nội dung policy cho phép:
- Tạo, đọc, cập nhật, xóa và list các ACL policies tại `sys/policies/acl/*`
- List danh sách policies tại `sys/policies/acl` (path không có wildcard — cần rule riêng)

Sau khi tạo file, đăng ký policy lên Vault với tên `policy-admin`.

### Bước 4 — Tạo secret test và xác minh policy jenkins-dev hoạt động

Tạo secret trong KV v2 tại path `secret/apps/jenkins/config` với key `url` và giá trị `http://jenkins:8080`.

Sau đó tạo một token với policy `jenkins-dev` và dùng token đó để đọc secret vừa tạo — xác nhận policy hoạt động đúng.

### Bước 5 — Xác minh tất cả policies đã được đăng ký

Dùng lệnh list policies để kiểm tra cả ba policies (`jenkins-dev`, `aws-consumer`, `policy-admin`) đều có trong hệ thống.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
