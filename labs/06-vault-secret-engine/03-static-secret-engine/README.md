---
title: Thực hành KV Secrets Engine
estMinutes: 25
---

# Thực hành KV Secrets Engine

## Mục tiêu

Sau khi hoàn thành bài này, bạn sẽ biết cách ghi, đọc và quản lý vòng đời version của secret trong KV v2, đồng thời hiểu sự khác biệt giữa soft delete, destroy vĩnh viễn và rollback trong môi trường thực.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết KV Secrets Engine — Static Secrets trong `site/docs/06-vault-secret-engine/03-static-secret-engine/theory.mdx`.

## Nhiệm vụ của bạn

### Bước 1 — Xác nhận KV v2 đang chạy

Kiểm tra danh sách secrets engine đang được bật. Xác nhận rằng KV v2 đang được mount tại path `secret/`. Xem loại engine và phiên bản của mount `secret/`.

### Bước 2 — Ghi và đọc secret cơ bản

Ghi một secret mới vào path `training/creds` trong mount `secret/` với hai field: `username` và `password`. Sau đó đọc lại secret vừa tạo để xác nhận dữ liệu.

### Bước 3 — Cập nhật secret và xem lịch sử version

Cập nhật `password` của secret `training/creds` sang giá trị mới bằng lệnh patch (không thay đổi `username`). Sau đó đọc metadata của secret để xem danh sách version và trạng thái từng version.

### Bước 4 — Soft delete một version

Thực hiện soft delete version 1 của secret `training/creds`. Thử đọc lại version 1 và quan sát kết quả. Sau đó xem metadata để xác nhận version 1 đã ở trạng thái deleted.

### Bước 5 — Undelete để khôi phục version đã xóa

Khôi phục (undelete) version 1 của secret `training/creds` vừa bị soft delete ở bước 4. Đọc lại version 1 để xác nhận dữ liệu đã trở lại accessible.

### Bước 6 — Destroy một version vĩnh viễn

Thực hiện destroy vĩnh viễn version 1 của secret `training/creds`. Thử đọc lại version 1 và quan sát kết quả. Xem metadata để xác nhận trạng thái "destroyed".

### Bước 7 — Rollback về dữ liệu của version cũ

Rollback secret `training/creds` về dữ liệu của version 2. Đọc secret ở version hiện tại (mới nhất) sau khi rollback và xác nhận nội dung. Xem metadata để hiểu version count đã thay đổi như thế nào.

> Gợi ý: hãy tự suy nghĩ và thử lệnh trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
