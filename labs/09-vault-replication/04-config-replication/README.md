---
title: Cấu hình DR Replication qua CLI và UI
estMinutes: 20
---

# Cấu hình DR Replication qua CLI và UI

## Mục tiêu

Trong bài thực hành này, bạn sẽ khám phá các endpoint replication của Vault bằng cách đọc trạng thái, thử các lệnh CLI cho DR và Performance replication, và phân tích output để hiểu cấu trúc path cũng như các trường trạng thái quan trọng.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng về cấu hình DR Replication.
- Lưu ý: Vault dev server là phiên bản OSS — các lệnh replication sẽ trả về lỗi Enterprise license, nhưng endpoint vẫn phản hồi và trả về dữ liệu trạng thái có thể phân tích được.

## Nhiệm vụ của bạn

### Bước 1 — Đọc trạng thái DR replication hiện tại

Dùng lệnh `vault read` để truy vấn endpoint `sys/replication/dr/status` và lưu ý giá trị của các trường `mode`, `state`, và `connection_state`.

Câu hỏi để suy nghĩ: Vault OSS không hỗ trợ replication — vậy trường `mode` sẽ có giá trị gì?

### Bước 2 — Thử ba lệnh CLI thiết lập DR replication

Thử lần lượt ba lệnh thiết lập DR replication theo đúng thứ tự:

1. Kích hoạt DR primary (trên cụm primary — trong bài này bạn dùng dev server để quan sát output).
2. Tạo secondary token với `id` có tên gợi nhớ.
3. Quan sát lỗi Enterprise license trong output — đây là hành vi bình thường trên Vault OSS.

Chú ý: với Vault OSS, các lệnh này sẽ trả về lỗi. Mục tiêu là quan sát cú pháp lệnh và cấu trúc path, không phải thực thi thành công.

### Bước 3 — So sánh path DR với Performance replication

Thử lệnh tương đương cho Performance replication để thấy rõ sự khác nhau về path:

- Đọc endpoint `sys/replication/performance/status`
- So sánh cấu trúc output với `sys/replication/dr/status`

### Bước 4 — Đọc trạng thái tổng hợp cả hai loại replication

Truy vấn endpoint `sys/replication/status` (không có segment `dr` hay `performance`) để xem trạng thái tổng hợp.

### Bước 5 — Phân tích trường trạng thái

Từ output của các bước trên, trả lời:

- Trường `mode` có giá trị gì trên Vault OSS?
- Nếu replication healthy trên Vault Enterprise, trường `state` ở secondary sẽ có giá trị gì?
- Trường `connection_state` có giá trị gì khi kết nối ổn định?

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
