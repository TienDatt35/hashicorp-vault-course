---
title: "Đáp án mẫu — Thực hành Raft: list-peers và snapshot"
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này tập trung vào các lệnh vận hành Raft API của Vault. Dev server dùng in-memory storage (`inmem`), nhưng Vault vẫn expose đầy đủ Raft operator commands để bạn học cú pháp mà không cần setup cluster thật. Trong production, các lệnh này hoạt động y hệt trên Integrated Storage thật.

## Các lệnh

```bash
# Bước 1 — Kiểm tra trạng thái Vault
vault status
# Chú ý dòng "Storage Type: inmem" — dev mode không dùng Raft thật,
# nhưng Raft API vẫn hoạt động để học lệnh.

# Bước 2 — Xem danh sách node trong cluster
vault operator raft list-peers
# Output mẫu trong dev mode:
# Node       Address           State     Voter
# ----       -------           -----     -----
# vault-dev  127.0.0.1:8201   leader    true

# Bước 3 — Tạo snapshot
vault operator raft snapshot save /tmp/vault-raft-$(date +%Y%m%d).snap
# Kiểm tra file tồn tại và có kích thước > 0
ls -lh /tmp/vault-raft-*.snap

# Bước 4 — Đọc file raft-cluster.hcl
# Không có lệnh cụ thể — chỉ cần mở file và đọc.
# Đáp án 3 câu hỏi:
#   1. cluster_addr đặt ở TOP-LEVEL, ngoài storage "raft" block.
#   2. Port 8201 được dùng cho cluster_addr.
#   3. Hai block retry_join để node tự tìm leader khi khởi động:
#      node1 sẽ thử kết nối tới node2 VÀ node3 — nếu một trong hai
#      là leader hoặc đã trong cluster, node1 sẽ join được.

# Bước 5 — Restore snapshot
vault operator raft snapshot restore /tmp/vault-raft-$(date +%Y%m%d).snap
```

## Giải thích bước 4 — Câu hỏi về raft-cluster.hcl

**Câu 1: `cluster_addr` ở đâu?**
`cluster_addr = "https://vault-node1:8201"` nằm ở top-level của file, cùng cấp với `ui`, `api_addr`, `disable_mlock` — KHÔNG nằm bên trong `storage "raft" { ... }`. Đây là lỗi cấu hình rất phổ biến: nhiều người nhầm đặt vào trong block storage.

**Câu 2: Port nào?**
Port 8201. Phân biệt rõ: port 8200 dành cho API/client (vault CLI, ứng dụng, UI), port 8201 dành cho cluster communication nội bộ giữa các Raft node.

**Câu 3: Tại sao có hai `retry_join`?**
Mỗi `retry_join` block chỉ định địa chỉ API của một node khác trong cluster. Khi vault-node1 khởi động, nó sẽ thử kết nối tới cả vault-node2 lẫn vault-node3. Nếu vault-node2 đang offline nhưng vault-node3 online, node1 vẫn join được. Khai báo nhiều `retry_join` tăng khả năng thành công khi một số node tạm thời không có mặt.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
