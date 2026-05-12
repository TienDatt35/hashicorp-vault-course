---
title: Vòng đời Secrets Engine: Enable, Tune, Disable
estMinutes: 15
---

# Vòng đời Secrets Engine: Enable, Tune, Disable

## Mục tiêu

Bạn sẽ thực hành toàn bộ vòng đời cơ bản của một secrets engine: bật engine tại path tùy chỉnh, ghi và đọc secret, điều chỉnh tham số TTL, rồi tắt engine và xác nhận dữ liệu đã bị xóa hoàn toàn.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/06-vault-secret-engine/01-secret-engine-introduction/`.

## Nhiệm vụ của bạn

**Bước 1:** Bật KV v2 secrets engine tại path `demo-secrets/` (không phải path mặc định `kv/`).

**Bước 2:** Xác nhận engine vừa bật bằng cách liệt kê tất cả secrets engine đang hoạt động. Tìm `demo-secrets/` trong danh sách.

**Bước 3:** Ghi một secret vào engine vừa bật, sau đó đọc lại để kiểm tra:
- Path: `demo-secrets/config`
- Nội dung: key `api_key` với value `abc123`

**Bước 4:** Điều chỉnh `default-lease-ttl` của engine `demo-secrets/` thành `2h`.

**Bước 5:** Tắt engine `demo-secrets/`. Sau đó thử đọc lại secret cũ và quan sát kết quả — dữ liệu không còn tồn tại nữa.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Chú ý đặc biệt đến cú pháp flag `-path` và argument trailing slash khi dùng `vault secrets tune` và `vault secrets disable`.

## Tiêu chí thành công

Chạy bộ kiểm tra sau khi hoàn thành **Bước 1 đến Bước 4** (trước khi thực hiện Bước 5):

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

> Lưu ý: script `verify.sh` kiểm tra trạng thái sau khi bạn đã thực hiện tune nhưng **chưa** disable. Sau khi chạy verify thành công, bạn có thể thực hiện Bước 5 để quan sát hành vi disable.

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
