---
title: Dynamic Secrets Engine: Cấu hình database engine và tạo credential thật
estMinutes: 35
---

# Dynamic Secrets Engine: Cấu hình database engine và tạo credential thật

## Mục tiêu

Bạn sẽ thực hành toàn bộ vòng đời của dynamic secrets engine: khởi động PostgreSQL bằng Docker, cấu hình Vault kết nối tới database, tạo role ánh xạ permission, và cuối cùng yêu cầu Vault sinh credential thật — một tài khoản PostgreSQL tạm thời tự hủy sau TTL.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Codespace chạy trên Alpine Linux — `apk` có sẵn để cài package.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/06-vault-secret-engine/02-dynamic-secret-engine/`.

## Nhiệm vụ của bạn

**Bước 0:** Cài đặt và khởi động PostgreSQL trực tiếp trong Codespace (môi trường Alpine, không có Docker daemon):
- Cài gói: `apk add --no-cache postgresql postgresql-client`
- Khởi tạo data directory tại `/tmp/pgdata` với user OS `postgres`
- Tạo role `vault-admin` (superuser) và database `mydb`
- Chờ đến khi `pg_isready` báo sẵn sàng

**Bước 1:** Bật database secrets engine tại path mặc định `database/`.

**Bước 2:** Cấu hình kết nối backend với tên config là `mydb`. Sử dụng các thông số sau:
- `plugin_name`: `postgresql-database-plugin`
- `connection_url`: `postgresql://{{username}}:{{password}}@localhost:5432/mydb?sslmode=disable`
- `allowed_roles`: `db-readonly`
- `username`: `vault-admin`
- `password`: `admin-password`

(Lần này không cần `verify_connection=false` vì đã có database thật.)

**Bước 3:** Tạo role `db-readonly` với các thông số sau:
- `db_name`: `mydb` (phải khớp với tên config ở Bước 2)
- `creation_statements`: câu SQL tạo user với quyền SELECT trên schema public:
  ```
  CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
  ```
- `default_ttl`: `1h`
- `max_ttl`: `24h`

**Bước 4:** Tạo policy tên `db-client` cho phép client đọc credential từ role `db-readonly`. Ghi policy vào file `/tmp/db-client-policy.hcl` rồi áp dụng vào Vault.

**Bước 5:** Xác nhận cấu hình bằng cách đọc config `database/config/mydb` và role `database/roles/db-readonly`.

**Bước 6:** Tạo credential thật bằng lệnh `vault read database/creds/db-readonly`. Quan sát username và password được sinh ngẫu nhiên, và `lease_id` dùng để revoke thủ công nếu cần.

> Gợi ý: Ở Bước 6, mỗi lần gọi `vault read database/creds/db-readonly` sẽ tạo ra một tài khoản PostgreSQL mới và độc lập. Chạy hai lần liên tiếp để thấy username khác nhau.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
