---
title: Đáp án mẫu — Cấu hình DR Replication qua CLI và UI
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Vault dev server là phiên bản OSS nên các lệnh replication sẽ trả về lỗi Enterprise license — đây là hành vi mong đợi. Mục tiêu là quan sát cấu trúc lệnh và phân tích output trạng thái.

## Giải thích ngắn

Vault OSS không hỗ trợ replication, nhưng các endpoint `sys/replication/*/status` vẫn phản hồi và trả về trạng thái `"disabled"`. Điều này cho phép bạn học cú pháp lệnh, cấu trúc path, và các trường output mà không cần môi trường Enterprise thực.

Ba endpoint quan trọng:
- `sys/replication/dr/status` — trạng thái DR replication
- `sys/replication/performance/status` — trạng thái Performance replication
- `sys/replication/status` — trạng thái tổng hợp cả hai

## Các lệnh

```bash
# Buoc 1 — Doc trang thai DR replication
vault read -format=json sys/replication/dr/status

# Buoc 2a — Thu kich hoat DR primary (se bao loi Enterprise license)
vault write -f sys/replication/dr/primary/enable

# Buoc 2b — Thu tao secondary token (se bao loi Enterprise license)
vault write sys/replication/dr/primary/secondary-token id="dc2-us-west"

# Buoc 3a — Doc trang thai Performance replication (so sanh path)
vault read -format=json sys/replication/performance/status

# Buoc 3b — So sanh output: ca hai deu co truong mode, nhung path khac nhau
# DR:          sys/replication/dr/status
# Performance: sys/replication/performance/status

# Buoc 4 — Doc trang thai tong hop ca hai loai replication
vault read -format=json sys/replication/status

# Buoc 5 — Phan tich: tren Vault OSS, truong mode co gia tri la "disabled"
# Neu replication healthy tren Enterprise secondary, state = "stream-wals"
# connection_state = "ready" khi ket noi on dinh
```

## Phân tích output

Khi chạy `vault read -format=json sys/replication/dr/status` trên Vault OSS, output trả về có dạng:

```json
{
  "request_id": "...",
  "data": {
    "mode": "disabled"
  }
}
```

Trường `mode` có giá trị `"disabled"` vì Vault OSS không hỗ trợ replication. Trên Vault Enterprise sau khi thiết lập:
- Primary: `"mode": "primary"`
- Secondary healthy: `"mode": "secondary"`, `"state": "stream-wals"`, `"connection_state": "ready"`

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
