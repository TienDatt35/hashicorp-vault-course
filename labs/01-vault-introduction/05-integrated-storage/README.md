---
title: "Thực hành Raft: list-peers và snapshot"
estMinutes: 20
---

# Thực hành Raft: list-peers và snapshot

## Mục tiêu

Thực hành các lệnh vận hành Raft cluster trong môi trường dev (1 node) và đọc hiểu cấu hình HCL cho cluster 3 node thực tế.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết về Integrated Storage.

## Nhiệm vụ của bạn

**Bước 1 — Xác nhận Vault đang chạy**

Chạy lệnh kiểm tra trạng thái Vault:

```bash
vault status
```

Chú ý dòng `Storage Type` trong output. Dev server dùng `inmem` (in-memory storage), không phải `raft`. Tuy nhiên, Vault dev server vẫn hỗ trợ đầy đủ Raft API để bạn học cú pháp lệnh.

**Bước 2 — Xem danh sách node trong cluster**

Chạy lệnh liệt kê các Raft peer:

```bash
vault operator raft list-peers
```

Quan sát output: trong dev mode bạn sẽ thấy 1 node duy nhất với State là `leader` và Voter là `true`. Trong production cluster 3-node, bạn sẽ thấy 3 dòng với các State khác nhau.

**Bước 3 — Tạo snapshot**

Tạo một snapshot của storage hiện tại:

```bash
vault operator raft snapshot save /tmp/vault-raft-$(date +%Y%m%d).snap
```

Sau đó kiểm tra file đã được tạo và có kích thước lớn hơn 0:

```bash
ls -lh /tmp/vault-raft-*.snap
```

**Bước 4 — Đọc file config mẫu**

Mở file `raft-cluster.hcl` trong thư mục này và trả lời 3 câu hỏi sau (không cần viết ra — chỉ cần hiểu):

1. `cluster_addr` được đặt ở đâu trong file — nằm bên trong `storage "raft"` block hay ở ngoài top-level?
2. Port nào được dùng cho `cluster_addr`?
3. `retry_join` có tác dụng gì — tại sao lại có hai block `retry_join` thay vì một?

**Bước 5 — Restore snapshot**

Restore lại snapshot vừa tạo ở bước 3:

```bash
vault operator raft snapshot restore /tmp/vault-raft-$(date +%Y%m%d).snap
```

Lưu ý: trong môi trường dev với dữ liệu nhỏ, restore snapshot vừa tạo sẽ không làm mất dữ liệu vì snapshot đang chứa đúng dữ liệu hiện tại. Trong production, bạn nên dừng traffic trước khi restore snapshot cũ.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
