---
title: Dynamic Secrets Engine: Cấu hình database engine và role
estMinutes: 25
---

# Dynamic Secrets Engine: Cấu hình database engine và role

## Mục tiêu

Bạn sẽ thực hành mô hình 2 bước của dynamic secrets engine bằng cách bật database engine, cấu hình kết nối backend (với `verify_connection=false` do không có PostgreSQL thật trong môi trường lab), tạo role ánh xạ permission, và tạo policy cho client.

> Lưu ý về môi trường: Devcontainer này không có PostgreSQL. Lab dùng `verify_connection=false` để Vault chấp nhận cấu hình mà không thực sự kết nối database. Mô hình 2 bước và cú pháp lệnh hoàn toàn giống môi trường thực tế — chỉ có bước đọc credential cuối sẽ thất bại vì không có database thật để sinh user.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/06-vault-secret-engine/02-dynamic-secret-engine/`.

## Nhiệm vụ của bạn

**Bước 1:** Bật database secrets engine tại path mặc định `database/`.

**Bước 2:** Cấu hình kết nối backend với tên config là `mydb`. Sử dụng các thông số sau:
- `plugin_name`: `postgresql-database-plugin`
- `connection_url`: `postgresql://{{username}}:{{password}}@localhost/mydb?sslmode=disable`
- `allowed_roles`: `db-readonly`
- `username`: `vault-admin`
- `password`: `admin-password`
- `verify_connection`: `false` (bắt buộc trong môi trường lab không có PostgreSQL)

**Bước 3:** Tạo role `db-readonly` với các thông số sau:
- `db_name`: `mydb` (phải khớp với tên config ở Bước 2)
- `creation_statements`: câu SQL tạo user với quyền SELECT trên schema public:
  ```
  CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
  ```
- `default_ttl`: `1h`
- `max_ttl`: `24h`

**Bước 4:** Tạo policy tên `db-client` cho phép client đọc credential từ role `db-readonly`. Ghi policy vào file `/tmp/db-client-policy.hcl` rồi áp dụng vào Vault.

**Bước 5:** Xác nhận cấu hình bằng cách:
- Liệt kê secrets engine đang hoạt động và tìm `database/`
- Đọc config `database/config/mydb` để kiểm tra thông số
- Đọc role `database/roles/db-readonly` để kiểm tra TTL

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Chú ý đặc biệt đến flag `verify_connection=false` ở Bước 2 và cú pháp `creation_statements` ở Bước 3 — chuỗi SQL phải đặt trong dấu ngoặc kép.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
