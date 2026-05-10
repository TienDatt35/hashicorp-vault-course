---
title: Thiết lập DR Replication
estMinutes: 25
---

# Thiết lập DR Replication

## Mục tiêu

Khám phá quy trình CLI thiết lập DR Replication — từ kiểm tra trạng thái ban đầu, thử kích hoạt primary, đến hiểu rõ hành vi của Vault OSS khi gặp tính năng Enterprise. Bạn sẽ nắm vững các lệnh thực tế và biết cách đọc output của `sys/replication/dr/status`.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/09-vault-replication/03-setup-replication/`.

## Nhiệm vụ của bạn

### Bước 1 — Kiểm tra trạng thái replication hiện tại

Trước tiên, hãy xem trạng thái DR replication hiện tại của Vault server đang chạy. Đọc kỹ output và xác định trường `mode` trả về giá trị gì.

### Bước 2 — Thử kích hoạt DR Primary

Thử kích hoạt DR primary bằng lệnh CLI tương ứng. Quan sát output trả về — nếu Vault là bản OSS (không có Enterprise license), bạn sẽ thấy thông báo lỗi. Ghi lại nội dung lỗi.

### Bước 3 — Kiểm tra thông tin phiên bản và license

Xem thông tin chi tiết về phiên bản Vault đang chạy và loại license (OSS hay Enterprise). Tìm hiểu tại sao DR Replication không hoạt động trên phiên bản hiện tại.

### Bước 4 — Khám phá cấu trúc endpoint replication

Dùng lệnh CLI để liệt kê các endpoint replication có sẵn trên namespace gốc. Tìm hiểu endpoint nào tồn tại ngay cả trên Vault OSS và endpoint nào chỉ hoạt động khi replication được bật.

### Bước 5 — Ghi lại quy trình 3 bước

Dựa vào bài lý thuyết, soạn thảo lại 3 lệnh CLI đầy đủ (với ví dụ token giả) để thiết lập DR Replication từ đầu. Bao gồm lệnh cho cả primary lẫn secondary.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần
> giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
