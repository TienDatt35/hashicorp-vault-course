---
title: Đáp án mẫu — Thực hành KV Secrets Engine
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này sử dụng KV v2 đã được mount sẵn tại `secret/` trong Vault dev server. Mọi thao tác ghi dữ liệu đều tạo version mới, không overwrite. Vault tự động mã hóa dữ liệu qua crypto barrier trước khi ghi xuống storage — bạn không cần cấu hình thêm gì. Điểm then chốt là phân biệt ba thao tác xóa: `delete` (soft, có thể undelete), `destroy` (vĩnh viễn, không undelete được), và `rollback` (tạo version mới từ dữ liệu cũ).

## Các lệnh

```bash
# Bước 1 — Xác nhận KV v2 đang chạy
# Liệt kê tất cả secrets engine đang được bật
vault secrets list -detailed

# Xem thông tin cụ thể của mount secret/
vault secrets list -detailed | grep secret/
```

```bash
# Bước 2 — Ghi và đọc secret cơ bản
# Ghi secret mới vào training/creds (tạo version 1)
vault kv put -mount=secret training/creds username="admin" password="s3cr3t"

# Đọc lại để xác nhận
vault kv get -mount=secret training/creds
```

```bash
# Bước 3 — Cập nhật secret và xem lịch sử version
# Patch chỉ trường password (tạo version 2, username giữ nguyên)
vault kv patch -mount=secret training/creds password="n3wpassword"

# Xem metadata và danh sách version
vault kv metadata get -mount=secret training/creds
```

```bash
# Bước 4 — Soft delete version 1
# Soft delete: version 1 bị đánh dấu "deleted" nhưng chưa mất dữ liệu
vault kv delete -mount=secret -versions=1 training/creds

# Thử đọc version 1 — sẽ báo lỗi hoặc không trả về dữ liệu
vault kv get -mount=secret -version=1 training/creds

# Xem metadata để thấy trạng thái "deleted" của version 1
vault kv metadata get -mount=secret training/creds
```

```bash
# Bước 5 — Undelete version 1
# Khôi phục version 1 đã soft delete
vault kv undelete -mount=secret -versions=1 training/creds

# Đọc lại version 1 để xác nhận đã accessible
vault kv get -mount=secret -version=1 training/creds
```

```bash
# Bước 6 — Destroy version 1 vĩnh viễn
# Destroy: dữ liệu version 1 bị purge hoàn toàn, KHÔNG thể undelete
vault kv destroy -mount=secret -versions=1 training/creds

# Thử đọc version 1 — sẽ trả về trạng thái "destroyed"
vault kv get -mount=secret -version=1 training/creds

# Xem metadata để thấy trạng thái "destroyed"
vault kv metadata get -mount=secret training/creds
```

```bash
# Bước 7 — Rollback về dữ liệu version 2
# Rollback tạo version MỚI (version 3) chứa dữ liệu của version 2
# Version count tiếp tục tăng, không "quay về quá khứ"
vault kv rollback -mount=secret -version=2 training/creds

# Đọc version mới nhất để xác nhận nội dung giống version 2
vault kv get -mount=secret training/creds

# Xem metadata để thấy version count mới
vault kv metadata get -mount=secret training/creds
```

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
