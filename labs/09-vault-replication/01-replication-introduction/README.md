---
title: Khám phá trạng thái Replication trên Vault OSS
estMinutes: 20
---

# Khám phá trạng thái Replication trên Vault OSS

> Vault Replication chỉ có trên Vault Enterprise và HCP Vault Dedicated. Trong
> bài này, bạn sẽ dùng Vault OSS dev server để khám phá API replication, đọc
> và phân tích output, đồng thời suy nghĩ về khi nào nên dùng loại replication
> nào trong thực tế.

## Mục tiêu

Sau khi hoàn thành bài này, bạn sẽ:

- Biết cách truy vấn trạng thái replication của một Vault cluster.
- Hiểu ý nghĩa các field trong response `sys/replication/status`.
- Phân tích được các tình huống thực tế để chọn đúng loại replication.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/09-vault-replication/01-replication-introduction/`.

## Nhiệm vụ của bạn

### Bước 1: Kiểm tra trạng thái replication tổng quát

Chạy lệnh sau để xem trạng thái replication của Vault cluster hiện tại:

```bash
vault read sys/replication/status
```

Quan sát output. Bạn sẽ thấy hai nhóm thông tin: `dr` và `performance`. Ghi
chú lại giá trị của các field sau trong output:

- `dr.mode`
- `performance.mode`
- `cluster_id` (nếu có)

### Bước 2: Phân tích output chi tiết theo từng loại

Chạy thêm hai lệnh sau để xem thông tin chi tiết của từng loại replication:

```bash
vault read sys/replication/dr/status
vault read sys/replication/performance/status
```

Với mỗi lệnh, hãy quan sát:

- Giá trị `mode` là gì?
- Tại sao Vault OSS trả về giá trị này?
- `state` khác gì `mode`?

### Bước 3: Suy nghĩ về tình huống thực tế

Đọc ba tình huống dưới đây. Với mỗi tình huống, hãy tự quyết định:
(a) Loại replication nào phù hợp — DR, Performance, hay kết hợp cả hai?
(b) Lý do tại sao?

**Tình huống A**: Công ty của bạn có primary Vault cluster ở Singapore.
Nhóm kỹ sư ở châu Âu phàn nàn rằng mỗi lần ứng dụng đọc secret từ Vault,
độ trễ cao hơn 200ms so với nhóm ở châu Á. Bạn cần giảm latency cho nhóm
châu Âu mà không thay đổi code ứng dụng.

**Tình huống B**: Sau một sự cố mất điện kéo dài ở data center Singapore,
toàn bộ Vault cluster bị mất liên lạc trong 4 giờ. Tất cả ứng dụng không
thể lấy secret và ngừng hoạt động. Ban lãnh đạo yêu cầu có giải pháp để khi
Singapore mất điện, hệ thống có thể tiếp tục trong vòng 15 phút, và ứng dụng
không cần đăng nhập lại Vault.

**Tình huống C**: Sau khi xử lý xong Tình huống A và B, bạn được yêu cầu
thiết kế kiến trúc Vault cho toàn cầu: giảm latency cho 5 văn phòng trên
khắp thế giới VÀ đảm bảo có backup phòng thảm họa.

### Bước 4 (tùy chọn): So sánh output từ hai endpoint

Chạy cả hai lệnh và so sánh output:

```bash
vault read sys/replication/status
vault read -format=json sys/replication/status
```

Khi dùng `-format=json`, output có dễ đọc hơn không? Trong tình huống thực
tế (ví dụ: trong script tự động hóa), format nào hữu ích hơn?

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với
> phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
