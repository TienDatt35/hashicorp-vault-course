---
title: Kiến Trúc Vault và Path-based Routing
estMinutes: 20
---

# Kiến Trúc Vault và Path-based Routing

## Mục tiêu

Sau khi hoàn thành bài thực hành, bạn sẽ biết cách khám phá kiến trúc vận hành của Vault thông qua CLI: xem các mount đang hoạt động, enable secrets engine và auth method tại custom path, tương tác với System Backend qua `sys/`, và quan sát hành vi khi cố gắng mount vào reserved path.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/02-vault-architecture/02-vault-architecture-and-path/theory.mdx`.

## Nhiệm vụ của bạn

### Bước 1: Kiểm tra Vault và xem các mount paths hiện tại

Bắt đầu bằng việc xác nhận Vault đang chạy và xem trạng thái ban đầu của các mount:

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
```

Sau đó kiểm tra trạng thái Vault, liệt kê tất cả secrets engines đang mount, và liệt kê tất cả auth methods đang enable.

Hãy chú ý các path nào xuất hiện mặc định trong dev mode và path nào là reserved.

### Bước 2: Enable secrets engine tại custom path

Enable KV secrets engine tại một path tùy chỉnh tên là `myapp` (không phải tên mặc định của engine). Sau đó xác nhận nó xuất hiện trong danh sách mount.

Tiếp theo, ghi một secret vào engine vừa mount qua path mới, với key `db_host` có giá trị `localhost`. Đọc lại secret đó để xác nhận routing hoạt động đúng.

Hãy suy nghĩ: tại sao bạn dùng path `myapp/config` chứ không phải `kv/config` trong bước này?

### Bước 3: Khám phá System Backend qua `sys/`

Đọc thông tin chi tiết về tất cả mount đang hoạt động thông qua System Backend. Bạn có thể dùng CLI hoặc gọi REST API trực tiếp.

Hãy xác nhận rằng `sys/` xuất hiện trong output và tìm hiểu thông tin nào được trả về về mỗi mount (type, options, v.v.).

### Bước 4: Thử mount vào reserved path

Thử enable một secrets engine KV tại path `cubbyhole` — đây là một reserved path. Quan sát lỗi mà Vault trả về.

Đây là bước quan sát, không phải bước cần "thành công". Lỗi là kết quả mong đợi.

### Bước 5: Enable auth method tại custom path

Enable auth method `userpass` tại path tùy chỉnh tên là `my-userpass` (không phải path mặc định `userpass`).

Xác nhận auth method xuất hiện trong danh sách với path `auth/my-userpass/`.

Tạo một user tên `alice` với password `password123` và policy `default` trong auth method vừa enable. Sau đó thử login với user này qua custom path.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
